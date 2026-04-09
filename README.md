# Kokoro Runtime Swift

Unified Swift package for running Kokoro with either:
- MLX (`KokoroSwift`)
- Core ML / ANE (`KokoroANE`)

Model bundles are hosted on Hugging Face:
- https://huggingface.co/mweinbach/kokoro-runtime-swift

## Requirements

- macOS 15+
- Swift 6.2
- Xcode 26+ recommended
- Apple Silicon for MLX / ANE usage

## Install

### As a package dependency

```swift
.package(url: "https://github.com/mweinbach/kokoro-runtime-swift", branch: "main")
```

Products:
- `KokoroRuntime`
- executable `kokoro-runtime`

### Build the CLI

```bash
git clone https://github.com/mweinbach/kokoro-runtime-swift
cd kokoro-runtime-swift
swift build -c release
```

## CLI

### 1. Download model bundles

```bash
swift run kokoro-runtime download --backend all --output-dir ./kokoro-bundle
```

This creates:
- `./kokoro-bundle/mlx`
- `./kokoro-bundle/coreml`

You can also download a single backend:

```bash
swift run kokoro-runtime download --backend mlx --output-dir ./kokoro-bundle
swift run kokoro-runtime download --backend coreml --output-dir ./kokoro-bundle
```

### 2. Compile Core ML models

```bash
swift run kokoro-runtime compile-coreml --bundle-dir ./kokoro-bundle
```

This compiles the downloaded `.mlpackage` files into `./kokoro-bundle/coreml/Artifacts/.compiled`.

### 3. Run MLX

```bash
swift run kokoro-runtime run \
  --backend mlx \
  --bundle-dir ./kokoro-bundle \
  --voice af_heart \
  --phonemes "həlˈO wˈɜɹld." \
  --seed 0 \
  --output-wav ./mlx.wav
```

### 4. Run Core ML / ANE

```bash
swift run kokoro-runtime run \
  --backend coreml \
  --bundle-dir ./kokoro-bundle \
  --voice af_heart \
  --phonemes "həlˈO wˈɜɹld." \
  --seed 0 \
  --output-wav ./coreml.wav
```

Optional Core ML placement flags:

```bash
swift run kokoro-runtime run \
  --backend coreml \
  --bundle-dir ./kokoro-bundle \
  --voice af_heart \
  --phonemes "həlˈO wˈɜɹld." \
  --duration-compute all \
  --f0n-compute cpu_and_ne \
  --prehar-compute cpu_only \
  --tail-compute all
```

Accepted values:
- `all`
- `cpu_only`
- `cpu_and_ne`
- `cpu_and_gpu`

Current default Core ML placement is:
- duration: `all`
- f0n: `cpu_and_ne`
- prehar: `cpu_only`
- tail: `all`

## Library usage

### MLX

```swift
import Foundation
import KokoroRuntime

let result = try KokoroRuntime.runMLX(
  bundleRoot: URL(fileURLWithPath: "./kokoro-bundle"),
  voice: "af_heart",
  phonemes: "həlˈO wˈɜɹld.",
  speed: 1.0,
  seed: 0
)
```

### Core ML

```swift
import Foundation
import KokoroRuntime

let result = try KokoroRuntime.runCoreML(
  bundleRoot: URL(fileURLWithPath: "./kokoro-bundle"),
  voice: "af_heart",
  phonemes: "həlˈO wˈɜɹld.",
  speed: 1.0,
  seed: 0
)
```

## Notes

- The current package is phoneme-input oriented.
- MLX runtime expects the downloaded `mlx.metallib` bundle asset; the CLI stages it automatically when needed.
- Core ML first-run latency is higher because model loading/compilation is cold; warm runs are much faster.
