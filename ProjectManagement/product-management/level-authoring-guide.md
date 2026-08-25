# Level Authoring Guide

Brick Puzzle levels use a data-first authoring workflow: each playable level is a reviewed JSON fixture paired with a deterministic clean replay. This keeps content changes diffable, testable, and usable by both the app and CI.

## Authoring Approach

Continue with JSON fixtures and replay validation while the catalog is small. A visual editor is intentionally deferred until authoring data shows that it would solve a recurring problem. Re-evaluate an editor when any of these thresholds is reached:

- median end-to-end authoring time exceeds 10 minutes per level across a batch;
- more than 10% of submitted fixtures need structural correction in review;
- coordinate-placement defects recur across multiple content PRs.

Record authoring time and review corrections in each content PR so the decision is evidence-based.

## File Naming and Pairing

Use a matching, zero-padded identifier for the level and its clean replay:

- `BrickPuzzle/Resources/Levels/prototype-NNN.json`
- `BrickPuzzle/Resources/Replays/prototype-NNN-clean.json`

Identifiers must start at `prototype-001`, remain contiguous, and agree with the filenames. Every level requires exactly one clean replay.

## Level Contract

Each level must define:

- a non-empty board with unique brick identifiers and coordinates inside the declared rows and columns;
- valid hit points, objectives, links, available powerups, and loadout limits;
- internally consistent two- and three-star shot limits;
- an `intendedSolution` that explains the authored idea;
- a positive `minimumKnownShotCount` no greater than the three-star limit;
- at least one `requiredMechanics` entry;
- a `difficulty` of `tutorial`, `easy`, `medium`, or `hard`;
- a `validationStatus` of `draft` or `replayValidated`.

Use `draft` while iterating. Change to `replayValidated` only after the clean replay passes the deterministic simulator tests.

## Clean Replay Contract

A clean replay must:

- reference the matching level identifier;
- contain at least one shot with an aim angle between 10 and 170 degrees;
- reference only bricks and powerups declared by the level;
- expect a completed, three-star outcome;
- stay within the level's three-star shot limit;
- select and use no powerups when three stars require a powerup-free solution.

The replay should demonstrate the current minimum known solution. If a simpler solution is discovered, update both the replay and `minimumKnownShotCount`.

## Difficulty Calibration

- `tutorial`: introduces one concept with an obvious target or guided route.
- `easy`: reinforces known mechanics with generous geometry and shot limits.
- `medium`: combines mechanics or requires intentional banking, ordering, or timing.
- `hard`: demands precise execution, multi-step reasoning, or mastery of combined mechanics.

Compare new levels with neighboring catalog entries. Difficulty should rise in waves rather than monotonically so players receive periodic recovery levels.

## Validation Commands

Run the catalog validator and regenerate its committed report:

```sh
python3 .github/scripts/level_catalog.py validate
python3 .github/scripts/level_catalog.py report --format markdown --output ProjectManagement/quality/level-catalog-report.md
python3 .github/scripts/level_catalog.py report --format markdown --check ProjectManagement/quality/level-catalog-report.md
```

Run the validator's unit tests:

```sh
python3 -m unittest discover -s .github/scripts/tests -p 'test_*.py'
```

Run the app's focused catalog and replay tests using an installed simulator:

```sh
xcodebuild test -project BrickPuzzle.xcodeproj -scheme BrickPuzzle \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  -only-testing:BrickPuzzleTests/LevelBundleLoaderTests \
  -only-testing:BrickPuzzleTests/ReplayRunnerTests
```

CI repeats the data validation, verifies that the generated report is current, and runs all Swift and UI tests.

## Content PR Checklist

- Add level and clean replay files with matching identifiers.
- Keep the identifier sequence contiguous.
- Include intent, mechanics, difficulty, and minimum known shot count metadata.
- Prove completion and the three-star result with a deterministic replay.
- Regenerate `ProjectManagement/quality/level-catalog-report.md`.
- Run Python validation/tests and the focused Swift replay tests.
- Record per-level authoring time and any structural corrections requested in review.
