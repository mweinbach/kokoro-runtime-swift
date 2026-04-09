import Foundation

public enum KokoroMLXRuntimeSupport {
  public static func ensureMetallibPresent(mlxBundleURL: URL) throws {
    let source = mlxBundleURL.appendingPathComponent("mlx.metallib")
    guard FileManager.default.fileExists(atPath: source.path) else {
      return
    }
    let executableURL = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
    let executableDirectory = executableURL.deletingLastPathComponent()
    for name in ["mlx.metallib", "default.metallib"] {
      let destination = executableDirectory.appendingPathComponent(name)
      if FileManager.default.fileExists(atPath: destination.path) {
        continue
      }
      try? FileManager.default.copyItem(at: source, to: destination)
    }
  }
}
