import SwiftUI

struct AppRootView: View {
    @StateObject private var appState = AppState()
    @State private var path: [Route] = []

    private let levels: [LevelDefinition]
    private let testResult: AttemptResult?

    init() {
        levels = (try? LevelBundleLoader().loadAllLevels()) ?? [.prototype]
        testResult = Self.testResult(
            from: ProcessInfo.processInfo.arguments,
            environment: ProcessInfo.processInfo.environment
        )
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let testResult {
                    AttemptResultsView(
                        level: levels[0],
                        result: testResult,
                        retry: {},
                        changeLoadout: {},
                        continueToLevels: {}
                    )
                } else {
                    MainMenuView(
                        play: { path.append(.loadout(levels[0].id)) },
                        levelSelect: { path.append(.levelSelect) },
                        settings: { path.append(.settings) }
                    )
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .levelSelect:
                    LevelSelectView(levels: levels, appState: appState) { level in
                        path.append(.loadout(level.id))
                    }
                case .settings:
                    SettingsView(settings: $appState.settings)
                case .loadout(let levelID):
                    if let level = level(withID: levelID) {
                        AttemptFlowView(level: level, appState: appState) {
                            path = [.levelSelect]
                        }
                    }
                }
            }
        }
    }

    private func level(withID id: String) -> LevelDefinition? {
        levels.first { $0.id == id }
    }

    private static func testResult(from arguments: [String], environment: [String: String]) -> AttemptResult? {
        let argumentValue = arguments.firstIndex(of: "-ui-test-result").flatMap { index in
            arguments.indices.contains(index + 1) ? arguments[index + 1] : nil
        }
        switch environment["UI_TEST_RESULT"] ?? argumentValue {
        case "won":
            return AttemptResult(
                terminalReason: .objectiveCompleted,
                stars: .three,
                shotCount: 1,
                usedPowerups: [],
                details: [.completed]
            )
        case "failed":
            return AttemptResult(
                terminalReason: .shotLimitReached,
                stars: .none,
                shotCount: 3,
                usedPowerups: [],
                details: [.failed]
            )
        default:
            return nil
        }
    }
}

private enum Route: Hashable {
    case levelSelect
    case settings
    case loadout(String)
}

private struct MainMenuView: View {
    let play: () -> Void
    let levelSelect: () -> Void
    let settings: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "square.grid.3x3.square")
                .font(.system(size: 72))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text("Brick Puzzle")
                .font(.largeTitle.bold())
                .accessibilityIdentifier("app-title")
            Text("Find the cleanest path through every board.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            menuButton("Play", identifier: "menu-play", action: play)
            menuButton("Level Select", identifier: "menu-level-select", action: levelSelect)
            Button("Settings", action: settings)
                .buttonStyle(.bordered)
                .accessibilityIdentifier("menu-settings")
            Spacer()
        }
        .padding(24)
        .navigationTitle("Brick Puzzle")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("main-menu")
    }

    private func menuButton(_ title: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityIdentifier(identifier)
    }
}

private struct LevelSelectView: View {
    let levels: [LevelDefinition]
    @ObservedObject var appState: AppState
    let select: (LevelDefinition) -> Void

    var body: some View {
        List(levels) { level in
            Button { select(level) } label: {
                HStack(spacing: 12) {
                    Image(systemName: "square.grid.3x3.fill")
                        .foregroundStyle(.tint)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(level.title).font(.headline)
                        Text(progressText(for: level))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("level-\(level.id)")
        }
        .navigationTitle("Level Select")
        .accessibilityIdentifier("level-select")
    }

    private func progressText(for level: LevelDefinition) -> String {
        let progress = appState.progress(for: level.id)
        guard progress.bestStars > 0 else { return "Not completed" }
        let stars = String(repeating: "★", count: progress.bestStars)
        return progress.bestShotCount.map { "\(stars) · Best \($0) shots" } ?? stars
    }
}

private struct SettingsView: View {
    @Binding var settings: AppSettings

    var body: some View {
        Form {
            Section("Feedback") {
                Toggle("Sound", isOn: $settings.soundEnabled)
                Toggle("Music", isOn: $settings.musicEnabled)
                Toggle("Haptics", isOn: $settings.hapticsEnabled)
            }
            Section("Accessibility") {
                Toggle("Reduce Motion", isOn: $settings.reduceMotion)
            }
        }
        .navigationTitle("Settings")
        .accessibilityIdentifier("settings-screen")
    }
}

private struct AttemptFlowView: View {
    let level: LevelDefinition
    @ObservedObject var appState: AppState
    let continueToLevels: () -> Void

    @State private var selectedPowerups: Set<PowerupDefinition> = []
    @State private var stage = Stage.loadout
    @State private var result: AttemptResult?
    @State private var attemptID = UUID()
    @State private var snapshot: GameSnapshot?

    private enum Stage { case loadout, playing, result }

    var body: some View {
        Group {
            switch stage {
            case .loadout:
                PowerupLoadoutPicker(level: level, selection: $selectedPowerups, start: startAttempt)
            case .playing:
                gameView
            case .result:
                if let result {
                    AttemptResultsView(
                        level: level,
                        result: result,
                        retry: retry,
                        changeLoadout: { stage = .loadout },
                        continueToLevels: continueToLevels
                    )
                }
            }
        }
        .navigationTitle(level.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(stage == .playing)
        .toolbar {
            if stage == .playing {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Level Select", systemImage: "square.grid.2x2", action: continueToLevels)
                        .accessibilityIdentifier("game-level-select")
                }
            }
        }
    }

    private var gameView: some View {
        VStack(spacing: 8) {
            GameHUD(level: level, snapshot: snapshot, retry: retry)
            SpriteKitGameView(
                level: level,
                loadout: PowerupLoadout(selectedPowerups: selectedPowerups.sorted { $0.rawValue < $1.rawValue }),
                reduceMotion: appState.settings.reduceMotion,
                onSnapshot: { snapshot = $0 }
            ) { completedResult in
                result = completedResult
                appState.record(completedResult, for: level.id)
                stage = .result
            }
            .id(attemptID)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 12).stroke(.quaternary) }
            .accessibilityLabel("Game board for \(level.title)")
            .accessibilityHint("Brick symbols are number sign for standard, M for mission, S for shield, K for key, B for bomb, and X for splitter.")
        }
        .padding()
        .accessibilityIdentifier("game-screen")
    }

    private func startAttempt() {
        attemptID = UUID(); snapshot = nil; result = nil; stage = .playing
    }

    private func retry() {
        attemptID = UUID(); snapshot = nil; result = nil; stage = .playing
    }
}

private struct GameHUD: View {
    let level: LevelDefinition
    let snapshot: GameSnapshot?
    let retry: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(level.title).font(.headline)
                Text("Mission bricks: \(snapshot?.missionBrickCount ?? level.bricks.filter { $0.kind == .mission }.count)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text("Shots \(snapshot?.shotCount ?? 0)")
                .font(.subheadline.monospacedDigit())
                .accessibilityIdentifier("hud-shot-count")
            Button("Retry", systemImage: "arrow.counterclockwise", action: retry)
                .labelStyle(.iconOnly)
                .accessibilityLabel("Retry level")
                .accessibilityIdentifier("hud-retry")
        }
        .accessibilityIdentifier("game-hud")
    }
}

private struct PowerupLoadoutPicker: View {
    let level: LevelDefinition
    @Binding var selection: Set<PowerupDefinition>
    let start: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Choose free helpers, or solve clean for three stars.")
                    .foregroundStyle(.secondary).multilineTextAlignment(.center)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Powerup Loadout").font(.headline)
                        Spacer()
                        Text("\(selection.count)/\(level.maxPowerupLoadoutSize)").monospacedDigit()
                    }
                    ForEach(level.availablePowerups) { powerup in
                        let selected = selection.contains(powerup)
                        Button {
                            if selected { selection.remove(powerup) }
                            else if selection.count < level.maxPowerupLoadoutSize { selection.insert(powerup) }
                        } label: {
                            HStack {
                                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                Text(powerup.displayName)
                                Spacer()
                                Text(selected ? "Selected" : "Free").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(!selected && selection.count >= level.maxPowerupLoadoutSize)
                        .accessibilityIdentifier("loadout-\(powerup.rawValue)")
                    }
                }
                .padding().background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                Text(selection.isEmpty ? "No powerups selected — clean solve eligible" : "Only activated powerups affect your stars")
                    .font(.footnote).foregroundStyle(.secondary)
                Button(action: start) { Text(selection.isEmpty ? "Start Clean" : "Start Attempt").frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent).accessibilityIdentifier("start-attempt")
            }
            .padding()
        }
        .accessibilityIdentifier("loadout-screen")
    }
}

private struct AttemptResultsView: View {
    let level: LevelDefinition
    let result: AttemptResult
    let retry: () -> Void
    let changeLoadout: () -> Void
    let continueToLevels: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text(result.stars == .none ? "Attempt Failed" : "Level Complete").font(.largeTitle.bold())
            Text(String(repeating: "★", count: result.stars.rawValue) + String(repeating: "☆", count: 3 - result.stars.rawValue))
                .font(.system(size: 46)).accessibilityLabel("\(result.stars.rawValue) stars")
            Text("\(result.shotCount) shots").font(.title3.monospacedDigit())
            Text(message).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Retry", action: retry).buttonStyle(.borderedProminent).accessibilityIdentifier("retry-attempt")
            Button("Change Loadout", action: changeLoadout).buttonStyle(.bordered).accessibilityIdentifier("return-to-loadout")
            Button("Level Select", action: continueToLevels).accessibilityIdentifier("results-level-select")
        }
        .padding().accessibilityIdentifier("results-screen")
    }

    private var message: String {
        if result.stars == .none { return "Try a different angle or adjust your free powerup loadout." }
        if result.details.contains(.powerupUsed) { return "Powerup used. Replay without helpers to earn three stars." }
        if result.details.contains(.threeStarShotLimitMissed) { return "Complete in fewer shots to earn three stars." }
        return "Clean solve — excellent work."
    }
}

#Preview { AppRootView() }
