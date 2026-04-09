// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "KokoroRuntimeSwift",
  platforms: [
    .macOS(.v15),
    .iOS(.v18),
  ],
  products: [
    .library(name: "KokoroRuntime", targets: ["KokoroRuntime"]),
    .executable(name: "kokoro-runtime", targets: ["KokoroRuntimeCLI"]),
  ],
  dependencies: [
    .package(url: "https://github.com/ml-explore/mlx-swift", exact: "0.30.2"),
    .package(url: "https://github.com/mlalma/MLXUtilsLibrary.git", exact: "0.0.6"),
  ],
  targets: [
    .target(
      name: "KokoroSwift",
      dependencies: [
        .product(name: "MLX", package: "mlx-swift"),
        .product(name: "MLXNN", package: "mlx-swift"),
        .product(name: "MLXRandom", package: "mlx-swift"),
        .product(name: "MLXFFT", package: "mlx-swift"),
        .product(name: "MLXUtilsLibrary", package: "MLXUtilsLibrary"),
      ]
    ),
    .target(name: "KokoroANE"),
    .target(
      name: "KokoroRuntime",
      dependencies: ["KokoroSwift", "KokoroANE"]
    ),
    .executableTarget(
      name: "KokoroRuntimeCLI",
      dependencies: ["KokoroRuntime"]
    ),
    .testTarget(
      name: "KokoroSwiftTests",
      dependencies: ["KokoroSwift"]
    ),
    .testTarget(
      name: "KokoroANETests",
      dependencies: ["KokoroANE"]
    ),
    .testTarget(
      name: "KokoroRuntimeTests",
      dependencies: ["KokoroRuntime"]
    ),
  ]
)
