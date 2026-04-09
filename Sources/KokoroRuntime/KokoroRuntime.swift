import CoreML
import Foundation
import MLX
import MLXRandom
import KokoroANE
import KokoroSwift

public struct KokoroRunResult: Sendable {
  public let backend: KokoroBackend
  public let samples: [Float]
  public let sampleRate: Int
  public let metadata: [String: String]
}

public enum KokoroRuntime {
  public static func runMLX(bundleRoot: URL, voice: String, phonemes: String, speed: Float = 1.0, seed: UInt64 = 0) throws -> KokoroRunResult {
    let layout = KokoroBundleLayout(rootURL: bundleRoot)
    try KokoroMLXRuntimeSupport.ensureMetallibPresent(mlxBundleURL: layout.mlxURL)
    let modelPath = layout.mlxURL.appendingPathComponent("kokoro-v1_0.safetensors")
    let configPath = layout.mlxURL.appendingPathComponent("config.json")
    let voicesDir = layout.mlxURL.appendingPathComponent("voices", isDirectory: true)

    var generated: [Float] = []
    try Device.withDefaultDevice(.gpu) {
      MLXRandom.seed(seed)
      let engine = try KokoroTTS(modelPath: modelPath, configPath: configPath, g2p: nil)
      let voiceStore = KokoroSwift.VoiceStore(voicesDirectory: voicesDir)
      let voiceTensor = try voiceStore.loadVoice(named: voice)
      generated = try engine.generateAudioFromPhonemes(voice: voiceTensor, phonemes: phonemes, speed: speed)
    }

    return KokoroRunResult(
      backend: .mlx,
      samples: generated,
      sampleRate: KokoroTTS.Constants.samplingRate,
      metadata: ["voice": voice, "seed": String(seed)]
    )
  }

  public static func runCoreML(
    bundleRoot: URL,
    voice: String,
    phonemes: String,
    speed: Float = 1.0,
    seed: UInt64 = 0,
    computeUnits: KokoroCoreMLComputeUnits = KokoroCoreMLComputeUnits()
  ) throws -> KokoroRunResult {
    let layout = KokoroBundleLayout(rootURL: bundleRoot)
    let engine = try KokoroANEEngine(artifactsURL: layout.coremlArtifactsURL, computeUnits: computeUnits.aneValue)
    let result = try engine.synthesize(phonemes: phonemes, voice: voice, speed: speed, seed: seed)
    return KokoroRunResult(
      backend: .coreml,
      samples: result.waveform,
      sampleRate: result.sampleRate,
      metadata: ["voice": voice, "seed": String(seed)]
    )
  }
}
