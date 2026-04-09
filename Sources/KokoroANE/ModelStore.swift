import CoreML
import Foundation

public final class ModelStore {
  private let artifactsURL: URL
  private let defaultComputeUnits: MLComputeUnits
  private let compiledRootURL: URL
  private var cache: [String: MLModel] = [:]
  private var compiledURLs: [String: URL] = [:]

  public init(artifactsURL: URL, defaultComputeUnits: MLComputeUnits = .cpuAndNeuralEngine) {
    self.artifactsURL = artifactsURL
    self.defaultComputeUnits = defaultComputeUnits
    compiledRootURL = artifactsURL.appendingPathComponent(".compiled", isDirectory: true)
  }

  public func loadModel(relativePath: String, computeUnits: MLComputeUnits? = nil) throws -> MLModel {
    let resolvedComputeUnits = computeUnits ?? defaultComputeUnits
    let cacheKey = "\(relativePath)#\(resolvedComputeUnits.rawValue)"
    if let cached = cache[cacheKey] {
      return cached
    }
    let compiledURL = try compiledURL(for: relativePath)
    let configuration = MLModelConfiguration()
    configuration.computeUnits = resolvedComputeUnits
    let model = try MLModel(contentsOf: compiledURL, configuration: configuration)
    cache[cacheKey] = model
    return model
  }

  private func compiledURL(for relativePath: String) throws -> URL {
    if let cachedCompiled = compiledURLs[relativePath] {
      return cachedCompiled
    }
    let fileManager = FileManager.default
    let sourceURL = artifactsURL.appendingPathComponent(relativePath)
    try fileManager.createDirectory(at: compiledRootURL, withIntermediateDirectories: true)
    let destinationURL = compiledRootURL.appendingPathComponent(sourceURL.deletingPathExtension().lastPathComponent + ".mlmodelc", isDirectory: true)
    if !fileManager.fileExists(atPath: destinationURL.path) {
      let temporaryCompiledURL = try MLModel.compileModel(at: sourceURL)
      if fileManager.fileExists(atPath: destinationURL.path) {
        try fileManager.removeItem(at: destinationURL)
      }
      try fileManager.copyItem(at: temporaryCompiledURL, to: destinationURL)
    }
    compiledURLs[relativePath] = destinationURL
    return destinationURL
  }
}
