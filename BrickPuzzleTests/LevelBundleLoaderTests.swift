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
