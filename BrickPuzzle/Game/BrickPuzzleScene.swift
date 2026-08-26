import SpriteKit
import UIKit

struct FrameRateSnapshot: Equatable {
    static let empty = FrameRateSnapshot(
        currentFramesPerSecond: 0,
        minimumFramesPerSecond: 0,
        longestFrameDuration: 0,
        hitchCount: 0,
        sampledDuration: 0
    )

    let currentFramesPerSecond: Double
    let minimumFramesPerSecond: Double
    let longestFrameDuration: TimeInterval
    let hitchCount: Int
    let sampledDuration: TimeInterval

    var meetsPrototypeThreshold: Bool {
        minimumFramesPerSecond >= 55 && longestFrameDuration <= 0.1
    }
}

struct BallPlaybackSample: Equatable {
    let elapsedTime: TimeInterval
    let position: BoardPoint
}

struct BallPlaybackPath {
    let samples: [BallPlaybackSample]

    func position(at elapsedTime: TimeInterval) -> BoardPoint? {
        guard let first = samples.first, elapsedTime >= first.elapsedTime else {
            return nil
        }
        guard let last = samples.last, elapsedTime < last.elapsedTime else {
            return samples.last?.position
        }

        var lowerBound = 0
        var upperBound = samples.count - 1
        while lowerBound + 1 < upperBound {
            let midpoint = (lowerBound + upperBound) / 2
            if samples[midpoint].elapsedTime <= elapsedTime {
                lowerBound = midpoint
            } else {
                upperBound = midpoint
            }
        }

        let lower = samples[lowerBound]
        let upper = samples[upperBound]
        let interval = upper.elapsedTime - lower.elapsedTime
        guard interval > 0 else { return upper.position }
        let progress = (elapsedTime - lower.elapsedTime) / interval
        return BoardPoint(
            x: lower.position.x + (upper.position.x - lower.position.x) * progress,
            y: lower.position.y + (upper.position.y - lower.position.y) * progress
        )
    }
}

struct BallPlaybackTrack {
    let id: String
    let path: BallPlaybackPath
}

struct ShotPlaybackPlan: @unchecked Sendable {
    let state: GameState
    let resolution: ShotResolution
    let ballTracks: [BallPlaybackTrack]
}

struct ShotPlaybackResolver: @unchecked Sendable {
    let state: GameState

    func resolve() throws -> ShotPlaybackPlan {
        var resolvedState = state
        let resolution = try resolvedState.fire()
        let ballIDs = Set(resolution.frames.flatMap { $0.balls.map(\.id) }).sorted()
        let tracks = ballIDs.map { ballID in
            BallPlaybackTrack(
                id: ballID,
                path: BallPlaybackPath(samples: resolution.frames.compactMap { frame in
                    guard let ball = frame.balls.first(where: { $0.id == ballID }) else {
                        return nil
                    }
                    return BallPlaybackSample(
                        elapsedTime: frame.elapsedTime,
                        position: ball.position
                    )
                })
            )
        }
        return ShotPlaybackPlan(
            state: resolvedState,
            resolution: resolution,
            ballTracks: tracks
        )
    }
}

struct FrameRateMonitor {
    private let reportingInterval: TimeInterval
    private let hitchThreshold: TimeInterval
    private var firstTimestamp: TimeInterval?
    private var lastTimestamp: TimeInterval?
    private var reportingWindowStart: TimeInterval?
    private var reportingWindowFrameCount = 0
    private var minimumFramesPerSecond = Double.infinity
    private var longestFrameDuration: TimeInterval = 0
    private var hitchCount = 0

    init(reportingInterval: TimeInterval = 0.5, hitchThreshold: TimeInterval = 0.1) {
        self.reportingInterval = reportingInterval
        self.hitchThreshold = hitchThreshold
    }

    mutating func reset() {
        firstTimestamp = nil
        lastTimestamp = nil
        reportingWindowStart = nil
        reportingWindowFrameCount = 0
        minimumFramesPerSecond = .infinity
        longestFrameDuration = 0
        hitchCount = 0
    }

    mutating func recordFrame(at timestamp: TimeInterval) -> FrameRateSnapshot? {
        guard timestamp.isFinite else { return nil }

        guard let lastTimestamp else {
            firstTimestamp = timestamp
            reportingWindowStart = timestamp
            self.lastTimestamp = timestamp
            return nil
        }

        let frameDuration = timestamp - lastTimestamp
        guard frameDuration > 0 else { return nil }
        self.lastTimestamp = timestamp

        reportingWindowFrameCount += 1
        longestFrameDuration = max(longestFrameDuration, frameDuration)
        if frameDuration > hitchThreshold {
            hitchCount += 1
        }

        guard let reportingWindowStart,
              let firstTimestamp,
              timestamp - reportingWindowStart >= reportingInterval else {
            return nil
        }

        let reportingWindowDuration = timestamp - reportingWindowStart
        let currentFramesPerSecond = Double(reportingWindowFrameCount) / reportingWindowDuration
        minimumFramesPerSecond = min(minimumFramesPerSecond, currentFramesPerSecond)
        let snapshot = FrameRateSnapshot(
            currentFramesPerSecond: currentFramesPerSecond,
            minimumFramesPerSecond: minimumFramesPerSecond,
            longestFrameDuration: longestFrameDuration,
            hitchCount: hitchCount,
            sampledDuration: timestamp - firstTimestamp
        )

        self.reportingWindowStart = timestamp
        reportingWindowFrameCount = 0
        return snapshot
    }
}

final class BrickPuzzleScene: SKScene, @unchecked Sendable {
    private var gameState: GameState?
    private var activeTouch: UITouch?
    private var isAimCancelled = false
    private var isAnimatingShot = false
    private var pendingTargetPowerup: PowerupDefinition?
    private var reduceMotion = false
    private var onSnapshotChange: ((GameSnapshot, AttemptResult?) -> Void)?
    private var frameRateMonitor = FrameRateMonitor()
    private var onPerformanceSnapshot: ((FrameRateSnapshot) -> Void)?

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = .clear
        isUserInteractionEnabled = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        scaleMode = .resizeFill
        backgroundColor = .clear
        isUserInteractionEnabled = true
    }

    func configure(
        level: LevelDefinition,
        loadout: PowerupLoadout = .empty,
        reduceMotion: Bool = false,
        onSnapshotChange: ((GameSnapshot, AttemptResult?) -> Void)? = nil,
        onPerformanceSnapshot: ((FrameRateSnapshot) -> Void)? = nil
    ) {
        self.onSnapshotChange = onSnapshotChange
        self.onPerformanceSnapshot = onPerformanceSnapshot
        self.reduceMotion = reduceMotion
        gameState = try? GameState(level: level, loadout: loadout)
        pendingTargetPowerup = nil
        frameRateMonitor.reset()
        onPerformanceSnapshot?(.empty)
        renderSnapshot()
        notifySnapshotChange()
    }

    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        if let snapshot = frameRateMonitor.recordFrame(at: currentTime) {
            onPerformanceSnapshot?(snapshot)
        }
    }

    func activatePowerup(_ powerup: PowerupDefinition) {
        guard !isAnimatingShot, var state = gameState else { return }
        if powerup == .bomb || powerup == .rowClear {
            pendingTargetPowerup = powerup
            renderSnapshot()
            return
        }
        do {
            _ = try state.activatePowerup(powerup)
            gameState = state
            renderSnapshot()
            notifySnapshotChange()
        } catch {
            pendingTargetPowerup = nil
        }
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard !isAnimatingShot else {
            return
        }
        renderSnapshot()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isAnimatingShot,
              activeTouch == nil,
              let touch = touches.first,
              var state = gameState,
              state.snapshot.turnPhase == .idle else {
            return
        }

        let viewport = viewport(for: state.snapshot.boardSize)
        let location = touch.location(in: self)
        if let pendingTargetPowerup, viewport.boardRect.contains(location) {
            let boardPoint = viewport.boardPoint(for: location)
            let authoredRow = state.snapshot.boardSize.rows - 1 - Int(floor(boardPoint.y))
            let coordinate = BoardCoordinate(
                row: authoredRow,
                column: Int(floor(boardPoint.x))
            )
            do {
                _ = try state.activatePowerup(pendingTargetPowerup, target: coordinate)
                gameState = state
                self.pendingTargetPowerup = nil
                renderSnapshot()
                notifySnapshotChange()
            } catch {
                self.pendingTargetPowerup = nil
            }
            return
        }
        let launcher = viewport.scenePoint(for: BoardGeometry(size: state.snapshot.boardSize).launcherPosition)
        let activationRadius = max(34, viewport.cellSize * 0.9)
        let beganOnLauncher = hypot(location.x - launcher.x, location.y - launcher.y) <= activationRadius
        let beganOnField = viewport.boardRect.contains(location)
        guard beganOnLauncher || beganOnField else {
            return
        }

        do {
            try state.beginAiming()
            gameState = state
            activeTouch = touch
            isAimCancelled = false
            updateAim(for: location)
        } catch {
            activeTouch = nil
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let activeTouch, touches.contains(activeTouch) else {
            return
        }
        updateAim(for: activeTouch.location(in: self))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let activeTouch, touches.contains(activeTouch) else {
            return
        }

        let location = activeTouch.location(in: self)
        self.activeTouch = nil

        if isAimCancelled {
            cancelAim()
        } else {
            updateAim(for: location)
            isAimCancelled ? cancelAim() : fireShot()
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let activeTouch, touches.contains(activeTouch) else {
            return
        }
        self.activeTouch = nil
        cancelAim()
    }

    private func updateAim(for scenePoint: CGPoint) {
        guard var state = gameState, state.snapshot.turnPhase == .aiming else {
            return
        }

        let viewport = viewport(for: state.snapshot.boardSize)
        let geometry = BoardGeometry(size: state.snapshot.boardSize)
        let launcher = geometry.launcherPosition
        let target = viewport.boardPoint(for: scenePoint)
        let dx = target.x - launcher.x
        let dy = target.y - launcher.y
        let angle = atan2(dy, dx) * 180 / .pi

        if GameState.isValidAim(angle), dy > 0.25 {
            try? state.updateAim(angleDegrees: angle)
            gameState = state
            isAimCancelled = false
            renderSnapshot(guideTarget: scenePoint, guideIsValid: true)
        } else {
            isAimCancelled = true
            renderSnapshot(guideTarget: scenePoint, guideIsValid: false)
        }
    }

    private func cancelAim() {
        guard var state = gameState else {
            return
        }
        try? state.cancelAim()
        gameState = state
        isAimCancelled = false
        renderSnapshot()
    }

    private func fireShot() {
        guard let state = gameState else { return }

        isAnimatingShot = true
        let resolver = ShotPlaybackResolver(state: state)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let plan = try resolver.resolve()
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.gameState = plan.state
                    self.animate(plan)
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.isAnimatingShot = false
                    self.cancelAim()
                }
            }
        }
    }

    private func animate(_ plan: ShotPlaybackPlan) {
        let resolution = plan.resolution
        if reduceMotion {
            isAnimatingShot = false
            renderSnapshot()
            notifySnapshotChange()
            return
        }
        guard let snapshot = gameState?.snapshot,
              !resolution.frames.isEmpty else {
            isAnimatingShot = false
            renderSnapshot()
            return
        }

        isAnimatingShot = true
        childNode(withName: "aim-guide")?.removeFromParent()
        childNode(withName: "aim-guide-impact")?.removeFromParent()
        childNode(withName: "instruction-label")?.removeFromParent()

        let viewport = viewport(for: snapshot.boardSize)
        if let baseBallCount = gameState?.baseBallCount,
           let ballCount = resolution.frames.map({ $0.balls.count }).max(),
           ballCount > baseBallCount {
            renderExtraBallsLaunchFeedback(
                additionalBalls: ballCount - baseBallCount,
                viewport: viewport
            )
        }

        var previousBricks = resolution.frames[0].bricks
        for (index, frame) in resolution.frames.dropFirst().enumerated() where frame.bricks != previousBricks {
            let bricks = frame.bricks
            run(.sequence([
                .wait(forDuration: frame.elapsedTime),
                .run { [weak self] in
                    self?.renderPlaybackBricks(bricks, viewport: viewport)
                }
            ]), withKey: "brick-playback-\(index)")
            previousBricks = bricks
        }

        let duration = resolution.frames.last?.elapsedTime ?? 0
        let ballColors: [UIColor] = [.systemTeal, .systemYellow, .systemPink]
        for (ballIndex, track) in plan.ballTracks.enumerated() {
            guard let firstSample = track.path.samples.first else { continue }

            let ball = SKShapeNode(circleOfRadius: max(4, viewport.cellSize * 0.12))
            ball.name = "active-ball-\(track.id)"
            ball.position = viewport.scenePoint(for: firstSample.position)
            ball.fillColor = ballColors[ballIndex % ballColors.count]
            ball.strokeColor = .white
            ball.lineWidth = 2.5
            ball.zPosition = 20
            ball.alpha = firstSample.elapsedTime > 0 ? 0 : 1
            addChild(ball)

            ball.run(.customAction(withDuration: duration) { node, elapsedTime in
                guard let position = track.path.position(at: elapsedTime) else {
                    node.alpha = 0
                    return
                }
                node.alpha = 1
                node.position = viewport.scenePoint(for: position)
            })
        }

        run(.wait(forDuration: duration)) { [weak self] in
            guard let self else { return }
            self.isAnimatingShot = false
            self.renderSnapshot()
            self.renderEventFeedback(resolution.finalSnapshot.shotHistory.last?.events ?? [])
            self.notifySnapshotChange()
        }
    }

    private func renderEventFeedback(_ events: [GameplayEvent]) {
        guard !reduceMotion else { return }
        guard let snapshot = gameState?.snapshot else { return }
        let viewport = viewport(for: snapshot.boardSize)
        let geometry = BoardGeometry(size: snapshot.boardSize)

        for event in events where event.kind == .bombTriggered {
            guard let brick = snapshot.bricks.first(where: { $0.id == event.subjectID }),
                  let bounds = geometry.brickBounds(at: brick.coordinate) else { continue }
            let center = viewport.scenePoint(for: BoardPoint(
                x: (bounds.minX + bounds.maxX) / 2,
                y: (bounds.minY + bounds.maxY) / 2
            ))
            let blast = SKShapeNode(circleOfRadius: viewport.cellSize * 0.9)
            blast.position = center
            blast.fillColor = UIColor.systemOrange.withAlphaComponent(0.28)
            blast.strokeColor = .systemOrange
            blast.lineWidth = 3
            blast.zPosition = 30
            addChild(blast)
            blast.run(.sequence([
                .group([.scale(to: 1.35, duration: 0.25), .fadeOut(withDuration: 0.25)]),
                .removeFromParent()
            ]))
        }
    }

    private func renderExtraBallsLaunchFeedback(additionalBalls: Int, viewport: BoardViewport) {
        let label = SKLabelNode(text: "EXTRA BALLS +\(additionalBalls)")
        label.name = "extra-balls-feedback"
        label.fontName = "AvenirNext-Bold"
        label.fontSize = 16
        label.fontColor = .systemYellow
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: size.width / 2, y: viewport.boardRect.maxY - 18)
        label.zPosition = 40
        addChild(label)
        label.run(.sequence([
            .group([
                .scale(to: 1.12, duration: 0.15),
                .wait(forDuration: 0.15)
            ]),
            .fadeOut(withDuration: 0.35),
            .removeFromParent()
        ]))
    }

    private func renderSnapshot(guideTarget: CGPoint? = nil, guideIsValid: Bool = true) {
        removeAllChildren()

        guard let snapshot = gameState?.snapshot, size.width > 0, size.height > 0 else {
            return
        }

        let viewport = viewport(for: snapshot.boardSize)
        renderBoardBackground(viewport: viewport)

        for brick in snapshot.activeBricks {
            renderBrick(brick, viewport: viewport)
        }

        if let dangerLineRow = gameState?.effectiveDangerLineRow {
            renderDangerLine(row: dangerLineRow, viewport: viewport)
        }

        renderLauncher(snapshot: snapshot, viewport: viewport)
        renderHeader(snapshot)
        renderInstruction(snapshot)

        if let guideTarget {
            renderAimGuide(to: guideTarget, isValid: guideIsValid, snapshot: snapshot, viewport: viewport)
        }
    }

    private func renderBoardBackground(viewport: BoardViewport) {
        let board = SKShapeNode(rect: viewport.boardRect, cornerRadius: 14)
        board.fillColor = UIColor.systemBackground.withAlphaComponent(0.72)
        board.strokeColor = UIColor.separator.withAlphaComponent(0.45)
        board.lineWidth = 1
        board.zPosition = -1
        addChild(board)
    }

    private func renderBrick(_ brick: BrickState, viewport: BoardViewport) {
        let geometry = BoardGeometry(size: viewport.boardSize)
        guard let bounds = geometry.drawnBrickBounds(at: brick.coordinate) else {
            return
        }

        let center = viewport.scenePoint(for: BoardPoint(
            x: (bounds.minX + bounds.maxX) / 2,
            y: (bounds.minY + bounds.maxY) / 2
        ))
        let brickSize = CGSize(
            width: viewport.cellSize * CGFloat(bounds.maxX - bounds.minX),
            height: viewport.cellSize * CGFloat(bounds.maxY - bounds.minY)
        )
        let container = SKNode()
        container.name = "brick-\(brick.id)"
        container.position = center
        container.zPosition = 1
        addChild(container)

        let node = SKShapeNode(rectOf: brickSize, cornerRadius: min(8, viewport.cellSize * 0.16))
        node.name = "brick-body"
        node.fillColor = brick.kind.color
        node.strokeColor = brick.isProtected ? .systemCyan : UIColor.white.withAlphaComponent(0.5)
        node.lineWidth = brick.kind == .mission || brick.isProtected ? 3 : 1
        container.addChild(node)

        let label = SKLabelNode(text: "\(brick.kind.shortLabel) \(brick.hitPoints)")
        label.name = "brick-label"
        label.fontName = "AvenirNext-Bold"
        label.fontSize = max(11, viewport.cellSize * 0.24)
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.zPosition = 2
        container.addChild(label)

        if brick.isLocked || brick.isProtected {
            let stateLabel = SKLabelNode(text: brick.isLocked ? "🔒" : "◇")
            stateLabel.name = "brick-state"
            stateLabel.fontSize = max(10, viewport.cellSize * 0.22)
            stateLabel.horizontalAlignmentMode = .right
            stateLabel.verticalAlignmentMode = .top
            stateLabel.position = CGPoint(
                x: brickSize.width * 0.45,
                y: brickSize.height * 0.45
            )
            stateLabel.zPosition = 3
            container.addChild(stateLabel)
        }
    }

    private func renderPlaybackBricks(_ bricks: [BrickState], viewport: BoardViewport) {
        let activeBricks = bricks.filter { !$0.isDestroyed }
        let activeIDs = Set(activeBricks.map(\.id))
        enumerateChildNodes(withName: "brick-*") { node, _ in
            guard let name = node.name else { return }
            let id = String(name.dropFirst("brick-".count))
            if !activeIDs.contains(id) {
                node.removeFromParent()
            }
        }
        for brick in activeBricks {
            if !updateRenderedBrick(brick, viewport: viewport) {
                renderBrick(brick, viewport: viewport)
            }
        }
    }

    private func updateRenderedBrick(_ brick: BrickState, viewport: BoardViewport) -> Bool {
        guard let container = childNode(withName: "brick-\(brick.id)"),
              let body = container.childNode(withName: "brick-body") as? SKShapeNode,
              let label = container.childNode(withName: "brick-label") as? SKLabelNode else {
            return false
        }

        let geometry = BoardGeometry(size: viewport.boardSize)
        guard let bounds = geometry.drawnBrickBounds(at: brick.coordinate) else {
            container.removeFromParent()
            return true
        }
        let brickSize = CGSize(
            width: viewport.cellSize * CGFloat(bounds.maxX - bounds.minX),
            height: viewport.cellSize * CGFloat(bounds.maxY - bounds.minY)
        )
        container.position = viewport.scenePoint(for: BoardPoint(
            x: (bounds.minX + bounds.maxX) / 2,
            y: (bounds.minY + bounds.maxY) / 2
        ))
        body.fillColor = brick.kind.color
        body.strokeColor = brick.isProtected ? .systemCyan : UIColor.white.withAlphaComponent(0.5)
        body.lineWidth = brick.kind == .mission || brick.isProtected ? 3 : 1
        label.text = "\(brick.kind.shortLabel) \(brick.hitPoints)"

        if brick.isLocked || brick.isProtected {
            let stateLabel: SKLabelNode
            if let existing = container.childNode(withName: "brick-state") as? SKLabelNode {
                stateLabel = existing
            } else {
                stateLabel = SKLabelNode()
                stateLabel.name = "brick-state"
                stateLabel.zPosition = 3
                container.addChild(stateLabel)
            }
            stateLabel.text = brick.isLocked ? "🔒" : "◇"
            stateLabel.fontSize = max(10, viewport.cellSize * 0.22)
            stateLabel.horizontalAlignmentMode = .right
            stateLabel.verticalAlignmentMode = .top
            stateLabel.position = CGPoint(
                x: brickSize.width * 0.45,
                y: brickSize.height * 0.45
            )
        } else {
            container.childNode(withName: "brick-state")?.removeFromParent()
        }
        return true
    }

    func renderPlaybackBricksForTesting(_ bricks: [BrickState]) {
        guard let snapshot = gameState?.snapshot else { return }
        renderPlaybackBricks(bricks, viewport: viewport(for: snapshot.boardSize))
    }

    func renderedBrickNodeForTesting(id: String) -> SKNode? {
        childNode(withName: "brick-\(id)")
    }

    private func renderDangerLine(row: Int, viewport: BoardViewport) {
        let y = viewport.origin.y + CGFloat(viewport.boardSize.rows - row) * viewport.cellSize
        let path = CGMutablePath()
        path.move(to: CGPoint(x: viewport.boardRect.minX, y: y))
        path.addLine(to: CGPoint(x: viewport.boardRect.maxX, y: y))
        let line = SKShapeNode(path: path)
        line.strokeColor = .systemRed
        line.lineWidth = 2
        line.zPosition = 5
        addChild(line)
    }

    private func renderLauncher(snapshot: GameSnapshot, viewport: BoardViewport) {
        let launcherPosition = viewport.scenePoint(for: BoardGeometry(size: snapshot.boardSize).launcherPosition)
        let launcher = SKShapeNode(circleOfRadius: max(14, viewport.cellSize * 0.34))
        launcher.name = "launcher"
        launcher.position = launcherPosition
        launcher.fillColor = snapshot.turnPhase == .won ? .systemGreen : .label
        launcher.strokeColor = .systemBackground
        launcher.lineWidth = 3
        launcher.zPosition = 10
        addChild(launcher)
    }

    private func renderAimGuide(
        to target: CGPoint,
        isValid: Bool,
        snapshot: GameSnapshot,
        viewport: BoardViewport
    ) {
        let launcher = viewport.scenePoint(for: BoardGeometry(size: snapshot.boardSize).launcherPosition)
        let path = CGMutablePath()
        path.move(to: launcher)
        let hasPrecisionGuide = snapshot.armedPowerups.contains(.precisionGuide)
        if hasPrecisionGuide, isValid,
           let preview = precisionGuidePreview(from: launcher, through: target, boardRect: viewport.boardRect) {
            path.addLine(to: preview.impact)
            path.addLine(to: preview.reflectedEnd)
            let impact = SKShapeNode(circleOfRadius: max(5, viewport.cellSize * 0.12))
            impact.name = "aim-guide-impact"
            impact.position = preview.impact
            impact.fillColor = .systemYellow
            impact.strokeColor = .white
            impact.lineWidth = 2
            impact.zPosition = 10
            addChild(impact)
        } else {
            path.addLine(to: target)
        }

        let guide = SKShapeNode(path: path)
        guide.name = "aim-guide"
        guide.strokeColor = isValid ? (hasPrecisionGuide ? .systemYellow : .systemTeal) : .systemRed
        guide.lineWidth = hasPrecisionGuide ? 5 : 3
        guide.lineCap = .round
        guide.zPosition = 9
        addChild(guide)
    }

    private func precisionGuidePreview(
        from origin: CGPoint,
        through target: CGPoint,
        boardRect: CGRect
    ) -> (impact: CGPoint, reflectedEnd: CGPoint)? {
        let dx = target.x - origin.x
        let dy = target.y - origin.y
        let length = hypot(dx, dy)
        guard length > 0 else { return nil }
        let direction = CGVector(dx: dx / length, dy: dy / length)

        var candidates: [(time: CGFloat, point: CGPoint, verticalWall: Bool)] = []
        if direction.dx != 0 {
            for x in [boardRect.minX, boardRect.maxX] {
                let time = (x - origin.x) / direction.dx
                let y = origin.y + direction.dy * time
                if time > 0, boardRect.minY...boardRect.maxY ~= y {
                    candidates.append((time, CGPoint(x: x, y: y), true))
                }
            }
        }
        if direction.dy != 0 {
            for y in [boardRect.minY, boardRect.maxY] {
                let time = (y - origin.y) / direction.dy
                let x = origin.x + direction.dx * time
                if time > 0, boardRect.minX...boardRect.maxX ~= x {
                    candidates.append((time, CGPoint(x: x, y: y), false))
                }
            }
        }
        guard let exit = candidates.min(by: { $0.time < $1.time }) else { return nil }
        let reflectedDirection = CGVector(
            dx: exit.verticalWall ? -direction.dx : direction.dx,
            dy: exit.verticalWall ? direction.dy : -direction.dy
        )
        let previewLength = min(boardRect.width, boardRect.height) * 0.3
        return (
            exit.point,
            CGPoint(
                x: exit.point.x + reflectedDirection.dx * previewLength,
                y: exit.point.y + reflectedDirection.dy * previewLength
            )
        )
    }

    private func renderHeader(_ snapshot: GameSnapshot) {
        let stepText: String
        if snapshot.objectiveProgress.orderedBrickIDs.isEmpty {
            stepText = ""
        } else {
            let completed = snapshot.objectiveProgress.nextStepIndex
            let total = snapshot.objectiveProgress.orderedBrickIDs.count
            stepText = "  •  Step \(min(completed + 1, total))/\(total)"
        }
        let label = SKLabelNode(text: "\(snapshot.levelTitle)  •  Shot \(snapshot.shotCount)\(stepText)")
        label.fontName = "AvenirNext-DemiBold"
        label.fontSize = 16
        label.fontColor = .label
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: size.width / 2, y: size.height - 20)
        addChild(label)
    }

    private func renderInstruction(_ snapshot: GameSnapshot) {
        let text: String
        let color: UIColor
        switch snapshot.turnPhase {
        case .idle:
            if let pendingTargetPowerup {
                text = pendingTargetPowerup == .rowClear
                    ? "Tap a row to clear"
                    : "Tap a cell for the bomb"
                color = .systemOrange
            } else {
                if snapshot.armedPowerups.contains(.precisionGuide) {
                    text = "Guide armed — drag to preview a bounce"
                    color = .systemYellow
                } else if snapshot.armedPowerups.contains(.extraBalls) {
                    text = "Extra Balls armed — next shot launches \(gameState?.nextShotBallCount ?? 13) balls"
                    color = .systemTeal
                } else {
                    text = "10-ball volley — touch and hold the field to aim"
                    color = .secondaryLabel
                }
            }
        case .aiming:
            if isAimCancelled {
                text = "Release to cancel"
                color = .systemRed
            } else if snapshot.armedPowerups.contains(.precisionGuide) {
                text = "Guide active — release to fire"
                color = .systemYellow
            } else {
                text = "Release to fire"
                color = .systemTeal
            }
        case .resolving:
            text = "Resolving shot…"
            color = .secondaryLabel
        case .won:
            text = "Level complete!"
            color = .systemGreen
        case .failed:
            text = "Attempt failed"
            color = .systemRed
        }

        let label = SKLabelNode(text: text)
        label.name = "instruction-label"
        label.fontName = "AvenirNext-Medium"
        label.fontSize = 14
        label.fontColor = color
        label.horizontalAlignmentMode = .center
        label.position = CGPoint(x: size.width / 2, y: 12)
        addChild(label)
    }

    private func viewport(for boardSize: BoardSize) -> BoardViewport {
        BoardViewport(sceneSize: size, boardSize: boardSize)
    }

    private func notifySnapshotChange() {
        guard let gameState else { return }
        onSnapshotChange?(gameState.snapshot, gameState.result)
    }
}

private struct BoardViewport {
    let boardSize: BoardSize
    let cellSize: CGFloat
    let origin: CGPoint

    init(sceneSize: CGSize, boardSize: BoardSize) {
        self.boardSize = boardSize
        let horizontalInset: CGFloat = 24
        let topInset: CGFloat = 42
        let bottomInset: CGFloat = 78
        let width = max(1, sceneSize.width - horizontalInset * 2)
        let height = max(1, sceneSize.height - topInset - bottomInset)
        cellSize = min(
            width / CGFloat(max(boardSize.columns, 1)),
            height / CGFloat(max(boardSize.rows, 1))
        )
        let boardWidth = cellSize * CGFloat(boardSize.columns)
        let boardHeight = cellSize * CGFloat(boardSize.rows)
        origin = CGPoint(
            x: (sceneSize.width - boardWidth) / 2,
            y: sceneSize.height - topInset - boardHeight
        )
    }

    var boardRect: CGRect {
        CGRect(
            origin: origin,
            size: CGSize(
                width: cellSize * CGFloat(boardSize.columns),
                height: cellSize * CGFloat(boardSize.rows)
            )
        )
    }

    func scenePoint(for point: BoardPoint) -> CGPoint {
        CGPoint(
            x: origin.x + CGFloat(point.x) * cellSize,
            y: origin.y + CGFloat(point.y) * cellSize
        )
    }

    func boardPoint(for point: CGPoint) -> BoardPoint {
        BoardPoint(
            x: Double((point.x - origin.x) / cellSize),
            y: Double((point.y - origin.y) / cellSize)
        )
    }
}

private extension BrickKind {
    var color: UIColor {
        switch self {
        case .standard: .systemBlue
        case .mission: .systemGreen
        case .shield: .systemIndigo
        case .key: .systemOrange
        case .bomb: .systemRed
        case .splitter: .systemPurple
        }
    }

    var shortLabel: String {
        switch self {
        case .standard: "#"
        case .mission: "M"
        case .shield: "S"
        case .key: "K"
        case .bomb: "B"
        case .splitter: "X"
        }
    }
}
