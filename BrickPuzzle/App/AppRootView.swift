import SwiftUI

struct AppRootView: View {
    private let prototypeLevel = LevelDefinition.prototype

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("Brick Puzzle")
                        .font(.largeTitle.bold())
                        .accessibilityIdentifier("app-title")

                    Text("Aim, fire, and solve with the right powerup loadout.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                SpriteKitGameView(level: prototypeLevel)
                    .aspectRatio(9.0 / 14.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(.quaternary, lineWidth: 1)
                    }
                    .accessibilityLabel("Prototype game board")

                PowerupLoadoutSummary(level: prototypeLevel)
            }
            .padding()
            .navigationTitle("Brick Puzzle")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct PowerupLoadoutSummary: View {
    let level: LevelDefinition

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Prototype Loadout")
                .font(.headline)

            Text("Choose up to \(level.maxPowerupLoadoutSize) free powerups before solving this level.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                ForEach(level.availablePowerups) { powerup in
                    Text(powerup.displayName)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.thinMaterial, in: Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    AppRootView()
}

