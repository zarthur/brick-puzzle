import SpriteKit
import UIKit

final class BrickPuzzleScene: SKScene {
    private var gameState: GameState?
    private var activeTouch: UITouch?
    private var isAimCancelled = false
    private var isAnimatingShot = false

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

    func configure(level: LevelDefinition) {
        gameState = GameState(level: level)
        renderSnapshot()
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
        guard var state = gameState else {
            return
        }

        do {
            let resolution = try state.fire()
            gameState = state
            animate(resolution)
        } catch {
            gameState = state
            cancelAim()
        }
    }

    private func animate(_ resolution: ShotResolution) {
        guard let snapshot = gameState?.snapshot,
              !resolution.frames.isEmpty else {
            renderSnapshot()
            return
        }

        isAnimatingShot = true
        childNode(withName: "aim-guide")?.removeFromParent()
        childNode(withName: "instruction-label")?.removeFromParent()

        let viewport = viewport(for: snapshot.boardSize)
        let ballIDs = Set(resolution.frames.flatMap { $0.balls.map(\.id) }).sorted()

        for ballID in ballIDs {
            let samples = resolution.frames.compactMap { frame -> (Double, BoardPoint)? in
                guard let ball = frame.balls.first(where: { $0.id == ballID }) else { return nil }
                return (frame.elapsedTime, ball.position)
            }
            guard let firstSample = samples.first else { continue }

            let ball = SKShapeNode(circleOfRadius: max(4, viewport.cellSize * 0.12))
            ball.name = "active-ball-\(ballID)"
            ball.position = viewport.scenePoint(for: firstSample.1)
            ball.fillColor = .white
            ball.strokeColor = .systemTeal
            ball.lineWidth = 2
            ball.zPosition = 20
            addChild(ball)

            var actions: [SKAction] = []
            if firstSample.0 > 0 {
                ball.alpha = 0
                actions.append(.wait(forDuration: firstSample.0))
                actions.append(.fadeIn(withDuration: 0.01))
            }
            var previousTime = firstSample.0
            for sample in samples.dropFirst() {
                let duration = max(0.001, sample.0 - previousTime)
                previousTime = sample.0
                actions.append(.move(to: viewport.scenePoint(for: sample.1), duration: duration))
            }
            ball.run(.sequence(actions))
        }

        let duration = resolution.frames.last?.elapsedTime ?? 0
        run(.wait(forDuration: duration)) { [weak self] in
            guard let self else { return }
            self.isAnimatingShot = false
            self.renderSnapshot()
            self.renderEventFeedback(resolution.finalSnapshot.shotHistory.last?.events ?? [])
        }
    }

    private func renderEventFeedback(_ events: [GameplayEvent]) {
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

        if let dangerLineRow = gameState?.configuredDangerLineRow {
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
        guard let bounds = geometry.brickBounds(at: brick.coordinate) else {
            return
        }

        let center = viewport.scenePoint(for: BoardPoint(
            x: (bounds.minX + bounds.maxX) / 2,
            y: (bounds.minY + bounds.maxY) / 2
        ))
        let brickSize = CGSize(width: viewport.cellSize * 0.86, height: viewport.cellSize * 0.72)
        let node = SKShapeNode(rectOf: brickSize, cornerRadius: min(8, viewport.cellSize * 0.16))
        node.position = center
        node.fillColor = brick.kind.color
        node.strokeColor = brick.isProtected ? .systemCyan : UIColor.white.withAlphaComponent(0.5)
        node.lineWidth = brick.kind == .mission || brick.isProtected ? 3 : 1
        addChild(node)

        let label = SKLabelNode(text: brick.kind == .standard ? "\(brick.hitPoints)" : "\(brick.kind.shortLabel) \(brick.hitPoints)")
        label.fontName = "AvenirNext-Bold"
        label.fontSize = max(11, viewport.cellSize * 0.24)
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.position = center
        label.zPosition = 2
        addChild(label)

        if brick.isLocked || brick.isProtected {
            let stateLabel = SKLabelNode(text: brick.isLocked ? "🔒" : "◇")
            stateLabel.fontSize = max(10, viewport.cellSize * 0.22)
            stateLabel.horizontalAlignmentMode = .right
            stateLabel.verticalAlignmentMode = .top
            stateLabel.position = CGPoint(
                x: center.x + brickSize.width * 0.45,
                y: center.y + brickSize.height * 0.45
            )
            stateLabel.zPosition = 3
            addChild(stateLabel)
        }
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
        path.addLine(to: target)

        let guide = SKShapeNode(path: path)
        guide.name = "aim-guide"
        guide.strokeColor = isValid ? .systemTeal : .systemRed
        guide.lineWidth = 3
        guide.lineCap = .round
        guide.zPosition = 9
        addChild(guide)
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
            text = "Touch and hold the field to aim"
            color = .secondaryLabel
        case .aiming:
            text = isAimCancelled ? "Release to cancel" : "Release to fire"
            color = isAimCancelled ? .systemRed : .systemTeal
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
        case .standard: ""
        case .mission: "M"
        case .shield: "S"
        case .key: "K"
        case .bomb: "B"
        case .splitter: "X"
        }
    }
}
