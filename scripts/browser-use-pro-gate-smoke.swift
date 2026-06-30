import Foundation

@main
enum BrowserUseProGateSmoke {
    static func main() throws {
        guard CommandLine.arguments.count == 2 else {
            throw SmokeError.usage("Usage: browser-use-pro-gate-smoke BrowserUsePro.bundle")
        }

        let bundleURL = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
            .standardizedFileURL
        let manifestURL = bundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Resources", isDirectory: true)
            .appendingPathComponent("BrowserUsePro", isDirectory: true)
            .appendingPathComponent("VENDOR_MANIFEST.json", isDirectory: false)

        let off = BrowserUseProGateStatus.status(
            environment: [:],
            manifestURL: manifestURL
        )
        guard !off.isActive, off.headline == "browser-use Pro: off" else {
            throw SmokeError.failed("expected default-off gate, got active=\(off.isActive) headline=\(off.headline)")
        }

        let on = BrowserUseProGateStatus.status(
            environment: [BrowserUseProGateStatus.flagName: "1"],
            manifestURL: manifestURL
        )
        guard on.isActive, on.headline == "browser-use Pro: signed packaged payload ready" else {
            throw SmokeError.failed("expected signed packaged gate, got active=\(on.isActive) headline=\(on.headline) detail=\(on.detail)")
        }

        print("browser-use Pro gate smoke OK: \(on.headline)")
    }

    enum SmokeError: Error, CustomStringConvertible {
        case usage(String)
        case failed(String)

        var description: String {
            switch self {
            case .usage(let message),
                 .failed(let message):
                message
            }
        }
    }
}
