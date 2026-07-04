import SpriteKit
import UIKit

final class BrickPuzzleScene: SKScene {
    private var snapshot: GameSnapshot?

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        scaleMode = .resizeFill
        backgroundColor = .clear
    }

    func configure(level: LevelDefinition) {
        configure(snapshot: GameState(level: level).snapshot)
    }

    func configure(snapshot: GameSnapshot) {
        self.snapshot = snapshot
        renderBoard()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        renderBoard()
    }

    private func renderBoard() {
        removeAllChildren()

        guard let snapshot, size.width > 0, size.height > 0 else {
            return
        }

        let boardColumns = max(snapshot.boardSize.columns, 1)
        let boardRows = max(snapshot.boardSize.rows, 1)
        let horizontalInset: CGFloat = 24
        let topInset: CGFloat = 42
        let launcherHeight: CGFloat = 92
        let availableWidth = size.width - horizontalInset * 2
        let availableHeight = size.height - topInset - launcherHeight
        let cellSize = min(availableWidth / CGFloat(boardColumns), availableHeight / CGFloat(boardRows))
        let boardWidth = cellSize * CGFloat(boardColumns)
        let boardHeight = cellSize * CGFloat(boardRows)
        let startX = (size.width - boardWidth) / 2
        let topY = size.height - topInset

        renderBoardBackground(
            origin: CGPoint(x: startX, y: topY - boardHeight),
            size: CGSize(width: boardWidth, height: boardHeight)
        )

        for brick in snapshot.activeBricks {
            renderBrick(brick, startX: startX, topY: topY, cellSize: cellSize)
        }

        renderLauncher(boardBottomY: topY - boardHeight)
        renderLevelLabel(snapshot)
    }

    private func renderBoardBackground(origin: CGPoint, size: CGSize) {
        let board = SKShapeNode(rect: CGRect(origin: origin, size: size), cornerRadius: 14)
        board.fillColor = UIColor.systemBackground.withAlphaComponent(0.72)
        board.strokeColor = UIColor.separator.withAlphaComponent(0.45)
        board.lineWidth = 1
        board.zPosition = -1
        addChild(board)
    }

    private func renderBrick(_ brick: BrickState, startX: CGFloat, topY: CGFloat, cellSize: CGFloat) {
        let x = startX + CGFloat(brick.coordinate.column) * cellSize + cellSize / 2
        let y = topY - CGFloat(brick.coordinate.row) * cellSize - cellSize / 2
        let brickSize = CGSize(width: cellSize * 0.86, height: cellSize * 0.72)

        let node = SKShapeNode(rectOf: brickSize, cornerRadius: min(8, cellSize * 0.16))
        node.position = CGPoint(x: x, y: y)
        node.fillColor = brick.kind.color
        node.strokeColor = UIColor.white.withAlphaComponent(0.35)
        node.lineWidth = 1
        addChild(node)

        let label = SKLabelNode(text: brick.kind.shortLabel)
        label.fontName = "AvenirNext-Bold"
        label.fontSize = max(12, cellSize * 0.28)
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.position = node.position
        addChild(label)
    }

    private func renderLauncher(boardBottomY: CGFloat) {
        let launcherY = max(44, boardBottomY - 56)
        let launcher = SKShapeNode(circleOfRadius: 18)
        launcher.position = CGPoint(x: size.width / 2, y: launcherY)
        launcher.fillColor = UIColor.label
        launcher.strokeColor = UIColor.systemBackground
        launcher.lineWidth = 3
        addChild(launcher)

        let path = CGMutablePath()
        path.move(to: launcher.position)
        path.addLine(to: CGPoint(x: size.width * 0.68, y: launcherY + 110))

        let aimLine = SKShapeNode(path: path)
        aimLine.strokeColor = UIColor.systemTeal
        aimLine.lineWidth = 3
        aimLine.lineCap = .round
        addChild(aimLine)
    }

    private func renderLevelLabel(_ snapshot: GameSnapshot) {
        let label = SKLabelNode(text: snapshot.levelTitle)
        label.fontName = "AvenirNext-DemiBold"
        label.fontSize = 16
        label.fontColor = UIColor.label
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: size.width / 2, y: size.height - 20)
        addChild(label)
    }
}

private extension BrickKind {
    var color: UIColor {
        switch self {
        case .standard:
            return .systemBlue
        case .mission:
            return .systemGreen
        case .shield:
            return .systemIndigo
        case .key:
            return .systemOrange
        case .bomb:
            return .systemRed
        case .splitter:
            return .systemPurple
        }
    }

    var shortLabel: String {
        switch self {
        case .standard:
            return "2"
        case .mission:
            return "M"
        case .shield:
            return "S"
        case .key:
            return "K"
        case .bomb:
            return "B"
        case .splitter:
            return "X"
        }
    }
}
