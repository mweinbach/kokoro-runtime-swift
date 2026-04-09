import Foundation

public enum AlignmentBuilder {
  public static func buildAlignment(predictedDurations: [Int], tokenCount: Int, tokenLimit: Int, frameCount: Int) -> [Float] {
    var trimmed = Array(repeating: 0, count: tokenLimit)
    let copyCount = min(tokenCount, min(tokenLimit, predictedDurations.count))
    if copyCount > 0 {
      for index in 0 ..< copyCount {
        trimmed[index] = max(1, predictedDurations[index])
      }
    }
    var repeated: [Int] = []
    repeated.reserveCapacity(max(frameCount, tokenLimit))
    for (index, duration) in trimmed.enumerated() {
      repeated.append(contentsOf: repeatElement(index, count: duration))
      if repeated.count >= frameCount {
        break
      }
    }
    if repeated.isEmpty {
      repeated = Array(repeating: 0, count: frameCount)
    } else if repeated.count < frameCount {
      repeated.append(contentsOf: repeatElement(repeated.last ?? 0, count: frameCount - repeated.count))
    } else if repeated.count > frameCount {
      repeated = Array(repeated.prefix(frameCount))
    }

    var matrix = Array(repeating: Float(0), count: tokenLimit * frameCount)
    for frame in 0 ..< frameCount {
      let tokenIndex = max(0, min(repeated[frame], tokenLimit - 1))
      matrix[tokenIndex * frameCount + frame] = 1
    }
    return matrix
  }

  public static func predictedFrameCount(predictedDurations: [Int], tokenCount: Int, tokenLimit: Int) -> Int {
    predictedDurations.prefix(min(tokenCount, tokenLimit)).reduce(0) { $0 + max(1, $1) }
  }
}
