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
            discreteGPUClients: [],
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
            discreteGPUClients: [],
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
            discreteGPUClients: [],
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

    func testActiveDiscreteGPUDetection() {
        let info = HardwareInfo(
            architecture: "x86_64",
            detectedGPUs: ["Intel UHD Graphics 630", "AMD Radeon Pro 560X"],
            activeGPUCandidates: ["AMD Radeon Pro 560X"],
            discreteGPUClients: [],
            hasIntelGPU: true,
            hasAMDGPU: true,
            hasExternalDisplay: false,
            supportsAutomaticGraphicsSwitching: true,
            pmsetHasGPUSwitch: true,
            warningMessage: nil
        )

        XCTAssertTrue(info.hasActiveDiscreteGPU)
    }

    func testDiscreteGPUClientDetection() {
        let info = HardwareInfo(
            architecture: "x86_64",
            detectedGPUs: ["Intel UHD Graphics 630", "AMD Radeon Pro 560X"],
            activeGPUCandidates: ["Intel UHD Graphics 630"],
            discreteGPUClients: ["Music"],
            hasIntelGPU: true,
            hasAMDGPU: true,
            hasExternalDisplay: false,
            supportsAutomaticGraphicsSwitching: true,
            pmsetHasGPUSwitch: true,
            warningMessage: nil
        )

        XCTAssertTrue(info.hasActiveDiscreteGPU)
    }

    func testDiscreteGPUClientParsing() {
        let output = #"""
          |   "mux-app-list" = ()
          |   "task-runtime" = ("1607,1535116,Music","1392,6456256,promecefpluginhost (GPU)")
          |   "task-list" = (1607,1392)
        """#

        XCTAssertEqual(
            HardwareInfoService.parseDiscreteGPUClients(from: output),
            ["Music", "promecefpluginhost (GPU)"]
        )
    }
}
