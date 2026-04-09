import Foundation

public struct KokoroANEManifest: Codable, Sendable {
  public let version: Int
  public let sampleRate: Int
  public let frameRate: Int
  public let samplesPerFrame: Int
  public let tokenLimit: Int
  public let durationModel: String
  public let config: String
  public let voicesManifest: String
  public let buckets: [KokoroANEBucket]

  enum CodingKeys: String, CodingKey {
    case version
    case sampleRate = "sample_rate"
    case frameRate = "frame_rate"
    case samplesPerFrame = "samples_per_frame"
    case tokenLimit = "token_limit"
    case durationModel = "duration_model"
    case config
    case voicesManifest = "voices_manifest"
    case buckets
  }
}

public struct KokoroANEBucket: Codable, Sendable {
  public let seconds: Int
  public let frames: Int
  public let f0Length: Int
  public let samples: Int
  public let f0nModel: String
  public let preharDecoderModel: String
  public let vocoderTailModel: String
  public let xPreShape: [Int]
  public let harShape: [Int]

  enum CodingKeys: String, CodingKey {
    case seconds
    case frames
    case f0Length = "f0_length"
    case samples
    case f0nModel = "f0n_model"
    case preharDecoderModel = "prehar_decoder_model"
    case vocoderTailModel = "vocoder_tail_model"
    case xPreShape = "x_pre_shape"
    case harShape = "har_shape"
  }
}

public struct KokoroConfig: Codable, Sendable {
  public let vocab: [String: Int]
}

public struct VoiceManifest: Codable, Sendable {
  public let version: Int
  public let voices: [VoiceEntry]
}

public struct VoiceEntry: Codable, Sendable {
  public let name: String
  public let file: String
  public let shape: [Int]
  public let dtype: String
}

public struct HarmonicSourceConfig: Codable, Sendable {
  public let weight: [Float]
  public let bias: [Float]
  public let samplingRate: Int
  public let upsampleScale: Int
  public let harmonicNum: Int
  public let sineAmp: Float
  public let noiseStd: Float
  public let voicedThreshold: Float
  public let stft: STFTConfig

  enum CodingKeys: String, CodingKey {
    case weight
    case bias
    case samplingRate = "sampling_rate"
    case upsampleScale = "upsample_scale"
    case harmonicNum = "harmonic_num"
    case sineAmp = "sine_amp"
    case noiseStd = "noise_std"
    case voicedThreshold = "voiced_threshold"
    case stft
  }
}

public struct STFTConfig: Codable, Sendable {
  public let filterLength: Int
  public let hopLength: Int
  public let winLength: Int
  public let padMode: String

  enum CodingKeys: String, CodingKey {
    case filterLength = "filter_length"
    case hopLength = "hop_length"
    case winLength = "win_length"
    case padMode = "pad_mode"
  }
}
