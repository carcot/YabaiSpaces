import Foundation
import TOMLDecoder

enum CapsConfiguration {
    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    private struct Key: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { return nil }
    }

    private struct Entry: Decodable {
        let app: String?
        let space: Int?
        let match: String?
        let disabled: Bool?

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Key.self)
            let fields = Set(container.allKeys.map(\.stringValue))
            guard fields.isSubset(of: ["app", "space", "match", "disabled"]) else {
                throw Failure(message: "Unknown binding fields: \(fields.subtracting(["app", "space", "match", "disabled"]).sorted().joined(separator: ", "))")
            }
            app = try container.decodeIfPresent(String.self, forKey: Key(stringValue: "app")!)
            space = try container.decodeIfPresent(Int.self, forKey: Key(stringValue: "space")!)
            match = try container.decodeIfPresent(String.self, forKey: Key(stringValue: "match")!)
            disabled = try container.decodeIfPresent(Bool.self, forKey: Key(stringValue: "disabled")!)
        }
    }

    private struct Document: Decodable {
        let caps: [String: Entry]

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Key.self)
            guard Set(container.allKeys.map(\.stringValue)) == ["caps"] else {
                throw Failure(message: "Expected only a [caps] table")
            }
            caps = try container.decode([String: Entry].self, forKey: Key(stringValue: "caps")!)
        }
    }

    static func parse(_ data: Data) throws -> [String: CapsBinding] {
        let document: Document
        do {
            document = try TOMLDecoder().decode(Document.self, from: data)
        } catch let error as Failure {
            throw error
        } catch {
            throw Failure(message: String(describing: error))
        }
        var bindings: [String: CapsBinding] = [:]
        for (key, entry) in document.caps {
            guard key.count == 1, "abcdefghijklmnopqrstuvwxyz".contains(key) else {
                throw Failure(message: "Caps key '\(key)' must be one lowercase letter a–z")
            }
            if entry.disabled != nil {
                guard entry.disabled == true, entry.app == nil, entry.space == nil, entry.match == nil else {
                    throw Failure(message: "caps.\(key): disabled must be true and cannot accompany app, space, or match")
                }
                continue
            }
            guard let app = entry.app, !app.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw Failure(message: "caps.\(key): app must be a nonempty string")
            }
            guard entry.space == nil || (entry.space! > 0 && entry.space! <= Int(Int32.max)) else {
                throw Failure(message: "caps.\(key): space must be a positive integer")
            }
            guard let match = CapsBinding.Match(rawValue: entry.match ?? "exact") else {
                throw Failure(message: "caps.\(key): match must be 'exact' or 'contains'")
            }
            bindings[key] = CapsBinding(app: app, space: entry.space, match: match)
        }
        return bindings
    }

    static var defaultText: String {
        let entries = CapsBinding.defaults.sorted { $0.key < $1.key }.map { key, binding in
            let app = binding.app.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
            var fields = ["app = \"\(app)\""]
            if let space = binding.space { fields.append("space = \(space)") }
            if binding.match == .contains { fields.append("match = \"contains\"") }
            return "\(key) = { \(fields.joined(separator: ", ")) }"
        }
        return "# Reload from the YS menu or with: YabaiIndicator config reload\n# Missing letters dismiss the prefix. Numbers and period keep their built-in actions.\n[caps]\n"
            + entries.joined(separator: "\n") + "\n"
    }
}

final class CapsConfigurationStore {
    static let defaultURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/yabaispaces/config.toml")
    let url: URL
    private let lock = NSLock()
    private let reloadLock = NSLock()
    private var bindings = CapsBinding.defaults

    init(url: URL = CapsConfigurationStore.defaultURL) { self.url = url }

    func resolve(_ command: JumpCommand) -> JumpCommand {
        lock.lock()
        defer { lock.unlock() }
        return JumpCommand(rawValue: command.rawValue, bindings: bindings)!
    }

    @discardableResult
    func reload(createIfMissing: Bool = false) throws -> Int {
        reloadLock.lock()
        defer { reloadLock.unlock() }
        if createIfMissing && !FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            do {
                try Data(CapsConfiguration.defaultText.utf8).write(to: url, options: .withoutOverwriting)
            } catch let error as CocoaError where error.code == .fileWriteFileExists {}
        }
        let resolvedURL = url.resolvingSymlinksInPath()
        let attributes = try FileManager.default.attributesOfItem(atPath: resolvedURL.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular else {
            throw CapsConfiguration.Failure(message: "Caps configuration must be a regular file")
        }
        let handle = try FileHandle(forReadingFrom: resolvedURL)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: 65_537) ?? Data()
        guard data.count <= 65_536 else {
            throw CapsConfiguration.Failure(message: "Caps configuration exceeds 64 KiB")
        }
        let replacement = try CapsConfiguration.parse(data)
        lock.lock()
        bindings = replacement
        lock.unlock()
        return replacement.count
    }
}
