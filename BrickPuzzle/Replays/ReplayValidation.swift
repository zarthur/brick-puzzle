import Foundation

struct ReplayFixture: Codable, Hashable {
    let levelID: String
    let selectedPowerups: [PowerupDefinition]
    let shots: [ReplayShot]
    let expectedOutcome: ReplayExpectedOutcome
}

struct ReplayShot: Codable, Hashable {
    let aimAngleDegrees: Double
    let usedPowerups: [PowerupDefinition]
    let destroyedBrickIDs: [String]
}

struct ReplayExpectedOutcome: Codable, Hashable, CustomStringConvertible {
    let completed: Bool
    let stars: Int

    var description: String {
        "completed=\(completed), stars=\(stars)"
    }
}

struct ReplayActualOutcome: Equatable, CustomStringConvertible {
    let completed: Bool
    let stars: Int

    var description: String {
        "completed=\(completed), stars=\(stars)"
    }
}

struct ReplayResult: Equatable {
    let levelID: String
    let shotIndex: Int?
    let expectedOutcome: ReplayExpectedOutcome
    let actualOutcome: ReplayActualOutcome
    let failureMessage: String?

    var passed: Bool {
        failureMessage == nil
    }
}

struct ReplayRunner {
    private let levelLoader: LevelBundleLoader

    init(levelLoader: LevelBundleLoader = LevelBundleLoader()) {
        self.levelLoader = levelLoader
    }

    func validate(_ replay: ReplayFixture) -> ReplayResult {
        do {
            let level = try levelLoader.loadLevel(id: replay.levelID)
            let loadout = PowerupLoadout(selectedPowerups: replay.selectedPowerups)

            guard loadout.isValid(for: level) else {
                return failureResult(
                    replay: replay,
                    shotIndex: nil,
                    actualOutcome: ReplayActualOutcome(completed: false, stars: 0),
                    reason: "Invalid selected powerup loadout."
                )
            }

            var state = try GameState(level: level, loadout: loadout)
            let selectedPowerups = Set(replay.selectedPowerups)
            let brickIDs = Set(state.snapshot.bricks.map(\.id))

            for (index, shot) in replay.shots.enumerated() {
                guard GameState.isValidAim(shot.aimAngleDegrees) else {
                    return failureResult(
                        replay: replay,
                        shotIndex: index,
                        actualOutcome: outcome(for: state),
                        reason: "Invalid aimAngleDegrees: \(shot.aimAngleDegrees)."
                    )
                }

                if let unselectedPowerup = shot.usedPowerups.first(where: { !selectedPowerups.contains($0) }) {
                    return failureResult(
                        replay: replay,
                        shotIndex: index,
                        actualOutcome: outcome(for: state),
                        reason: "Shot uses powerup not in selected loadout: \(unselectedPowerup.rawValue)."
                    )
                }

                if let unknownBrickID = shot.destroyedBrickIDs.first(where: { !brickIDs.contains($0) }) {
                    return failureResult(
                        replay: replay,
                        shotIndex: index,
                        actualOutcome: outcome(for: state),
                        reason: "Shot references unknown brick id: \(unknownBrickID)."
                    )
                }

                state.applyPlaceholderShot(
                    destroyedBrickIDs: shot.destroyedBrickIDs,
                    aimAngleDegrees: shot.aimAngleDegrees,
                    usedPowerups: shot.usedPowerups
                )
            }

            let actualOutcome = outcome(for: state)
            guard actualOutcome.completed == replay.expectedOutcome.completed,
                  actualOutcome.stars == replay.expectedOutcome.stars else {
                return failureResult(
                    replay: replay,
                    shotIndex: replay.shots.indices.last,
                    actualOutcome: actualOutcome,
                    reason: "Expected outcome did not match actual outcome."
                )
            }

            return ReplayResult(
                levelID: replay.levelID,
                shotIndex: replay.shots.indices.last,
                expectedOutcome: replay.expectedOutcome,
                actualOutcome: actualOutcome,
                failureMessage: nil
            )
        } catch {
            return failureResult(
                replay: replay,
                shotIndex: nil,
                actualOutcome: ReplayActualOutcome(completed: false, stars: 0),
                reason: String(describing: error)
            )
        }
    }

    private func outcome(for state: GameState) -> ReplayActualOutcome {
        guard state.snapshot.turnPhase == .won,
              let result = state.result else {
            return ReplayActualOutcome(completed: false, stars: 0)
        }
        return ReplayActualOutcome(completed: true, stars: result.stars.rawValue)
    }

    private func failureResult(
        replay: ReplayFixture,
        shotIndex: Int?,
        actualOutcome: ReplayActualOutcome,
        reason: String
    ) -> ReplayResult {
        let shotContext = shotIndex.map { "shot \($0)" } ?? "before first shot"
        let message = "Replay \(replay.levelID) failed at \(shotContext): \(reason) Expected \(replay.expectedOutcome); actual \(actualOutcome)."

        return ReplayResult(
            levelID: replay.levelID,
            shotIndex: shotIndex,
            expectedOutcome: replay.expectedOutcome,
            actualOutcome: actualOutcome,
            failureMessage: message
        )
    }
}

struct ReplayBundleLoader {
    private let replaysDirectoryURL: URL?
    private let bundle: Bundle
    private let subdirectory: String
    private let decoder: JSONDecoder

    init(bundle: Bundle = .main, subdirectory: String = "Replays", decoder: JSONDecoder = JSONDecoder()) {
        self.replaysDirectoryURL = nil
        self.bundle = bundle
        self.subdirectory = subdirectory
        self.decoder = decoder
    }

    init(replaysDirectoryURL: URL, decoder: JSONDecoder = JSONDecoder()) {
        self.replaysDirectoryURL = replaysDirectoryURL
        self.bundle = .main
        self.subdirectory = ""
        self.decoder = decoder
    }

    func loadReplay(named name: String) throws -> ReplayFixture {
        let directory = try replaysDirectory()
        let fileURL = directory.appendingPathComponent(name).appendingPathExtension("json")
        let data = try Data(contentsOf: fileURL)

        return try decoder.decode(ReplayFixture.self, from: data)
    }

    private func replaysDirectory() throws -> URL {
        if let replaysDirectoryURL {
            return try validatedDirectory(replaysDirectoryURL, label: replaysDirectoryURL.path)
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
}
