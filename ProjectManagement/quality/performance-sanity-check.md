# Prototype Performance Sanity Check

## Purpose

This check provides an early warning when deterministic shot resolution or SpriteKit rendering becomes too expensive for the 10-level prototype. It is a regression guard, not a replacement for profiling release builds on physical supported iPhones.

## Prototype Thresholds

- Rendering target: 60 frames per second on supported iPhones.
- Simulator sanity band: the Game Performance instrument should remain near the simulator display refresh rate, with no sustained interval below 55 FPS during a representative shot.
- Hitch target: no visible repeated animation hitch and no single hitch attributable to Brick Puzzle longer than 100 ms.
- Domain benchmark: the high-ball-count shot must finish without `simulationLimitReached`, reach at least six simultaneous balls, and resolve 25 fresh stress shots in under two seconds.

The simulator band is intentionally tolerant. Host load, screen recording, debugger attachment, and simulator services can affect frame delivery. A simulator failure must be reproduced on a physical device before it becomes a launch blocker.

## Automated Domain Benchmark

`GamePerformanceTests.highBallCountShotPerformance()` constructs a deterministic 9×10 stress board with three splitters and an armed Extra Balls powerup. It verifies at least six simultaneous balls, then resolves 25 fresh stress shots against a deliberately generous two-second regression ceiling.

Run it with:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild test \
  -project BrickPuzzle.xcodeproj \
  -scheme BrickPuzzle \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  '-only-testing:BrickPuzzleTests/GamePerformanceTests/highBallCountShotPerformance()'
```

The ceiling is a regression tripwire rather than a microbenchmark baseline. When it fails, reproduce on an otherwise idle host, profile the resolver, and record the measured duration before changing the limit.

## SpriteKit Frame-Rate Procedure

1. Boot an iPhone 17 simulator running iOS 26.5 and close unrelated simulator apps.
2. Build and launch the Debug scheme without enabling Reduce Motion.
3. In Xcode, open the Debug navigator and display FPS, CPU, and memory gauges. For a trace suitable for later comparison, select Product → Profile and use the **Game Performance** template.
4. Play level 1 without powerups as the normal-load sample.
5. Play level 6 with Extra Balls selected and activated; aim through the center splitter as the high-ball-count sample.
6. Play level 10 with Extra Balls selected and activated as the combined-mechanic sample.
7. Observe each shot from launch until every ball returns. Record the minimum sustained FPS, visible hitches, CPU peak, memory peak, simulator/runtime, Mac model, and whether a debugger or recording was attached.
8. Repeat each sample three times. Pass when all runs remain in the simulator sanity band without repeated hitches.

## Initial Validation Record

- Date: 2026-07-18
- App revision: `codex/prototype-quality-pass` (commit recorded in the pull request)
- Host: Apple silicon Mac, macOS 26.4.1
- Xcode: 26.5 (`17F113`)
- Simulator: iPhone 17, iOS 26.5 (`23F77`)
- Automated stress result: passed locally in 0.114 seconds for the complete test; 25 deterministic stress shots completed within the two-second budget and reached at least six simultaneous balls
- Normal-load visual result: pending manual Game Performance observation
- High-ball-count visual result: pending manual Game Performance observation
- Combined-mechanic visual result: pending manual Game Performance observation

## Known Limitations

- Simulator FPS reflects both the app and host workload and is not evidence for every supported physical iPhone.
- Debug builds include instrumentation and are slower than optimized release builds.
- The automated time ceiling covers deterministic domain resolution, not GPU presentation, CPU utilization, or memory growth.
- CA Event, IOSurface, SpriteKit focus-caching, and missing LLDB metadata messages can be simulator diagnostics rather than app failures; use the test result, crash report, and visible behavior to classify them.

Before release, repeat the Game Performance trace on the oldest supported physical iPhone using a Release configuration and archive the trace with release QA artifacts.
