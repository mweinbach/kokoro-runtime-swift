import CoreML
import Foundation
import KokoroANE

public enum KokoroCoreMLCompiler {
  public static func compileAll(artifactsURL: URL) throws {
    let data = try Data(contentsOf: artifactsURL.appendingPathComponent("manifest.json"))
    let manifest = try JSONDecoder().decode(KokoroANEManifest.self, from: data)
    let compiledRoot = artifactsURL.appendingPathComponent(".compiled", isDirectory: true)
    try FileManager.default.createDirectory(at: compiledRoot, withIntermediateDirectories: true)

    var relativePaths = [manifest.durationModel]
    for bucket in manifest.buckets {
      relativePaths.append(bucket.f0nModel)
      relativePaths.append(bucket.preharDecoderModel)
      relativePaths.append(bucket.vocoderTailModel)
    }

    for relativePath in relativePaths {
      let sourceURL = artifactsURL.appendingPathComponent(relativePath)
      let destinationURL = compiledRoot.appendingPathComponent(sourceURL.deletingPathExtension().lastPathComponent + ".mlmodelc", isDirectory: true)
      if FileManager.default.fileExists(atPath: destinationURL.path) {
        continue
      }
      let temporaryCompiledURL = try MLModel.compileModel(at: sourceURL)
      try FileManager.default.copyItem(at: temporaryCompiledURL, to: destinationURL)
    }
  }
}
