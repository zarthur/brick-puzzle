# Prototype Readiness Report

## Candidate

- Date: 2026-08-24
- Candidate revision: `9b8c54a` (`main`, after PR #74)
- Verdict: **Not ready — manual simulator and physical-device evidence pending**

This report records only observed results. A passing automated baseline does not substitute for the remaining manual frame-rate, accessibility, and level-by-level checks required by issues #53 and #55.

## Automated Baseline

### Local

- Host: Apple silicon Mac, macOS 26.4.1
- Xcode: 26.6 (`17F113`)
- Simulator: iPhone 17, iOS 26.5
- Build-for-testing: **Pass**
- Swift/domain/replay/performance tests: **50 passed**
- UI tests: **5 passed**
- High-ball-count benchmark: **Pass**, 0.425 seconds against the two-second ceiling
- CI-orchestration tests: **5 passed**

The XCUITest run emitted `IDELaunchParametersSnapshot: no debugger version` diagnostics but completed successfully with all five UI tests passing. The test result, rather than that non-fatal simulator diagnostic, determines the outcome.

### GitHub Actions

- Run: [iOS tests #14](https://github.com/zarthur/brick-puzzle/actions/runs/32797610501)
- Runner: `macos-15`
- Xcode: 16.4 (`16F6`)
- Simulator: iPhone 16 Pro, iOS 18.5
- Build-for-testing: **Pass**
- Swift/domain/replay/performance tests: **50 passed**
- UI tests: **5 passed**
- High-ball-count benchmark: **Pass**, 1.000 second against the two-second ceiling
- CI-orchestration tests: **5 passed**
- Unit and UI result artifacts: **Uploaded**

The prior `macos-26` attempt passed compilation and the unit target but hung while launching XCUITest. PR #74 moved the mandatory PR gate to the stable iOS 18-compatible runner instead of disabling UI execution.

## Manual Evidence Matrix

| Requirement | Status | Evidence needed |
| --- | --- | --- |
| Level 1 normal-load FPS, three runs | Blocked | Unlock the Mac and record overlay, CPU, and memory values. |
| Level 6 Extra Balls/splitter FPS, three runs | Blocked | Unlock the Mac and record overlay, CPU, and memory values. |
| Level 10 combined-mechanic FPS, three runs | Pass | 2026-08-26: 58 FPS minimum in each run; 33–36 ms longest frame; zero hitches. See `performance-sanity-check.md`. |
| Ten-level first-playtest checklist | Blocked | Unlock the Mac; complete every checklist section without inferring subjective results. |
| #70 brick descent and danger-line behavior on iPhone | Pass | 2026-08-26: selected domain and SpriteKit playback tests passed on connected iPhone 16 Pro (iOS 26.6), including nonterminal descent and danger-line failure. |
| #71 Extra Balls and Guide visibility on iPhone | Pass | 2026-08-26: Extra Balls physical UI test passed on connected iPhone 16 Pro; retained screenshot shows the `+3` launch banner, armed status, and differentiated helper balls. |
| Bug-triage verdict | Pending | Complete the manual checks, file every reproducible finding, and classify severity. |

## Closure Conditions

1. Complete the three performance scenarios three times each and update `performance-sanity-check.md` with measured values.
2. Complete every applicable row in `first-playtest-checklist.md` with Pass, Fail, or Not Tested and a rationale.
3. Validate #70 and #71 on the connected physical iPhone.
4. File and fix, or explicitly resolve, every discovered P0/P1/P2 item.
5. Change the verdict above to **Ready** or **Ready with follow-ups** only when no uncaptured P0/P1 issue remains.
6. Close #53, #55, #70, #71, and finally the #50 epic.
