import Foundation

struct SeededGenerator {
  private var state: UInt64

  init(seed: UInt64) {
    state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
  }

  mutating func nextUInt64() -> UInt64 {
    state &+= 0x9E37_79B9_7F4A_7C15
    var z = state
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    return z ^ (z >> 31)
  }

  mutating func nextFloat() -> Float {
    Float(nextUInt64() & 0x00FF_FFFF) / Float(0x0100_0000)
  }

  mutating func nextGaussian() -> Float {
    let u1 = max(nextFloat(), 1e-7)
    let u2 = nextFloat()
    return sqrt(-2 * log(u1)) * cos(2 * .pi * u2)
  }
}

public final class HarmonicSource {
  private let config: HarmonicSourceConfig
  private let hannWindow: [Float]
  private let basisReal: [[Float]]
  private let basisImag: [[Float]]

  public init(config: HarmonicSourceConfig) {
    self.config = config
    let window = (0 ..< config.stft.winLength).map { index in
      Float(0.5 - 0.5 * cos((2 * Double.pi * Double(index)) / Double(config.stft.winLength)))
    }
    hannWindow = window
    let bins = config.stft.filterLength / 2 + 1
    var real: [[Float]] = []
    var imag: [[Float]] = []
    for k in 0 ..< bins {
      real.append((0 ..< config.stft.filterLength).map { n in
        window[n] * Float(cos((2 * Double.pi * Double(k * n)) / Double(config.stft.filterLength)))
      })
      imag.append((0 ..< config.stft.filterLength).map { n in
        window[n] * Float(-sin((2 * Double.pi * Double(k * n)) / Double(config.stft.filterLength)))
      })
    }
    basisReal = real
    basisImag = imag
  }

  public func makeHar(f0Curve: [Float], expectedShape: [Int], seed: UInt64) -> [Float] {
    var rng = SeededGenerator(seed: seed)
    let dim = config.harmonicNum + 1
    let upsampled = upsampleRepeat(f0Curve, scale: config.upsampleScale)
    let sineWaves = makeSineWaves(upsampledF0: upsampled, harmonicCount: dim, rng: &rng)
    let merged = mergeSource(sineWaves: sineWaves)
    let (magnitude, phase) = stft(merged)
    let frames = expectedShape.last ?? magnitude.first?.count ?? 0
    let bins = config.stft.filterLength / 2 + 1
    var output = Array(repeating: Float(0), count: 2 * bins * frames)
    for channel in 0 ..< bins {
      for frame in 0 ..< frames {
        output[channel * frames + frame] = magnitude[channel][frame]
        output[(bins + channel) * frames + frame] = phase[channel][frame]
      }
    }
    return output
  }

  private func upsampleRepeat(_ input: [Float], scale: Int) -> [Float] {
    var output: [Float] = []
    output.reserveCapacity(input.count * scale)
    for value in input {
      output.append(contentsOf: repeatElement(value, count: scale))
    }
    return output
  }

  private func linearInterpolate(_ input: [Float], outputLength: Int) -> [Float] {
    if input.count == outputLength { return input }
    if outputLength <= 1 { return [input.first ?? 0] }
    let inputLength = input.count
    var output = Array(repeating: Float(0), count: outputLength)
    for index in 0 ..< outputLength {
      let position = (Float(index) + 0.5) * (Float(inputLength) / Float(outputLength)) - 0.5
      let clamped = min(max(position, 0), Float(inputLength - 1))
      let low = Int(floor(clamped))
      let high = min(low + 1, inputLength - 1)
      let frac = clamped - Float(low)
      output[index] = input[low] * (1 - frac) + input[high] * frac
    }
    return output
  }

  private func makeSineWaves(upsampledF0: [Float], harmonicCount: Int, rng: inout SeededGenerator) -> [[Float]] {
    let length = upsampledF0.count
    let coarseLength = max(1, length / config.upsampleScale)
    var phasesPerHarmonic = Array(repeating: Array(repeating: Float(0), count: length), count: harmonicCount)
    var uv = Array(repeating: Float(0), count: length)
    for index in 0 ..< length {
      uv[index] = upsampledF0[index] > config.voicedThreshold ? 1 : 0
    }
    for harmonic in 0 ..< harmonicCount {
      var radValues = Array(repeating: Float(0), count: length)
      let multiplier = Float(harmonic + 1)
      for index in 0 ..< length {
        radValues[index] = fmod((upsampledF0[index] * multiplier) / Float(config.samplingRate), 1)
      }
      radValues[0] += harmonic == 0 ? 0 : rng.nextFloat()
      let downsampled = linearInterpolate(radValues, outputLength: coarseLength)
      var cumulative = Array(repeating: Float(0), count: coarseLength)
      var running: Float = 0
      for index in 0 ..< coarseLength {
        running += downsampled[index]
        cumulative[index] = running * 2 * .pi
      }
      let upsampledPhase = linearInterpolate(cumulative.map { $0 * Float(config.upsampleScale) }, outputLength: length)
      for index in 0 ..< length {
        let sine = sin(upsampledPhase[index]) * config.sineAmp
        let noiseAmp = uv[index] * config.noiseStd + (1 - uv[index]) * config.sineAmp / 3
        phasesPerHarmonic[harmonic][index] = sine * uv[index] + noiseAmp * rng.nextGaussian()
      }
    }
    return phasesPerHarmonic
  }

  private func mergeSource(sineWaves: [[Float]]) -> [Float] {
    let length = sineWaves.first?.count ?? 0
    var output = Array(repeating: Float(0), count: length)
    for sample in 0 ..< length {
      var value = config.bias.first ?? 0
      for harmonic in 0 ..< min(config.weight.count, sineWaves.count) {
        value += config.weight[harmonic] * sineWaves[harmonic][sample]
      }
      output[sample] = tanh(value)
    }
    return output
  }

  private func stft(_ waveform: [Float]) -> ([[Float]], [[Float]]) {
    let pad = config.stft.filterLength / 2
    var padded = Array(repeating: waveform.first ?? 0, count: pad)
    padded.append(contentsOf: waveform)
    padded.append(contentsOf: Array(repeating: waveform.last ?? 0, count: pad))
    let bins = config.stft.filterLength / 2 + 1
    let frames = 1 + (padded.count - config.stft.filterLength) / config.stft.hopLength
    var magnitude = Array(repeating: Array(repeating: Float(0), count: frames), count: bins)
    var phase = Array(repeating: Array(repeating: Float(0), count: frames), count: bins)
    for frame in 0 ..< frames {
      let start = frame * config.stft.hopLength
      let slice = Array(padded[start ..< start + config.stft.filterLength])
      for bin in 0 ..< bins {
        var real: Float = 0
        var imag: Float = 0
        for index in 0 ..< config.stft.filterLength {
          real += slice[index] * basisReal[bin][index]
          imag += slice[index] * basisImag[bin][index]
        }
        magnitude[bin][frame] = sqrt(real * real + imag * imag + 1e-14)
        phase[bin][frame] = atan2(imag, real)
      }
    }
    return (magnitude, phase)
  }
}
