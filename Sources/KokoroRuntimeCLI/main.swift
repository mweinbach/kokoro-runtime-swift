import AVFoundation
import CoreML
import Foundation
import KokoroRuntime

struct CLIError: Error, CustomStringConvertible {
  let message: String
  var description: String { message }
}

func argument(_ name: String, in arguments: [String]) -> String? {
  guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else {
    return nil
  }
  return arguments[index + 1]
}

func parseComputeUnits(_ value: String) -> MLComputeUnits {
  switch value {
  case "all":
    return .all
  case "cpu_only":
    return .cpuOnly
  case "cpu_and_gpu":
    return .cpuAndGPU
  default:
    return .cpuAndNeuralEngine
  }
}

func writeWav(samples: [Float], sampleRate: Double, to fileURL: URL) throws {
  let frameCount = AVAudioFrameCount(samples.count)
  guard
    let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false),
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)
  else {
    throw CLIError(message: "Failed to create audio buffer")
  }
  buffer.frameLength = frameCount
  let channelData = buffer.floatChannelData![0]
  for index in 0 ..< Int(frameCount) {
    channelData[index] = samples[index]
  }
  let audioFile = try AVAudioFile(forWriting: fileURL, settings: format.settings, commonFormat: format.commonFormat, interleaved: format.isInterleaved)
  try audioFile.write(from: buffer)
}

func command(_ arguments: [String]) -> String? {
  guard arguments.count > 1 else { return nil }
  return arguments[1]
}

@main
struct KokoroRuntimeCLI {
  static func main() throws {
    let arguments = CommandLine.arguments
    switch command(arguments) {
    case "download":
      let output = URL(fileURLWithPath: argument("--output-dir", in: arguments) ?? FileManager.default.currentDirectoryPath)
      let backend = argument("--backend", in: arguments) ?? "all"
      switch backend {
      case "mlx":
        try KokoroDownloader.download(backend: .mlx, to: output)
      case "coreml":
        try KokoroDownloader.download(backend: .coreml, to: output)
      default:
        try KokoroDownloader.downloadAll(to: output)
      }
      print("{\"command\":\"download\",\"output_dir\":\"\(output.path)\",\"backend\":\"\(backend)\"}")

    case "compile-coreml":
      let bundleRoot = URL(fileURLWithPath: argument("--bundle-dir", in: arguments) ?? FileManager.default.currentDirectoryPath)
      let layout = KokoroBundleLayout(rootURL: bundleRoot)
      try KokoroCoreMLCompiler.compileAll(artifactsURL: layout.coremlArtifactsURL)
      print("{\"command\":\"compile-coreml\",\"artifacts_dir\":\"\(layout.coremlArtifactsURL.path)\"}")

    case "run":
      guard let backendName = argument("--backend", in: arguments) else {
        throw CLIError(message: "Missing --backend")
      }
      guard let bundleDir = argument("--bundle-dir", in: arguments) else {
        throw CLIError(message: "Missing --bundle-dir")
      }
      guard let voice = argument("--voice", in: arguments) else {
        throw CLIError(message: "Missing --voice")
      }
      guard let phonemes = argument("--phonemes", in: arguments) else {
        throw CLIError(message: "Missing --phonemes")
      }
      let seed = UInt64(argument("--seed", in: arguments) ?? "0") ?? 0
      let speed = Float(argument("--speed", in: arguments) ?? "1.0") ?? 1.0
      let bundleRoot = URL(fileURLWithPath: bundleDir)
      let start = Date()
      let result: KokoroRunResult
      if backendName == "mlx" {
        result = try KokoroRuntime.runMLX(bundleRoot: bundleRoot, voice: voice, phonemes: phonemes, speed: speed, seed: seed)
      } else {
        let computeUnits = KokoroCoreMLComputeUnits(
          duration: parseComputeUnits(argument("--duration-compute", in: arguments) ?? "all"),
          f0n: parseComputeUnits(argument("--f0n-compute", in: arguments) ?? "cpu_and_ne"),
          prehar: parseComputeUnits(argument("--prehar-compute", in: arguments) ?? "cpu_only"),
          tail: parseComputeUnits(argument("--tail-compute", in: arguments) ?? "all")
        )
        result = try KokoroRuntime.runCoreML(bundleRoot: bundleRoot, voice: voice, phonemes: phonemes, speed: speed, seed: seed, computeUnits: computeUnits)
      }
      let elapsed = Date().timeIntervalSince(start)
      if let outputWav = argument("--output-wav", in: arguments) {
        try writeWav(samples: result.samples, sampleRate: Double(result.sampleRate), to: URL(fileURLWithPath: outputWav))
      }
      let audioSeconds = Double(result.samples.count) / Double(result.sampleRate)
      let payload: [String: Any] = [
        "command": "run",
        "backend": backendName,
        "bundle_dir": bundleRoot.path,
        "voice": voice,
        "seed": seed,
        "samples": result.samples.count,
        "sample_rate": result.sampleRate,
        "audio_seconds": audioSeconds,
        "elapsed_seconds": elapsed,
        "rtfx": elapsed > 0 ? audioSeconds / elapsed : 0,
      ]
      let data = try JSONSerialization.data(withJSONObject: payload)
      print(String(decoding: data, as: UTF8.self))

    default:
      throw CLIError(message: "Usage: kokoro-runtime <download|compile-coreml|run> [options]")
    }
  }
}
