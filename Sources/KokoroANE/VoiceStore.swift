import Foundation

public final class VoiceStore {
  private let baseURL: URL
  private let manifest: VoiceManifest
  private var cache: [String: [Float]] = [:]

  public init(baseURL: URL, manifest: VoiceManifest) {
    self.baseURL = baseURL
    self.manifest = manifest
  }

  public func voiceRow(name: String, tokenCount: Int) throws -> [Float] {
    let clampedIndex = max(0, min(tokenCount - 1, 509))
    let fullVoice = try loadVoice(named: name)
    let offset = clampedIndex * 256
    return Array(fullVoice[offset ..< offset + 256])
  }

  public func loadVoice(named name: String) throws -> [Float] {
    if let cached = cache[name] {
      return cached
    }
    guard let entry = manifest.voices.first(where: { $0.name == name }) else {
      throw NSError(domain: "KokoroANE", code: 404, userInfo: [NSLocalizedDescriptionKey: "Unknown voice \(name)"])
    }
    let data = try Data(contentsOf: baseURL.appendingPathComponent(entry.file))
    let count = data.count / MemoryLayout<Float>.size
    let values: [Float] = data.withUnsafeBytes { rawBuffer in
      let buffer = rawBuffer.bindMemory(to: Float.self)
      return Array(buffer.prefix(count))
    }
    cache[name] = values
    return values
  }
}
