import CoreML
import Foundation
import KokoroANE

public struct KokoroCoreMLComputeUnits: Sendable {
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

  var aneValue: KokoroANEComputeUnits {
    KokoroANEComputeUnits(duration: duration, f0n: f0n, prehar: prehar, tail: tail)
  }
}
