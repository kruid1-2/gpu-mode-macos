import Foundation

enum GPUMode: Int, CaseIterable, Identifiable, Sendable {
    case integrated = 0
    case discrete = 1
    case automatic = 2
    case unknown = -1

    var id: Int { rawValue }

    static var switchableCases: [GPUMode] {
        [.automatic, .integrated, .discrete]
    }

    init(gpuSwitchValue: Int) {
        switch gpuSwitchValue {
        case 0:
            self = .integrated
        case 1:
            self = .discrete
        case 2:
            self = .automatic
        default:
            self = .unknown
        }
    }

    var gpuSwitchValue: Int? {
        switch self {
        case .integrated:
            0
        case .discrete:
            1
        case .automatic:
            2
        case .unknown:
            nil
        }
    }

    var title: String {
        switch self {
        case .integrated:
            "集显优先"
        case .discrete:
            "独显优先"
        case .automatic:
            "自动切换"
        case .unknown:
            "未知"
        }
    }

    var shortTitle: String {
        switch self {
        case .integrated:
            "集显"
        case .discrete:
            "独显"
        case .automatic:
            "自动"
        case .unknown:
            "未知"
        }
    }

    var subtitle: String {
        switch self {
        case .integrated:
            "优先使用 Intel 集成显卡"
        case .discrete:
            "强制使用 AMD 独立显卡"
        case .automatic:
            "交给 macOS 自动判断"
        case .unknown:
            "没有读到 gpuswitch 状态"
        }
    }

    var symbolName: String {
        switch self {
        case .integrated:
            "leaf.fill"
        case .discrete:
            "bolt.fill"
        case .automatic:
            "arrow.triangle.2.circlepath"
        case .unknown:
            "questionmark.circle"
        }
    }

    var menuBarSymbolName: String {
        switch self {
        case .integrated:
            "leaf"
        case .discrete:
            "bolt"
        case .automatic:
            "gauge.with.dots.needle.50percent"
        case .unknown:
            "questionmark.circle"
        }
    }
}
