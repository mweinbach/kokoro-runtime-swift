import Foundation

public enum KokoroBackend: String, Sendable {
  case mlx
  case coreml
}

public struct KokoroBundleLayout: Sendable {
  public let rootURL: URL

  public init(rootURL: URL) {
    self.rootURL = rootURL
  }

  public var mlxURL: URL { rootURL.appendingPathComponent("mlx", isDirectory: true) }
  public var coremlURL: URL { rootURL.appendingPathComponent("coreml", isDirectory: true) }
  public var coremlArtifactsURL: URL { coremlURL.appendingPathComponent("Artifacts", isDirectory: true) }
}

public enum HuggingFaceArtifacts {
  public static let repoID = "mweinbach/kokoro-runtime-swift"
  public static let baseURL = URL(string: "https://huggingface.co/\(repoID)/resolve/main")!
  public static let mlxArchiveName = "kokoro-mlx-bundle.zip"
  public static let coreMLArchiveName = "kokoro-coreml-bundle.zip"

  public static func archiveURL(for backend: KokoroBackend) -> URL {
    switch backend {
    case .mlx:
      return baseURL.appendingPathComponent(mlxArchiveName)
    case .coreml:
      return baseURL.appendingPathComponent(coreMLArchiveName)
    }
  }
}
