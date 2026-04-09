import Foundation
import Testing
@testable import KokoroSwift

@Test func loadConfigFromFile() throws {
  let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  let configURL = tempURL.appendingPathComponent("config.json")
  try FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true)
  let json = """
  {
    "istftnet": {
      "upsample_kernel_sizes": [20, 12],
      "upsample_rates": [10, 6],
      "gen_istft_hop_size": 5,
      "gen_istft_n_fft": 20,
      "resblock_dilation_sizes": [[1, 3, 5], [1, 3, 5], [1, 3, 5]],
      "resblock_kernel_sizes": [3, 7, 11],
      "upsample_initial_channel": 512
    },
    "dim_in": 64,
    "dropout": 0.2,
    "hidden_dim": 512,
    "max_conv_dim": 512,
    "max_dur": 50,
    "multispeaker": true,
    "n_layer": 3,
    "n_mels": 80,
    "n_token": 178,
    "style_dim": 128,
    "text_encoder_kernel_size": 5,
    "plbert": {
      "hidden_size": 768,
      "num_attention_heads": 12,
      "intermediate_size": 2048,
      "max_position_embeddings": 512,
      "num_hidden_layers": 12,
      "dropout": 0.1
    },
    "vocab": {"a": 1, "b": 2}
  }
  """
  try json.write(to: configURL, atomically: true, encoding: .utf8)

  let config = try KokoroConfig.loadConfig(from: configURL)
  #expect(config.hiddenDim == 512)
  #expect(config.vocab["a"] == 1)
}

@Test func tokenizerUsesLoadedConfig() throws {
  let data = Data(
    "{\"istftnet\":{\"upsample_kernel_sizes\":[20,12],\"upsample_rates\":[10,6],\"gen_istft_hop_size\":5,\"gen_istft_n_fft\":20,\"resblock_dilation_sizes\":[[1,3,5],[1,3,5],[1,3,5]],\"resblock_kernel_sizes\":[3,7,11],\"upsample_initial_channel\":512},\"dim_in\":64,\"dropout\":0.2,\"hidden_dim\":512,\"max_conv_dim\":512,\"max_dur\":50,\"multispeaker\":true,\"n_layer\":3,\"n_mels\":80,\"n_token\":178,\"style_dim\":128,\"text_encoder_kernel_size\":5,\"plbert\":{\"hidden_size\":768,\"num_attention_heads\":12,\"intermediate_size\":2048,\"max_position_embeddings\":512,\"num_hidden_layers\":12,\"dropout\":0.1},\"vocab\":{\"a\":1,\"b\":2}}".utf8
  )
  KokoroConfig.config = try JSONDecoder().decode(KokoroConfig.self, from: data)

  let tokenized = Tokenizer.tokenize(phonemizedText: "aba")
  #expect(tokenized == [1, 2, 1])
}
