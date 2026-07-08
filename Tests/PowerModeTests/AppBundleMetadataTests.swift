import Foundation
import XCTest

final class AppBundleMetadataTests: XCTestCase {
    func testGeneratedAppDeclaresAutomaticGraphicsSwitchingSupport() throws {
        let script = try String(contentsOf: repositoryRoot().appendingPathComponent("script/build_and_run.sh"))

        XCTAssertTrue(script.contains("<key>NSSupportsAutomaticGraphicsSwitching</key>\n  <true/>"))
    }

    private func repositoryRoot() throws -> URL {
        var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()

        while directory.path != "/" {
            let candidate = directory.appendingPathComponent("Package.swift")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return directory
            }
            directory.deleteLastPathComponent()
        }

        throw NSError(
            domain: "AppBundleMetadataTests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Could not locate repository root."]
        )
    }
}
