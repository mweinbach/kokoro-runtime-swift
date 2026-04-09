import Foundation
import Testing
@testable import KokoroANE

@Test func alignmentBuilderPadsToBucket() {
  let matrix = AlignmentBuilder.buildAlignment(predictedDurations: [2, 1, 1], tokenCount: 3, tokenLimit: 5, frameCount: 6)
  #expect(matrix.count == 30)
  let nonZero = matrix.filter { $0 > 0 }
  #expect(nonZero.count == 6)
}

@Test func tokenizerUsesConfigVocab() {
  let tokens = KokoroANETokenizer.tokenize(phonemes: "aba", vocab: ["a": 1, "b": 2])
  #expect(tokens == [1, 2, 1])
}
