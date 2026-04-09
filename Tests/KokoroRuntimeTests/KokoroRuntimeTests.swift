import Foundation
import Testing
@testable import KokoroRuntime

@Test func bundleLayoutBuildsExpectedPaths() {
  let layout = KokoroBundleLayout(rootURL: URL(fileURLWithPath: "/tmp/kokoro"))
  #expect(layout.mlxURL.path == "/tmp/kokoro/mlx")
  #expect(layout.coremlArtifactsURL.path == "/tmp/kokoro/coreml/Artifacts")
}
