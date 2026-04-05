import CryptoKit
import Foundation

final class OverlaySettingsStore: @unchecked Sendable {
    static let shared = OverlaySettingsStore()

    private let baseDirectory: URL

    init(baseDirectory: URL? = nil) {
        if let baseDirectory {
            self.baseDirectory = baseDirectory
        } else {
            let appSupport = try? FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )

            self.baseDirectory = (appSupport ?? FileManager.default.temporaryDirectory)
                .appendingPathComponent("OverlayNotes", isDirectory: true)
                .appendingPathComponent("OverlaySettings", isDirectory: true)
        }
    }

    func stableIdentifier(for fileURL: URL) -> String {
        let standardized = fileURL.standardizedFileURL.path
        let digest = SHA256.hash(data: Data(standardized.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    func load(for fileURL: URL) -> OverlaySettings? {
        load(forIdentifier: stableIdentifier(for: fileURL))
    }

    func load(forIdentifier identifier: String) -> OverlaySettings? {
        let fileURL = settingsURL(for: identifier)
        guard let data = try? Data(contentsOf: fileURL) else {
            return nil
        }

        let decoder = JSONDecoder()
        return try? decoder.decode(OverlaySettings.self, from: data)
    }

    func save(_ settings: OverlaySettings, for fileURL: URL) throws {
        try save(settings, forIdentifier: stableIdentifier(for: fileURL))
    }

    func save(_ settings: OverlaySettings, forIdentifier identifier: String) throws {
        try FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        let fileURL = settingsURL(for: identifier)
        let encoder = JSONEncoder()
        let data = try encoder.encode(settings)
        try data.write(to: fileURL, options: .atomic)
    }

    private func settingsURL(for identifier: String) -> URL {
        baseDirectory.appendingPathComponent(identifier).appendingPathExtension("json")
    }
}
