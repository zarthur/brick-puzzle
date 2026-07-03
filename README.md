# Brick Puzzle iOS

Product planning repository for a native iOS brick-breaker puzzle game built with Swift.

The game direction is an offline-first, aim-and-shoot brick puzzle where physics resolves each shot, levels have elegant intended solutions, powerups are free, and the only monetization is optional player support.

## Project Structure

- [BrickPuzzle.xcodeproj](BrickPuzzle.xcodeproj): Xcode project.
- [BrickPuzzle](BrickPuzzle): iOS app source.
- [BrickPuzzleTests](BrickPuzzleTests): unit tests.
- [BrickPuzzleUITests](BrickPuzzleUITests): UI tests.
- [ProjectManagement](ProjectManagement): product and planning documents.

## Project Management Documents

- [Product Plan](ProjectManagement/product-management/product-plan.md)
- [Research Sources](ProjectManagement/product-management/research-sources.md)

## Product Pillars

- Puzzle-first brick-breaking: levels should feel deliberately solvable, not random.
- Fair powerups: powerups are free, but choosing the right subset for a level matters.
- Elegant solutions: brute force can clear levels, but clean solutions earn better rewards.
- Offline native iOS: built for Swift, SpriteKit, SwiftUI, StoreKit, and Game Center where useful.
- Ethical monetization: no forced ads, paid retries, paid boosts, stamina timers, or paid currency.

## Local Development

Open `BrickPuzzle.xcodeproj` in Xcode, or build from the command line:

```sh
xcodebuild -project BrickPuzzle.xcodeproj -scheme BrickPuzzle -destination 'generic/platform=iOS Simulator' build
```
