# Brick Puzzle iOS

Product planning repository for a native iOS brick-breaker puzzle game built with Swift.

The game direction is an offline-first, aim-and-shoot brick puzzle where physics resolves each shot, levels have elegant intended solutions, powerups are free, and the only monetization is optional player support.

## First Playable Prototype

The first playable target is a 10-level offline prototype. A build is considered playable when a player can:

- launch the app and open a level from the app shell;
- choose a valid subset of free powerups before the level;
- aim, fire, and let deterministic gameplay resolve the shot;
- complete or fail a level based on authored objectives;
- earn 1, 2, or 3 stars, with 3 stars requiring no powerup usage where the level enables that rule;
- replay levels and retain local best progress;
- play all 10 bundled prototype levels with validation replays proving each level is solvable.

## Project Structure

- [BrickPuzzle.xcodeproj](BrickPuzzle.xcodeproj): Xcode project.
- [BrickPuzzle](BrickPuzzle): iOS app source.
- [BrickPuzzleTests](BrickPuzzleTests): unit tests.
- [BrickPuzzleUITests](BrickPuzzleUITests): UI tests.
- [ProjectManagement](ProjectManagement): product and planning documents.

Bundled level fixtures live in [BrickPuzzle/Resources/Levels](BrickPuzzle/Resources/Levels). Add prototype level JSON files there so the app, level loader, and replay validation tests use the same source data.

### Level authoring contract

Name bundled levels and their clean validation replays with matching, zero-padded ids, for example `prototype-003.json` and `prototype-003-clean.json`. Every level fixture must include `metadata` with:

- `intendedSolution`: internal design notes, never player-facing;
- `minimumKnownShotCount`: the best validated solution currently known;
- `requiredMechanics`: typed mechanics exercised by the level;
- `difficulty`: `tutorial`, `easy`, `medium`, or `hard`;
- `validationStatus`: `draft` or `replayValidated`.

The catalog and replay tests require deterministic fixture ordering, unique level ids, a replay for each bundled level, and a clean three-star replay for levels whose rules require no powerups.

## Project Management Documents

- [Product Plan](ProjectManagement/product-management/product-plan.md)
- [Research Sources](ProjectManagement/product-management/research-sources.md)
- [Prototype Performance Sanity Check](ProjectManagement/quality/performance-sanity-check.md)
- [First Playtest Checklist](ProjectManagement/quality/first-playtest-checklist.md)

## Product Pillars

- Puzzle-first brick-breaking: levels should feel deliberately solvable, not random.
- Fair powerups: powerups are free, but choosing the right subset for a level matters.
- Elegant solutions: brute force can clear levels, but clean solutions earn better rewards.
- Offline native iOS: built for Swift, SpriteKit, SwiftUI, StoreKit, and Game Center where useful.
- Ethical monetization: no forced ads, paid retries, paid boosts, stamina timers, or paid currency.

## Roadmap And Issue Workflow

Implementation work is tracked in [GitHub Issues](https://github.com/zarthur/brick-puzzle/issues). Parent issues are epics, and AI-sized implementation work is tracked as sub-issues.

Prototype milestones:

- [M0 - Planning & Test Foundation](https://github.com/zarthur/brick-puzzle/milestone/1): test strategy, Swift Testing migration, deterministic model split, level fixture loading, and replay validation.
- [M1 - First Playable Prototype](https://github.com/zarthur/brick-puzzle/milestone/2): aim/fire gameplay, brick mechanics, free powerups, star scoring, progression, 10 levels, and prototype QA.
- [M2 - Prototype Polish & Expansion](https://github.com/zarthur/brick-puzzle/milestone/3): authoring tooling, expanded content, visual/audio/accessibility polish.
- [M3 - Launch Readiness](https://github.com/zarthur/brick-puzzle/milestone/4): donation-only StoreKit support, Game Center/challenge evaluation, and advanced mechanics research.
- [M4 - Future Multiplayer](https://github.com/zarthur/brick-puzzle/milestone/5): versus-mode research and prototype planning.

Core prototype epics:

- [#1 Test and architecture foundation](https://github.com/zarthur/brick-puzzle/issues/1)
- [#7 Core aim-and-shoot game loop](https://github.com/zarthur/brick-puzzle/issues/7)
- [#16 Prototype brick mechanics](https://github.com/zarthur/brick-puzzle/issues/16)
- [#24 Free powerups and star scoring](https://github.com/zarthur/brick-puzzle/issues/24)
- [#36 App shell, progression, and settings](https://github.com/zarthur/brick-puzzle/issues/36)
- [#44 Ten-level playable content slice](https://github.com/zarthur/brick-puzzle/issues/44)
- [#50 Prototype quality pass](https://github.com/zarthur/brick-puzzle/issues/50)

Minimum playable path: complete epics #1, #7, #16, #24, #36, and #44, plus the UI smoke test in [#51](https://github.com/zarthur/brick-puzzle/issues/51).

When implementing an issue:

- choose one `ai-ready` sub-issue;
- keep the code change scoped to that issue's acceptance criteria;
- update or add the tests listed in the issue body;
- avoid ads, paid boosts, paid retries, network requirements, or third-party SDKs unless a later issue explicitly adds them;
- reference the issue number in the commit message.

## Local Development

Open `BrickPuzzle.xcodeproj` in Xcode, or build from the command line:

```sh
xcodebuild -project BrickPuzzle.xcodeproj -scheme BrickPuzzle -destination 'generic/platform=iOS Simulator' build
```

## Testing

Use Apple-native testing for the prototype:

- Swift Testing for new pure Swift/domain tests, including level schemas, scoring, loadout validation, deterministic game simulation, and replay fixtures.
- XCTest/XCUIAutomation for UI launch/navigation tests and SpriteKit integration or performance checks.

The current scaffold still includes XCTest-based unit tests. Issue [#3](https://github.com/zarthur/brick-puzzle/issues/3) migrates pure Swift unit tests to Swift Testing while keeping UI tests in XCTest.

Run all tests:

```sh
xcodebuild test -project BrickPuzzle.xcodeproj -scheme BrickPuzzle -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5'
```

Run focused unit/domain tests:

```sh
xcodebuild test -project BrickPuzzle.xcodeproj -scheme BrickPuzzle -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -only-testing:BrickPuzzleTests
```

Run focused UI tests:

```sh
xcodebuild test -project BrickPuzzle.xcodeproj -scheme BrickPuzzle -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -only-testing:BrickPuzzleUITests
```

Run the deterministic high-ball-count benchmark:

```sh
xcodebuild test -project BrickPuzzle.xcodeproj -scheme BrickPuzzle -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' '-only-testing:BrickPuzzleTests/GamePerformanceTests/highBallCountShotPerformance()'
```

Use the [Prototype Performance Sanity Check](ProjectManagement/quality/performance-sanity-check.md) for the SpriteKit 60 FPS procedure and record a manual session with the [First Playtest Checklist](ProjectManagement/quality/first-playtest-checklist.md) before prototype bug triage.
