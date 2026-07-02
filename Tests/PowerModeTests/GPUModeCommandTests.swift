import GPUModeShared
import XCTest

final class GPUModeCommandTests: XCTestCase {
    func testOnlyZeroOneTwoAreAccepted() {
        XCTAssertTrue(GPUModeCommandFactory.isValidMode(0))
        XCTAssertTrue(GPUModeCommandFactory.isValidMode(1))
        XCTAssertTrue(GPUModeCommandFactory.isValidMode(2))

        XCTAssertFalse(GPUModeCommandFactory.isValidMode(-1))
        XCTAssertFalse(GPUModeCommandFactory.isValidMode(3))
        XCTAssertFalse(GPUModeCommandFactory.isValidMode(99))
    }

    func testCommandConstructionIsFixed() {
        XCTAssertEqual(
            GPUModeCommandFactory.setModeCommand(for: 0),
            GPUModeCommandSpec(executablePath: "/usr/bin/pmset", arguments: ["-a", "gpuswitch", "0"])
        )
        XCTAssertEqual(
            GPUModeCommandFactory.setModeCommand(for: 1),
            GPUModeCommandSpec(executablePath: "/usr/bin/pmset", arguments: ["-a", "gpuswitch", "1"])
        )
        XCTAssertEqual(
            GPUModeCommandFactory.setModeCommand(for: 2),
            GPUModeCommandSpec(executablePath: "/usr/bin/pmset", arguments: ["-a", "gpuswitch", "2"])
        )
    }

    func testInvalidModesDoNotProduceCommands() {
        XCTAssertNil(GPUModeCommandFactory.setModeCommand(for: -1))
        XCTAssertNil(GPUModeCommandFactory.setModeCommand(for: 3))
        XCTAssertNil(GPUModeCommandFactory.setModeCommand(for: Int.max))
    }
}
