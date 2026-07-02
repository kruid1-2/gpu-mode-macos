import XCTest
@testable import PowerMode

final class GPUModeTests: XCTestCase {
    func testGPUSwitchValueMapping() {
        XCTAssertEqual(GPUMode(gpuSwitchValue: 0), .integrated)
        XCTAssertEqual(GPUMode(gpuSwitchValue: 1), .discrete)
        XCTAssertEqual(GPUMode(gpuSwitchValue: 2), .automatic)
        XCTAssertEqual(GPUMode(gpuSwitchValue: 9), .unknown)
    }

    func testAppleSiliconIsUnsupported() {
        let info = HardwareInfo(
            architecture: "arm64",
            detectedGPUs: ["Apple M-series"],
            activeGPUCandidates: [],
            hasIntelGPU: false,
            hasAMDGPU: false,
            hasExternalDisplay: false,
            supportsAutomaticGraphicsSwitching: false,
            pmsetHasGPUSwitch: false,
            warningMessage: nil
        )

        XCTAssertFalse(info.isSupported)
        XCTAssertTrue(info.compatibilityMessage.contains("Apple Silicon"))
    }

    func testMissingDualGPUIsUnsupported() {
        let info = HardwareInfo(
            architecture: "x86_64",
            detectedGPUs: ["Intel UHD Graphics 630"],
            activeGPUCandidates: ["Intel UHD Graphics 630"],
            hasIntelGPU: true,
            hasAMDGPU: false,
            hasExternalDisplay: false,
            supportsAutomaticGraphicsSwitching: false,
            pmsetHasGPUSwitch: true,
            warningMessage: nil
        )

        XCTAssertFalse(info.isSupported)
        XCTAssertTrue(info.compatibilityMessage.contains("Intel + AMD"))
    }

    func testMissingGPUSwitchIsUnsupported() {
        let info = HardwareInfo(
            architecture: "x86_64",
            detectedGPUs: ["Intel UHD Graphics 630", "AMD Radeon Pro"],
            activeGPUCandidates: ["Intel UHD Graphics 630"],
            hasIntelGPU: true,
            hasAMDGPU: true,
            hasExternalDisplay: false,
            supportsAutomaticGraphicsSwitching: true,
            pmsetHasGPUSwitch: false,
            warningMessage: nil
        )

        XCTAssertFalse(info.isSupported)
        XCTAssertTrue(info.compatibilityMessage.contains("不支持此功能"))
    }
}
