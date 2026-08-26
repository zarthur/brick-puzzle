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
        let expectedIDs = (1...50).map { String(format: "prototype-%03d", $0) }

        #expect(try LevelBundleLoader().loadAllLevels().map(\.id) == expectedIDs)
    }

    @Test("Combination batch follows its fixed difficulty and mechanic plan")
    func combinationBatchContract() throws {
        let allLevels = try LevelBundleLoader().loadAllLevels()
        let levels = allLevels.filter {
            ("prototype-026"..."prototype-050").contains($0.id)
        }
        let easyIDs: Set<String> = ["prototype-030", "prototype-037"]
        let hardIDs: Set<String> = [
            "prototype-028", "prototype-032", "prototype-035", "prototype-039",
            "prototype-042", "prototype-045", "prototype-048", "prototype-050"
        ]
        let specialtyMechanics: Set<LevelMechanic> = [
            .keyOrdering, .shields, .bombs, .splitters
        ]

        #expect(levels.count == 25)
        #expect(Set(allLevels.map(\.title)).count == allLevels.count)
        #expect(levels.allSatisfy { level in
            let expectedDifficulty: LevelDifficulty = if easyIDs.contains(level.id) {
                .easy
            } else if hardIDs.contains(level.id) {
                .hard
            } else {
                .medium
            }
            return level.metadata.difficulty == expectedDifficulty
        })
        #expect(levels.allSatisfy { $0.metadata.validationStatus == .replayValidated })
        #expect(levels.allSatisfy {
            $0.metadata.minimumKnownShotCount == $0.starRules.threeStarShotLimit
                && $0.starRules.twoStarShotLimit == $0.starRules.threeStarShotLimit + 1
                && $0.starRules.threeStarRequiresNoPowerups
        })
        #expect(levels.allSatisfy { level in
            let represented = Set(level.metadata.requiredMechanics).intersection(specialtyMechanics)
            return (2...3).contains(represented.count)
        })
        #expect(levels.allSatisfy { level in
            !level.metadata.requiredMechanics.contains(.keyOrdering) || !level.keyLinks.isEmpty
        })
        #expect(levels.allSatisfy { level in
            !level.metadata.requiredMechanics.contains(.shields) || !level.shieldLinks.isEmpty
        })
        #expect(levels.allSatisfy { level in
            !level.metadata.requiredMechanics.contains(.bombs)
                || level.bricks.contains { $0.kind == .bomb }
        })
        #expect(levels.allSatisfy { level in
            !level.metadata.requiredMechanics.contains(.splitters)
                || level.bricks.contains { $0.kind == .splitter }
        })

        for mechanic in specialtyMechanics {
            #expect(levels.filter { $0.metadata.requiredMechanics.contains(mechanic) }.count >= 10)
        }
    }

    @Test("First expansion batch follows its difficulty and mechanic plan")
    func firstExpansionBatchContract() throws {
        let levels = try LevelBundleLoader().loadAllLevels().filter {
            ("prototype-011"..."prototype-025").contains($0.id)
        }
        let difficultyCounts = Dictionary(grouping: levels, by: \.metadata.difficulty)
            .mapValues(\.count)

        #expect(levels.count == 15)
        #expect(Set(levels.map(\.title)).count == levels.count)
        #expect(difficultyCounts[.easy] == 8)
        #expect(difficultyCounts[.medium] == 6)
        #expect(difficultyCounts[.hard] == 1)
        #expect(levels.allSatisfy { $0.metadata.validationStatus == .replayValidated })
        #expect(levels.allSatisfy {
            $0.metadata.minimumKnownShotCount == $0.starRules.threeStarShotLimit
                && $0.starRules.threeStarRequiresNoPowerups
        })
        #expect(levels.allSatisfy { level in
            !level.metadata.requiredMechanics.contains(.keyOrdering) || !level.keyLinks.isEmpty
        })
        #expect(levels.allSatisfy { level in
            !level.metadata.requiredMechanics.contains(.shields) || !level.shieldLinks.isEmpty
        })
        #expect(levels.allSatisfy { level in
            !level.metadata.requiredMechanics.contains(.bombs)
                || level.bricks.contains { $0.kind == .bomb }
        })
        #expect(levels.allSatisfy { level in
            !level.metadata.requiredMechanics.contains(.splitters)
                || level.bricks.contains { $0.kind == .splitter }
        })

        for mechanic in [
            LevelMechanic.keyOrdering, .shields, .bombs, .splitters
        ] {
            #expect(levels.filter { $0.metadata.requiredMechanics.contains(mechanic) }.count >= 6)
        }
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
