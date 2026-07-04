import Foundation

struct LevelBundleLoader {
    private let levelsDirectoryURL: URL?
    private let bundle: Bundle
    private let subdirectory: String
    private let decoder: JSONDecoder

    init(bundle: Bundle = .main, subdirectory: String = "Levels", decoder: JSONDecoder = JSONDecoder()) {
        self.levelsDirectoryURL = nil
        self.bundle = bundle
        self.subdirectory = subdirectory
        self.decoder = decoder
    }

    init(levelsDirectoryURL: URL, decoder: JSONDecoder = JSONDecoder()) {
        self.levelsDirectoryURL = levelsDirectoryURL
        self.bundle = .main
        self.subdirectory = ""
        self.decoder = decoder
    }

    func loadLevel(id: String) throws -> LevelDefinition {
        let levels = try loadAllLevels()

        guard let level = levels.first(where: { $0.id == id }) else {
            throw LevelLoadingError.missingLevel(id: id)
        }

        return level
    }

    func loadAllLevels() throws -> [LevelDefinition] {
        let directory = try levelsDirectory()
        let fileURLs = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension == "json" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }

        guard !fileURLs.isEmpty else {
            throw LevelLoadingError.emptyCatalog
        }

        let levels = try fileURLs.map(decodeLevel)
        let duplicateID = levels
            .map(\.id)
            .first { id in levels.filter { $0.id == id }.count > 1 }

        if let duplicateID {
            throw LevelLoadingError.duplicateLevelID(duplicateID)
        }

        return levels
    }

    static func prototypeLevel(bundle: Bundle = .main) -> LevelDefinition {
        (try? LevelBundleLoader(bundle: bundle).loadLevel(id: "prototype-001")) ?? .prototype
    }

    private func levelsDirectory() throws -> URL {
        if let levelsDirectoryURL {
            return try validatedDirectory(levelsDirectoryURL, label: levelsDirectoryURL.path)
        }

        guard let url = bundle.url(forResource: subdirectory, withExtension: nil) else {
            throw LevelLoadingError.missingLevelsDirectory(subdirectory)
        }

        return try validatedDirectory(url, label: subdirectory)
    }

    private func validatedDirectory(_ url: URL, label: String) throws -> URL {
        var isDirectory = ObjCBool(false)
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw LevelLoadingError.missingLevelsDirectory(label)
        }

        return url
    }

    private func decodeLevel(from fileURL: URL) throws -> LevelDefinition {
        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode(LevelDefinition.self, from: data)
        } catch {
            throw LevelLoadingError.decodeFailed(
                fileName: fileURL.lastPathComponent,
                reason: String(describing: error)
            )
        }
    }
}

enum LevelLoadingError: Error, Equatable, CustomStringConvertible {
    case missingLevelsDirectory(String)
    case missingLevel(id: String)
    case emptyCatalog
    case duplicateLevelID(String)
    case decodeFailed(fileName: String, reason: String)

    var description: String {
        switch self {
        case .missingLevelsDirectory(let subdirectory):
            return "Missing bundled levels directory: \(subdirectory)"
        case .missingLevel(let id):
            return "Missing level fixture with id: \(id)"
        case .emptyCatalog:
            return "Level catalog contains no JSON fixtures."
        case .duplicateLevelID(let id):
            return "Duplicate level fixture id: \(id)"
        case .decodeFailed(let fileName, let reason):
            return "Failed to decode level fixture \(fileName): \(reason)"
        }
    }
}
