# First Playtest Checklist

## Session Information

- Date:
- Build/commit:
- Tester:
- Device and OS:
- New install or existing progress:
- Sound / Music / Haptics / Reduce Motion settings:
- Session duration:

Use **Pass**, **Fail**, or **Not Tested** for each check. Add an issue link beside every failure after triage.

## Launch, Navigation, and Persistence

| Check | Result | Notes / Issue |
| --- | --- | --- |
| App launches to the main menu without intervention |  |  |
| Play opens the first level loadout |  |  |
| Level Select lists levels 1–10 once and in order |  |  |
| Every level entry opens its matching loadout |  |  |
| Level Select remains available during gameplay |  |  |
| Retry starts a clean attempt with the chosen loadout |  |  |
| Completed stars and best shot count survive relaunch |  |  |
| Settings survive relaunch |  |  |

## Onboarding and Aiming Feel

| Check | Result | Notes / Issue |
| --- | --- | --- |
| The first actionable control is obvious |  |  |
| The difference between Play and Level Select is clear |  |  |
| Touch-and-hold / drag aiming is discoverable |  |  |
| Aim cancellation is understandable and does not consume a shot |  |  |
| The launch direction matches the displayed guide |  |  |
| Wall bounces feel predictable |  |  |
| Shot resolution is readable at full speed |  |  |
| Reduce Motion remains understandable and responsive |  |  |

## Powerups and Scoring

| Check | Result | Notes / Issue |
| --- | --- | --- |
| Free loadout choices and maximum selection are clear |  |  |
| Starting clean is clearly eligible for three stars |  |  |
| Extra Balls behavior matches its name |  |  |
| Shield Breaker communicates removed protection |  |  |
| Bomb targeting and affected area are understandable |  |  |
| Row Clear targeting and affected row are understandable |  |  |
| Precision Guide provides useful additional information |  |  |
| Selecting but not using a powerup preserves clean-solve eligibility |  |  |
| Using a powerup prevents three stars where required |  |  |
| Results explain whether powerup use or shot count blocked three stars |  |  |

## Level-by-Level Review

For each level, attempt the intended clean solution first, then retry with a powerup-assisted or brute-force route where practical.

| Level | Load / Complete | Intended mechanic understood | Clean route feels fair | Assisted route viable | Difficulty (1–5) | Notes / Issue |
| --- | --- | --- | --- | --- | --- | --- |
| 1 — First Shot |  |  |  |  |  |  |
| 2 — Mission Stars |  |  |  |  |  |  |
| 3 — Key First |  |  |  |  |  |  |
| 4 — Shield Route |  |  |  |  |  |  |
| 5 — Bomb Bank |  |  |  |  |  |  |
| 6 — Split Decision |  |  |  |  |  |  |
| 7 — Unlock the Blast |  |  |  |  |  |  |
| 8 — Crossfire |  |  |  |  |  |  |
| 9 — Powder Key |  |  |  |  |  |  |
| 10 — Final Sequence |  |  |  |  |  |  |

## Difficulty and Replay Motivation

| Check | Result | Notes / Issue |
| --- | --- | --- |
| Levels 1–3 teach before testing |  |  |
| Levels 4–7 combine mechanics without an unexplained spike |  |  |
| Levels 8–10 feel harder but solvable |  |  |
| Failure usually suggests a useful next attempt |  |  |
| Star thresholds feel demanding but credible |  |  |
| Results make Retry and Level Select equally clear |  |  |
| Improving a one- or two-star result feels worthwhile |  |  |
| At least one elegant no-powerup solve feels satisfying |  |  |

## Accessibility and Readability

| Check | Result | Notes / Issue |
| --- | --- | --- |
| Main controls have useful VoiceOver labels |  |  |
| Level, loadout, gameplay, and result controls are reachable with VoiceOver |  |  |
| Standard, mission, shield, key, bomb, and splitter bricks are distinguishable without color |  |  |
| Brick symbols remain readable during animation |  |  |
| Text is readable on the smallest supported simulator |  |  |
| Controls have adequate touch targets |  |  |
| Reduce Motion removes distracting shot/event animation |  |  |
| Sound-off play preserves all required gameplay information |  |  |

## Performance and Stability

| Check | Result | Notes / Issue |
| --- | --- | --- |
| No launch, navigation, or gameplay crash occurs |  |  |
| Normal shots remain visually smooth |  |  |
| Extra Balls plus splitter shots remain visually smooth |  |  |
| No control becomes unavailable after repeated retries |  |  |
| Memory does not visibly grow across a 10-level session |  |  |
| The performance procedure in `performance-sanity-check.md` passes |  |  |

## Freeform Observations

### Best moment


### Most confusing moment


### Level that felt easiest / hardest


### Powerup chosen most / least often and why


### What would motivate another session?


### Accessibility or comfort concerns


## Triage Summary

- P0 blockers:
- P1 prototype blockers:
- P2 follow-ups:
- Documentation-only findings:
- Overall first-playable verdict: **Ready / Ready with follow-ups / Not ready**
- Issue links created or updated:
