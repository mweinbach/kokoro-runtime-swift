import Foundation

public enum KokoroANETokenizer {
  public static func tokenize(phonemes: String, vocab: [String: Int]) -> [Int] {
    phonemes.compactMap { vocab[String($0)] }
  }
}
