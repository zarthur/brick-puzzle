import SwiftUI

struct AppRootView: View {
    private let prototypeLevel = LevelBundleLoader.prototypeLevel()

    @State private var selectedPowerups: Set<PowerupDefinition> = []
    @State private var isPlaying = false
    @State private var result: AttemptResult?
    @State private var attemptID = UUID()

    var body: some View {
        NavigationStack {
            Group {
                if let result {
                    AttemptResultsView(
                        level: prototypeLevel,
                        result: result,
                        retry: retry,
                        returnToLoadout: returnToLoadout
                    )
                } else if isPlaying {
                    gameView
                } else {
                    PowerupLoadoutPicker(
                        level: prototypeLevel,
                        selection: $selectedPowerups,
                        start: startAttempt
                    )
                }
            }
            .padding()
            .navigationTitle("Brick Puzzle")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var gameView: some View {
        VStack(spacing: 12) {
            Text(prototypeLevel.title)
                .font(.title2.bold())

            SpriteKitGameView(
                level: prototypeLevel,
                loadout: PowerupLoadout(
                    selectedPowerups: selectedPowerups.sorted { $0.rawValue < $1.rawValue }
                )
            ) { completedResult in
                result = completedResult
            }
            .id(attemptID)
            .frame(maxHeight: 680)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.quaternary, lineWidth: 1)
            }
            .accessibilityLabel("Prototype game board")
        }
    }

    private func startAttempt() {
        attemptID = UUID()
        result = nil
        isPlaying = true
    }

    private func retry() {
        attemptID = UUID()
        result = nil
        isPlaying = true
    }

    private func returnToLoadout() {
        result = nil
        isPlaying = false
    }
}

private struct PowerupLoadoutPicker: View {
    let level: LevelDefinition
    @Binding var selection: Set<PowerupDefinition>
    let start: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("Brick Puzzle")
                        .font(.largeTitle.bold())
                        .accessibilityIdentifier("app-title")

                    Text("Choose free helpers, or solve clean for three stars.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Powerup Loadout")
                            .font(.headline)
                        Spacer()
                        Text("\(selection.count)/\(level.maxPowerupLoadoutSize)")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    ForEach(level.availablePowerups) { powerup in
                        let isSelected = selection.contains(powerup)
                        Button {
                            if isSelected {
                                selection.remove(powerup)
                            } else if selection.count < level.maxPowerupLoadoutSize {
                                selection.insert(powerup)
                            }
                        } label: {
                            HStack {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                Text(powerup.displayName)
                                Spacer()
                                Text(isSelected ? "Selected" : "Free")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(!isSelected && selection.count >= level.maxPowerupLoadoutSize)
                        .accessibilityIdentifier("loadout-\(powerup.rawValue)")
                    }
                }
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))

                Text(selection.isEmpty ? "No powerups selected — clean solve eligible" : "Only activated powerups affect your stars")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button(action: start) {
                    Text(selection.isEmpty ? "Start Clean" : "Start Attempt")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("start-attempt")
            }
            .padding(.vertical, 4)
        }
    }
}

private struct AttemptResultsView: View {
    let level: LevelDefinition
    let result: AttemptResult
    let retry: () -> Void
    let returnToLoadout: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text(result.stars == StarRating.none ? "Attempt Failed" : "Level Complete")
                .font(.largeTitle.bold())

            Text(starText)
                .font(.system(size: 46))
                .accessibilityLabel("\(result.stars.rawValue) stars")

            Text("\(result.shotCount) shots")
                .font(.title3.monospacedDigit())

            Text(resultMessage)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Retry", action: retry)
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("retry-attempt")

            Button("Change Loadout", action: returnToLoadout)
                .buttonStyle(.bordered)
                .accessibilityIdentifier("return-to-loadout")
        }
        .navigationTitle(level.title)
        .accessibilityIdentifier("results-screen")
    }

    private var starText: String {
        String(repeating: "★", count: result.stars.rawValue)
            + String(repeating: "☆", count: 3 - result.stars.rawValue)
    }

    private var resultMessage: String {
        if result.stars == StarRating.none {
            return "Try a different angle or adjust your free powerup loadout."
        }
        if result.details.contains(.powerupUsed) {
            return "Powerup used. Replay without helpers to earn three stars."
        }
        if result.details.contains(.threeStarShotLimitMissed) {
            return "Complete in fewer shots to earn three stars."
        }
        return "Clean solve — excellent work."
    }
}

#Preview {
    AppRootView()
}
