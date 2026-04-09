import CoreML
import Foundation

public enum MultiArrayFactory {
  public static func makeFloat32(_ values: [Float], shape: [Int]) throws -> MLMultiArray {
    let array = try MLMultiArray(shape: shape.map(NSNumber.init(value:)), dataType: .float32)
    let count = values.count
    let ptr = UnsafeMutablePointer<Float>(OpaquePointer(array.dataPointer))
    for index in 0 ..< count {
      ptr[index] = values[index]
    }
    return array
  }

  public static func makeInt32(_ values: [Int32], shape: [Int]) throws -> MLMultiArray {
    let array = try MLMultiArray(shape: shape.map(NSNumber.init(value:)), dataType: .int32)
    let count = values.count
    let ptr = UnsafeMutablePointer<Int32>(OpaquePointer(array.dataPointer))
    for index in 0 ..< count {
      ptr[index] = values[index]
    }
    return array
  }

  public static func floatArray(from multiArray: MLMultiArray) -> [Float] {
    let count = multiArray.count
    switch multiArray.dataType {
    case .float32:
      let ptr = UnsafeMutablePointer<Float>(OpaquePointer(multiArray.dataPointer))
      return Array(UnsafeBufferPointer(start: ptr, count: count))
    case .float16:
      let ptr = UnsafeMutablePointer<Float16>(OpaquePointer(multiArray.dataPointer))
      return Array(UnsafeBufferPointer(start: ptr, count: count)).map(Float.init)
    case .double:
      let ptr = UnsafeMutablePointer<Double>(OpaquePointer(multiArray.dataPointer))
      return Array(UnsafeBufferPointer(start: ptr, count: count)).map(Float.init)
    case .int32:
      let ptr = UnsafeMutablePointer<Int32>(OpaquePointer(multiArray.dataPointer))
      return Array(UnsafeBufferPointer(start: ptr, count: count)).map(Float.init)
    default:
      preconditionFailure("Unsupported MLMultiArray dtype: \(multiArray.dataType)")
    }
  }

  public static func intArray(from multiArray: MLMultiArray) -> [Int] {
    let count = multiArray.count
    switch multiArray.dataType {
    case .int32:
      let ptr = UnsafeMutablePointer<Int32>(OpaquePointer(multiArray.dataPointer))
      return Array(UnsafeBufferPointer(start: ptr, count: count)).map(Int.init)
    case .float32:
      let ptr = UnsafeMutablePointer<Float>(OpaquePointer(multiArray.dataPointer))
      return Array(UnsafeBufferPointer(start: ptr, count: count)).map { Int($0.rounded()) }
    case .float16:
      let ptr = UnsafeMutablePointer<Float16>(OpaquePointer(multiArray.dataPointer))
      return Array(UnsafeBufferPointer(start: ptr, count: count)).map { Int(Float($0).rounded()) }
    default:
      preconditionFailure("Unsupported MLMultiArray dtype: \(multiArray.dataType)")
    }
  }
}
