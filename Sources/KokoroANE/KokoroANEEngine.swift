import CoreML
import Foundation

public struct KokoroANEStageTimings: Sendable {
  public let setupSeconds: Double
  public let durationSeconds: Double
  public let alignmentSeconds: Double
  public let f0nSeconds: Double
  public let preharSeconds: Double
  public let harmonicSeconds: Double
  public let tailSeconds: Double

  public var totalSeconds: Double {
    setupSeconds + durationSeconds + alignmentSeconds + f0nSeconds + preharSeconds + harmonicSeconds + tailSeconds
  }
}

public struct KokoroANEComputeUnits: Sendable {
  public let duration: MLComputeUnits
  public let f0n: MLComputeUnits
  public let prehar: MLComputeUnits
  public let tail: MLComputeUnits

  public init(
    duration: MLComputeUnits = .all,
    f0n: MLComputeUnits = .cpuAndNeuralEngine,
    prehar: MLComputeUnits = .cpuOnly,
    tail: MLComputeUnits = .all
  ) {
    self.duration = duration
    self.f0n = f0n
    self.prehar = prehar
    self.tail = tail
  }
}

public struct KokoroANEResult: Sendable {
  public let waveform: [Float]
  public let sampleRate: Int
  public let bucketSeconds: Int
  public let stageTimings: KokoroANEStageTimings
}

public final class KokoroANEEngine {
  public let artifactsURL: URL
  public let manifest: KokoroANEManifest
  public let config: KokoroConfig
  public let voiceManifest: VoiceManifest
  public let harmonicConfig: HarmonicSourceConfig
  public let computeUnits: KokoroANEComputeUnits
  private let modelStore: ModelStore
  private let voiceStore: VoiceStore
  private let harmonicSource: HarmonicSource

  public init(artifactsURL: URL, computeUnits: KokoroANEComputeUnits = KokoroANEComputeUnits()) throws {
    self.artifactsURL = artifactsURL
    self.computeUnits = computeUnits
    let decoder = JSONDecoder()
    manifest = try decoder.decode(KokoroANEManifest.self, from: Data(contentsOf: artifactsURL.appendingPathComponent("manifest.json")))
    config = try decoder.decode(KokoroConfig.self, from: Data(contentsOf: artifactsURL.appendingPathComponent(manifest.config)))
    voiceManifest = try decoder.decode(VoiceManifest.self, from: Data(contentsOf: artifactsURL.appendingPathComponent(manifest.voicesManifest)))
    harmonicConfig = try decoder.decode(HarmonicSourceConfig.self, from: Data(contentsOf: artifactsURL.appendingPathComponent("harmonic_source.json")))
    modelStore = ModelStore(artifactsURL: artifactsURL, defaultComputeUnits: computeUnits.duration)
    voiceStore = VoiceStore(baseURL: artifactsURL.appendingPathComponent("voices"), manifest: voiceManifest)
    harmonicSource = HarmonicSource(config: harmonicConfig)
  }

  public func synthesize(phonemes: String, voice: String, speed: Float = 1.0, seed: UInt64 = 0) throws -> KokoroANEResult {
    var setupSeconds = 0.0
    var durationSeconds = 0.0
    var alignmentSeconds = 0.0
    var f0nSeconds = 0.0
    var preharSeconds = 0.0
    var harmonicSeconds = 0.0
    var tailSeconds = 0.0

    var mark = CFAbsoluteTimeGetCurrent()
    let tokenIDs = KokoroANETokenizer.tokenize(phonemes: phonemes, vocab: config.vocab)
    if tokenIDs.count + 2 > manifest.tokenLimit {
      throw NSError(domain: "KokoroANE", code: 413, userInfo: [NSLocalizedDescriptionKey: "Too many tokens for ANE runtime"])
    }

    let tokenCount = tokenIDs.count + 2
    let voiceRow = try voiceStore.voiceRow(name: voice, tokenCount: tokenCount)
    let paddedIDs = ([0] + tokenIDs + [0]) + Array(repeating: 0, count: manifest.tokenLimit - tokenCount)
    let attentionMask = Array(repeating: Int32(1), count: tokenCount) + Array(repeating: Int32(0), count: manifest.tokenLimit - tokenCount)
    setupSeconds += CFAbsoluteTimeGetCurrent() - mark

    mark = CFAbsoluteTimeGetCurrent()
    let durationModel = try modelStore.loadModel(relativePath: manifest.durationModel, computeUnits: computeUnits.duration)
    let durationInput = try MLDictionaryFeatureProvider(dictionary: [
      "input_ids": MultiArrayFactory.makeInt32(paddedIDs.map(Int32.init), shape: [1, manifest.tokenLimit]),
      "ref_s": MultiArrayFactory.makeFloat32(voiceRow, shape: [1, 256]),
      "speed": MultiArrayFactory.makeFloat32([speed], shape: [1]),
      "attention_mask": MultiArrayFactory.makeInt32(attentionMask, shape: [1, manifest.tokenLimit]),
    ])
    let durationOutput = try durationModel.prediction(from: durationInput)
    let predDur = MultiArrayFactory.intArray(from: durationOutput.featureValue(for: "pred_dur")!.multiArrayValue!)
    let totalFrames = AlignmentBuilder.predictedFrameCount(predictedDurations: predDur, tokenCount: tokenCount, tokenLimit: manifest.tokenLimit)
    guard let bucket = manifest.buckets.first(where: { $0.frames >= totalFrames }) ?? manifest.buckets.last else {
      throw NSError(domain: "KokoroANE", code: 500, userInfo: [NSLocalizedDescriptionKey: "No ANE buckets available"])
    }
    durationSeconds += CFAbsoluteTimeGetCurrent() - mark

    mark = CFAbsoluteTimeGetCurrent()
    let alignment = AlignmentBuilder.buildAlignment(predictedDurations: predDur, tokenCount: tokenCount, tokenLimit: manifest.tokenLimit, frameCount: bucket.frames)
    let dValues = MultiArrayFactory.floatArray(from: durationOutput.featureValue(for: "d")!.multiArrayValue!)
    let tEnValues = MultiArrayFactory.floatArray(from: durationOutput.featureValue(for: "t_en")!.multiArrayValue!)
    let sValues = MultiArrayFactory.floatArray(from: durationOutput.featureValue(for: "s")!.multiArrayValue!)
    let refSValues = MultiArrayFactory.floatArray(from: durationOutput.featureValue(for: "ref_s_out")!.multiArrayValue!)
    let dTransposed = transposeDurationFeatures(dValues)
    let en = MatrixOps.matmulRowMajor(dTransposed, rowsA: 640, colsA: manifest.tokenLimit, alignment, colsB: bucket.frames)
    let asr = MatrixOps.matmulRowMajor(tEnValues, rowsA: 512, colsA: manifest.tokenLimit, alignment, colsB: bucket.frames)
    alignmentSeconds += CFAbsoluteTimeGetCurrent() - mark

    mark = CFAbsoluteTimeGetCurrent()
    let f0nModel = try modelStore.loadModel(relativePath: bucket.f0nModel, computeUnits: computeUnits.f0n)
    let f0nInput = try MLDictionaryFeatureProvider(dictionary: [
      "en": MultiArrayFactory.makeFloat32(en, shape: [1, 640, bucket.frames]),
      "s": MultiArrayFactory.makeFloat32(sValues, shape: [1, 128]),
    ])
    let f0nOutput = try f0nModel.prediction(from: f0nInput)
    let f0Pred = MultiArrayFactory.floatArray(from: f0nOutput.featureValue(for: "f0_pred")!.multiArrayValue!)
    let nPred = MultiArrayFactory.floatArray(from: f0nOutput.featureValue(for: "n_pred")!.multiArrayValue!)
    f0nSeconds += CFAbsoluteTimeGetCurrent() - mark

    mark = CFAbsoluteTimeGetCurrent()
    let preharModel = try modelStore.loadModel(relativePath: bucket.preharDecoderModel, computeUnits: computeUnits.prehar)
    let preharInput = try MLDictionaryFeatureProvider(dictionary: [
      "asr": MultiArrayFactory.makeFloat32(asr, shape: [1, 512, bucket.frames]),
      "f0_pred": MultiArrayFactory.makeFloat32(f0Pred, shape: [1, bucket.f0Length]),
      "n_pred": MultiArrayFactory.makeFloat32(nPred, shape: [1, bucket.f0Length]),
      "ref_s": MultiArrayFactory.makeFloat32(refSValues, shape: [1, 256]),
    ])
    let preharOutput = try preharModel.prediction(from: preharInput)
    let xPre = MultiArrayFactory.floatArray(from: preharOutput.featureValue(for: "x_pre")!.multiArrayValue!)
    preharSeconds += CFAbsoluteTimeGetCurrent() - mark

    mark = CFAbsoluteTimeGetCurrent()
    let har = harmonicSource.makeHar(f0Curve: f0Pred, expectedShape: bucket.harShape, seed: seed)
    harmonicSeconds += CFAbsoluteTimeGetCurrent() - mark

    mark = CFAbsoluteTimeGetCurrent()
    let vocoderTail = try modelStore.loadModel(relativePath: bucket.vocoderTailModel, computeUnits: computeUnits.tail)
    let vocoderInput = try MLDictionaryFeatureProvider(dictionary: [
      "x_pre": MultiArrayFactory.makeFloat32(xPre, shape: bucket.xPreShape),
      "ref_s": MultiArrayFactory.makeFloat32(refSValues, shape: [1, 256]),
      "har": MultiArrayFactory.makeFloat32(har, shape: bucket.harShape),
    ])
    let vocoderOutput = try vocoderTail.prediction(from: vocoderInput)
    let waveform = MultiArrayFactory.floatArray(from: vocoderOutput.featureValue(for: "waveform")!.multiArrayValue!)
    let targetSampleCount = min(waveform.count, max(manifest.samplesPerFrame, totalFrames * manifest.samplesPerFrame))
    let trimmedWaveform = Array(waveform.prefix(targetSampleCount))
    tailSeconds += CFAbsoluteTimeGetCurrent() - mark

    let stageTimings = KokoroANEStageTimings(
      setupSeconds: setupSeconds,
      durationSeconds: durationSeconds,
      alignmentSeconds: alignmentSeconds,
      f0nSeconds: f0nSeconds,
      preharSeconds: preharSeconds,
      harmonicSeconds: harmonicSeconds,
      tailSeconds: tailSeconds
    )

    return KokoroANEResult(waveform: trimmedWaveform, sampleRate: manifest.sampleRate, bucketSeconds: bucket.seconds, stageTimings: stageTimings)
  }

  private func transposeDurationFeatures(_ values: [Float]) -> [Float] {
    var output = Array(repeating: Float(0), count: 640 * manifest.tokenLimit)
    for token in 0 ..< manifest.tokenLimit {
      for hidden in 0 ..< 640 {
        output[hidden * manifest.tokenLimit + token] = values[token * 640 + hidden]
      }
    }
    return output
  }
}
