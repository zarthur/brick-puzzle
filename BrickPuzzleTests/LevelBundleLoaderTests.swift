import Foundation
import Testing
@testable import BrickPuzzle

@Suite("Level bundle loading")
struct LevelBundleLoaderTests {
    @Test("Bundled prototype fixture decodes")
    func bundledPrototypeFixtureDecodes() throws {
        let level = try LevelBundleLoader().loadLevel(id: "prototype-001")

        #expect(level == .prototype)
    }

    @Test("Bundled catalog is deterministically ordered")
    func bundledCatalogOrder() throws {
        #expect(try LevelBundleLoader().loadAllLevels().map(\.id) == [
            "prototype-001", "prototype-002", "prototype-003", "prototype-004",
            "prototype-005", "prototype-006", "prototype-007", "prototype-008",
            "prototype-009", "prototype-010"
        ])
    }

    @Test("Elegant challenge levels combine mechanics and offer assisted routes")
    func elegantChallengeContract() throws {
        let levels = try LevelBundleLoader().loadAllLevels().filter {
            ("prototype-008"..."prototype-010").contains($0.id)
        }

        #expect(levels.count == 3)
        #expect(levels.allSatisfy { $0.metadata.difficulty == .hard })
        #expect(levels.allSatisfy { $0.metadata.requiredMechanics.count >= 4 })
        #expect(levels.allSatisfy { $0.maxPowerupLoadoutSize == 2 })
        #expect(levels.allSatisfy { $0.availablePowerups.count >= 4 })
        #expect(levels.allSatisfy { $0.starRules.threeStarRequiresNoPowerups })
    }

    @Test("Combination levels expose multiple mechanics and useful loadout choices")
    func combinationLevelContract() throws {
        let levels = try LevelBundleLoader().loadAllLevels().filter {
            ("prototype-004"..."prototype-007").contains($0.id)
        }

        #expect(levels.count == 4)
        #expect(levels.allSatisfy { $0.metadata.requiredMechanics.count >= 3 })
        #expect(levels.filter { $0.maxPowerupLoadoutSize > 1 && $0.availablePowerups.count > 2 }.count >= 2)
        #expect(levels.allSatisfy { $0.starRules.threeStarRequiresNoPowerups })
    }

    @Test("Invalid fixture reports decode failure")
    func invalidFixtureReportsDecodeFailure() throws {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? fileManager.removeItem(at: directory)
        }

        let invalidFixtureURL = directory.appendingPathComponent("invalid.json")
        try "{".write(to: invalidFixtureURL, atomically: true, encoding: .utf8)

        let loader = LevelBundleLoader(levelsDirectoryURL: directory)
        var reportedDecodeFailure = false

        do {
            _ = try loader.loadAllLevels()
        } catch LevelLoadingError.decodeFailed(let fileName, _) {
            reportedDecodeFailure = fileName == "invalid.json"
        } catch {
            reportedDecodeFailure = false
        }

        #expect(reportedDecodeFailure)
    }

    @Test("Missing fixture directory reports loading error")
    func missingFixtureDirectoryReportsLoadingError() throws {
        let missingDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let loader = LevelBundleLoader(levelsDirectoryURL: missingDirectory)
        var reportedMissingDirectory = false

        do {
            _ = try loader.loadAllLevels()
        } catch LevelLoadingError.missingLevelsDirectory(let path) {
            reportedMissingDirectory = path == missingDirectory.path
        } catch {
            reportedMissingDirectory = false
        }

        #expect(reportedMissingDirectory)
    }
}
