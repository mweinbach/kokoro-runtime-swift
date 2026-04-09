import Accelerate
import Foundation

public enum MatrixOps {
  public static func matmulRowMajor(_ a: [Float], rowsA: Int, colsA: Int, _ b: [Float], colsB: Int) -> [Float] {
    var output = Array(repeating: Float(0), count: rowsA * colsB)
    cblas_sgemm(
      CblasRowMajor,
      CblasNoTrans,
      CblasNoTrans,
      Int32(rowsA),
      Int32(colsB),
      Int32(colsA),
      1,
      a,
      Int32(colsA),
      b,
      Int32(colsB),
      0,
      &output,
      Int32(colsB)
    )
    return output
  }
}
