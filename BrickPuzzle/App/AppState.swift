import Foundation
import Combine

struct LevelProgress: Codable, Equatable {
    var bestStars: Int
    var bestShotCount: Int?
    var completionCount: Int

    static let empty = LevelProgress(bestStars: 0, bestShotCount: nil, completionCount: 0)

    mutating func record(_ result: AttemptResult) {
        guard result.stars != .none else { return }
        completionCount += 1
        bestStars = max(bestStars, result.stars.rawValue)
        if let currentBest = bestShotCount {
            bestShotCount = min(currentBest, result.shotCount)
        } else {
            bestShotCount = result.shotCount
        }
    }
}

struct AppSettings: Codable, Equatable {
    var soundEnabled = true
    var musicEnabled = true
    var hapticsEnabled = true
    var reduceMotion = false
}

protocol KeyValueStoring {
    func data(forKey defaultName: String) -> Data?
    func set(_ value: Any?, forKey defaultName: String)
}

extension UserDefaults: KeyValueStoring {}

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var progress: [String: LevelProgress]
    @Published var settings: AppSettings {
        didSet { persistSettings() }
    }

    private let storage: KeyValueStoring
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private static let progressKey = "brick-puzzle.progress.v1"
    private static let settingsKey = "brick-puzzle.settings.v1"

    init(storage: KeyValueStoring = UserDefaults.standard) {
        let decoder = JSONDecoder()
        self.storage = storage
        progress = storage.data(forKey: Self.progressKey)
            .flatMap { try? decoder.decode([String: LevelProgress].self, from: $0) } ?? [:]
        settings = storage.data(forKey: Self.settingsKey)
            .flatMap { try? decoder.decode(AppSettings.self, from: $0) } ?? AppSettings()
    }

    func progress(for levelID: String) -> LevelProgress {
        progress[levelID] ?? .empty
    }

    func record(_ result: AttemptResult, for levelID: String) {
        var updated = progress[levelID] ?? .empty
        updated.record(result)
        progress[levelID] = updated
        if let data = try? encoder.encode(progress) {
            storage.set(data, forKey: Self.progressKey)
        }
    }

    private func persistSettings() {
        if let data = try? encoder.encode(settings) {
            storage.set(data, forKey: Self.settingsKey)
        }
    }
}
