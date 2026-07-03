# Brick Puzzle iOS Product Plan

Last updated: 2026-07-03

## 1. Product Summary

Build a native iOS puzzle brick-breaker inspired by the aim-and-shoot "bricks and balls" genre, with a stronger emphasis on authored puzzle logic and fair progression.

The game should let players aim, fire, and then watch physics resolve the outcome. Levels should support both brute-force clears and elegant clears. Elegant clears are rewarded through a 3-star system, with 3 stars reserved for solving the level without powerups.

The game is offline-first. Powerups are free. The only microtransaction is an optional support/tip purchase that gives no gameplay advantage.

## 2. Product Positioning

Player-facing promise:

> Win by understanding the board, not by paying.

The market contains many brick-breaker puzzle games with strong core loops, but repeated player complaints around ads, paywalled retries, unclear currencies, and boost-dependent level tuning. This game should differentiate through transparent rules, no forced ads, and puzzle levels that feel intentionally designed.

## 3. Target Audience

- Casual puzzle players who like short sessions.
- Players who enjoy physics-based satisfaction but want more strategic planning.
- Players frustrated by ad-heavy or pay-to-progress mobile games.
- Completionists who replay levels for clean 3-star solutions.

## 4. Core Game Loop

1. Player opens a level.
2. Player studies the board and mission objective.
3. Player selects a subset of available powerups for the level loadout.
4. Player aims and fires.
5. Balls resolve through physics.
6. Bricks, blockers, locks, and special effects update.
7. Player repeats until the level is cleared or failed.
8. Game awards completion stars, badges, and progress.

## 5. Core Mechanics

### Aim-And-Shoot Physics

- Player drags to aim and releases to fire.
- Once fired, the shot resolves automatically.
- Aiming must feel precise and forgiving:
  - Cancel zone before release.
  - Optional aim lock.
  - Optional fine-tune nudge controls.
  - Predictive guide line with limited bounce preview.

### Bricks And Objects

Initial brick types:

- Standard brick: has hit points and breaks at zero.
- Mission brick: required for level completion.
- Shield brick: protects nearby or linked bricks until removed.
- Key brick: unlocks gated bricks, rows, or paths.
- Bomb brick: explodes and damages neighbors.
- Splitter brick: creates extra balls or changes trajectories.
- Anchor brick: holds moving rows or blockers in place.
- Fragile brick: easy to destroy, but may be needed for an elegant route.
- Hazard brick: punishes careless collisions.

### Level Objectives

Support multiple objective types:

- Clear all mission bricks.
- Clear all bricks.
- Trigger required keys in sequence.
- Rescue or release an object by removing surrounding bricks.
- Prevent bricks from crossing the danger line.
- Clear within a limited number of shots.

## 6. Powerup System

Powerups are always free, but the player cannot bring every powerup into every level.

Design goals:

- Choosing a loadout should be part of the puzzle.
- Multiple correct powerup combinations should exist.
- Some levels should be solvable without powerups.
- Powerups should help brute-force progress without invalidating elegant play.

Candidate powerups:

- Extra balls: adds balls to the next shot.
- Piercing shot: balls pass through the first few bricks.
- Laser line: direct damage along an aimed line.
- Bomb: targeted area damage.
- Row clear: clears or damages a horizontal row.
- Shield breaker: removes shields or linked protection.
- Ricochet boost: increases bounce energy or changes reflection behavior.
- Slow time preview: gives a longer path forecast before firing.
- Undo shot: resets the board to before the previous shot.
- Gravity shift: changes a physics constant for one shot.

Powerup loadout requirements:

- Each level defines an available pool of powerups.
- Each level defines a max loadout size.
- Player may change loadout before starting or after failing.
- The game records whether powerups were used, not just selected.
- 3-star completion requires no powerup usage.

Future mechanic to evaluate:

- In-level physics modifiers, such as gravity, restitution, friction, or ball speed changes. These should be treated as powerups or advanced level mechanics, not global settings at first.

## 7. Scoring And Rewards

Recommended star system:

- 1 star: complete the level by any valid means.
- 2 stars: complete under a target shot count, score threshold, or with limited powerup use.
- 3 stars: complete without powerups and meet level-specific elegance criteria.

Elegance criteria examples:

- No powerups used.
- Complete within intended shot count.
- Trigger keys in optimal order.
- Avoid destroying protected optional bricks.
- Clear with one high-value chain reaction.
- Finish with unused balls or no danger-line pressure.

Rewards should be non-monetary and non-blocking:

- Stars unlock new worlds or challenge branches.
- Badges mark clean solves.
- Optional cosmetics can be unlocked through play.
- No paid currency, stamina, or paid retry loop.

## 8. Game Modes

### MVP: Solo Puzzle Journey

- Offline level progression.
- 75 to 150 handcrafted launch levels.
- Tutorial levels introducing one mechanic at a time.
- Replay for better stars.
- Optional Game Center achievements.

### Later: Daily Puzzle

- One curated offline puzzle per day if bundled in app updates, or online-delivered only if live operations become worthwhile.
- Clean-solve leaderboard if Game Center is enabled.

### Later: Multiplayer Versus

Track as a future mode, not a prototype feature.

Concept:

- Two players compete on separate boards.
- Clearing bricks charges attacks.
- Combos or elegant clears send new bricks, blockers, shields, or hazards to the opponent board.
- Similar pressure pattern to Tetris garbage lines, adapted to brick-breaker layouts.

Open questions:

- Real-time or asynchronous turn-based?
- Game Center multiplayer, custom backend, or local pass-and-play?
- Symmetric boards or different boards with normalized difficulty?
- Are sent blocks random, player-selected, or based on cleared brick types?
- How to prevent runaway leader advantage?

## 9. User Stories

- As a casual player, I want each level to be playable in a short session so I can make progress in spare moments.
- As a puzzle player, I want levels to have intended solution paths so clearing them feels earned.
- As a stuck player, I want free powerups so I can keep playing without paying or watching ads.
- As a strategic player, I want to choose a powerup loadout so my preparation matters.
- As a completionist, I want 3-star clean solves so I have a reason to replay levels.
- As a fair-play player, I want no paid boosts, no forced ads, and no stamina timers.
- As a supporter, I want an optional way to tip the developer without changing game balance.
- As a future competitive player, I want multiplayer pressure mechanics where my clears affect my opponent.

## 10. Functional Requirements

MVP:

- Native iOS app written in Swift.
- SpriteKit game scene for 2D physics and rendering.
- SwiftUI shell for menus, level map, settings, and support screen.
- Offline playable levels.
- Level schema using Codable data.
- Deterministic replay or simulator for level validation.
- Powerup loadout selection before level start.
- Star scoring and replay.
- Local save progress.
- App settings for sound, music, haptics, reduce motion, and color accessibility.
- Optional StoreKit 2 support/tip purchases.

Post-MVP:

- Game Center achievements.
- Game Center leaderboards for selected challenge levels.
- Daily or weekly challenge.
- Multiplayer versus prototype.
- Cloud sync only if offline local progress becomes insufficient.

## 11. Nonfunctional Requirements

- 60 FPS target on supported iPhones.
- No network dependency for core gameplay.
- Small initial app size.
- Clear visual distinction between brick types.
- Colorblind-safe shapes and iconography.
- Minimal data collection.
- No ad SDK in MVP.
- No third-party SDK unless it clearly earns its maintenance and privacy cost.

## 12. Level Design Principles

- Teach one new rule at a time.
- Early levels should create quick wins.
- Difficulty should ramp in waves: teach, test, relax, combine.
- Every level should have at least one validated solution.
- Important levels should have an elegant solution and at least one brute-force solution.
- Failed attempts should produce insight, not confusion.
- Powerup usage should be a strategic choice, not a tax.

Level metadata should include:

- Intended solution notes.
- Minimum known shot count.
- Expected star thresholds.
- Available powerup pool.
- Max powerup loadout size.
- Required mechanics.
- Estimated difficulty.
- Validation status.

## 13. Technical Direction

Recommended Apple stack:

- Swift for all game and app code.
- SpriteKit for 2D board rendering, particles, collision, and animation.
- SwiftUI for app shell and non-game UI.
- StoreKit 2 for optional tips.
- GameKit/Game Center for achievements, leaderboards, and future multiplayer evaluation.

Key technical uncertainty:

SpriteKit physics may not be deterministic enough for solver-grade validation across devices. Prototype this early. If results vary too much, use custom lightweight deterministic collision math for gameplay and keep SpriteKit for rendering.

## 14. Analytics Plan

Keep analytics privacy-light and product-focused:

- Level started.
- Level completed.
- Level failed.
- Attempt count.
- Shot count.
- Stars earned.
- Powerups selected.
- Powerups used.
- Hint used.
- Time in level.
- Exit after fail.

Use analytics to tune level fairness, not to create monetization pressure.

## 15. Launch Plan

1. Build core prototype with 10 levels.
2. Validate aiming feel and physics repeatability.
3. Build level schema and internal level editor.
4. Produce 50 levels across first two worlds.
5. Add star scoring and powerup loadouts.
6. Run internal playtest.
7. Expand to 75 to 150 levels.
8. Add StoreKit support screen.
9. Run TestFlight beta.
10. Tune difficulty and onboarding.
11. Prepare App Store screenshots and app preview.
12. Launch iPhone-first with iPad compatibility if layout is solid.

## 16. Risks And Evaluation Items

- Copycat risk: avoid Bricks Legend branding, art, UI layout, level designs, and exact economy patterns.
- Physics determinism: validate before building many levels.
- Content cost: handcrafted puzzle levels will be the main production bottleneck.
- Powerup balance: free powerups can flatten difficulty if loadout constraints are weak.
- Star fairness: 3-star requirements must feel challenging but not arbitrary.
- Revenue model: donation-only monetization is player-friendly but financially uncertain.
- App Review language: support/tips should be positioned carefully and implemented through Apple-approved purchase flows.
- Multiplayer complexity: versus mode may require networking, matchmaking, anti-cheat, and balance work, so it should stay out of MVP.

## 17. Open Questions

- What visual theme should make the game distinct from existing brick-breakers?
- Should powerups be selected before each attempt, or can players swap mid-level at a star penalty?
- Should hints count against 3-star elegance?
- Should undo be a powerup, a general accessibility feature, or a training-only feature?
- What is the right initial launch scope: 75 highly polished levels or 150 lighter levels?
- Is the support/tip screen visible from settings only, or also after milestone completions?

