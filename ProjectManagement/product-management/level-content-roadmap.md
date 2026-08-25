# Level Content Roadmap: 11–75

The content target is 75 deterministic, replay-validated levels. Expansion should ship in reviewable batches while preserving mechanic coverage, recovery beats, and a deliberate difficulty curve.

## Difficulty Distribution

| Range | Tutorial | Easy | Medium | Hard | Total |
| --- | ---: | ---: | ---: | ---: | ---: |
| Existing 1–10 | 3 | 2 | 2 | 3 | 10 |
| 11–25 | 0 | 8 | 6 | 1 | 15 |
| 26–50 | 0 | 2 | 15 | 8 | 25 |
| 51–75 | 0 | 0 | 9 | 16 | 25 |
| **Total** | **3** | **12** | **32** | **28** | **75** |

Difficulty is a catalog label, not a demand for a straight upward line. Each batch should alternate challenge peaks with easier consolidation levels.

## Batch 1: Levels 11–25 — Reinforcement

- Reinforce aiming, durable bricks, ordered objectives, keys, shields, bombs, and splitters.
- Favor readable boards and generous shot limits.
- Introduce combinations one pair at a time.
- Reserve one hard level for a batch-ending mastery check.

## Batch 2: Levels 26–50 — Combinations

- Combine two or three established mechanics per level.
- Increase the value of bank shots, target order, and controlled chain reactions.
- Use easy levels sparingly as recovery beats after difficulty spikes.
- Validate that powerups remain useful optional tools without being required for completion.

## Batch 3: Levels 51–75 — Mastery

- Emphasize compact solutions, precise routing, and layered mechanic interactions.
- Retain readable intent even as execution becomes demanding.
- Use medium levels as pacing relief among hard mastery puzzles.
- End with a representative capstone rather than a one-off gimmick.

## Mechanic Coverage Targets

By level 75, each of keys, shields, bombs, and splitters should appear in at least 15 levels. A level may count toward multiple targets when the interaction is intentional and named in `requiredMechanics`.

Do not add advanced mechanics until the research and prototype work tracked by issue #61 is complete. Existing mechanics should reach adequate breadth before the ruleset expands.

## Review Gates

At the end of each submitted content batch:

1. Catalog validation and all automated tests pass.
2. Every level has a clean, deterministic three-star replay.
3. The committed catalog report matches generated output.
4. Actual difficulty distribution is compared with this roadmap.
5. Mechanic counts are checked against the coverage targets.
6. Authoring time and structural-review corrections are summarized to inform the visual-editor decision.
7. A manual play pass checks clarity and enjoyment; replay validation alone is not treated as player validation.
