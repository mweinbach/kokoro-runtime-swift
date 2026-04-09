import Foundation

public enum KokoroDownloadError: Error {
  case downloadFailed(URL)
  case unzipFailed(URL)
}

public enum KokoroDownloader {
  @discardableResult
  public static func download(
    backend: KokoroBackend,
    to outputDirectory: URL,
    session: URLSession = .shared
  ) throws -> URL {
    let layout = KokoroBundleLayout(rootURL: outputDirectory)
    let destinationDirectory = backend == .mlx ? layout.mlxURL : layout.coremlURL
    try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

    let archiveURL = destinationDirectory.appendingPathComponent(
      backend == .mlx ? HuggingFaceArtifacts.mlxArchiveName : HuggingFaceArtifacts.coreMLArchiveName
    )
    let sourceURL = HuggingFaceArtifacts.archiveURL(for: backend)

    let semaphore = DispatchSemaphore(value: 0)
    var finalError: Error?
    let task = session.downloadTask(with: sourceURL) { temporaryURL, _, error in
      defer { semaphore.signal() }
      if let error {
        finalError = error
        return
      }
      guard let temporaryURL else {
        finalError = KokoroDownloadError.downloadFailed(sourceURL)
        return
      }
      do {
        if FileManager.default.fileExists(atPath: archiveURL.path) {
          try FileManager.default.removeItem(at: archiveURL)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: archiveURL)
      } catch {
        finalError = error
      }
    }
    task.resume()
    semaphore.wait()
    if let finalError {
      throw finalError
    }

    try extractArchive(archiveURL, to: destinationDirectory)
    return destinationDirectory
  }

  public static func downloadAll(to outputDirectory: URL) throws {
    try download(backend: .mlx, to: outputDirectory)
    try download(backend: .coreml, to: outputDirectory)
  }

  private static func extractArchive(_ archiveURL: URL, to destinationDirectory: URL) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
    process.arguments = ["-x", "-k", archiveURL.path, destinationDirectory.path]
    try process.run()
    process.waitUntilExit()
    if process.terminationStatus != 0 {
      throw KokoroDownloadError.unzipFailed(archiveURL)
    }
  }
}
