import SpriteKit
import GameplayKit

struct PhysicsCategory {
    static let none: UInt32 = 0
    static let bird: UInt32 = 0x1 << 0
    static let pipe: UInt32 = 0x1 << 1
    static let ground: UInt32 = 0x1 << 2
    static let scoreZone: UInt32 = 0x1 << 3
}

class GameScene: SKScene, SKPhysicsContactDelegate {

    // MARK: - Nodes
    private var bird: SKSpriteNode!
    private var scoreLabel: SKLabelNode!
    private var bestScoreLabel: SKLabelNode!
    private var gameOverNode: SKNode!
    private var tapToStartLabel: SKLabelNode!
    private var groundNode: SKNode!
    private var bgColor = UIColor(red: 0.48, green: 0.78, blue: 0.89, alpha: 1.0)

    // MARK: - Game State
    private enum GameState {
        case idle, playing, gameOver
    }

    private var gameState: GameState = .idle
    private var score = 0
    private var bestScore = 0
    private var pipeSpawnTimer: Timer?
    private var lastUpdateTime: TimeInterval = 0

    // MARK: - Constants
    private let birdSize = CGSize(width: 40, height: 30)
    private let pipeWidth: CGFloat = 60
    private let pipeGap: CGFloat = 160
    private let groundHeight: CGFloat = 80
    private let pipeSpeed: CGFloat = 150
    private let flapImpulse: CGFloat = 280
    private let gravity: CGFloat = -600

    // MARK: - Setup
    override func didMove(to view: SKView) {
        bestScore = UserDefaults.standard.integer(forKey: "bestScore")
        physicsWorld.contactDelegate = self
        physicsWorld.gravity = CGVector(dx: 0, dy: gravity / 100)
        setupBackground()
        setupGround()
        setupBird()
        setupUI()
        showIdleState()
    }

    private func setupBackground() {
        backgroundColor = bgColor

        // Clouds
        for i in 0..<4 {
            let cloud = makeCloud()
            cloud.position = CGPoint(x: CGFloat(i) * size.width / 3 + 80, y: size.height * 0.75 + CGFloat(i % 2) * 40)
            addChild(cloud)
            animateCloud(cloud)
        }
    }

    private func makeCloud() -> SKNode {
        let cloud = SKNode()
        let positions: [(CGFloat, CGFloat, CGFloat)] = [
            (0, 0, 30), (-22, -5, 22), (22, -5, 22), (-11, 10, 20), (11, 10, 20)
        ]
        for (x, y, r) in positions {
            let circle = SKShapeNode(circleOfRadius: r)
            circle.fillColor = .white
            circle.strokeColor = .clear
            circle.alpha = 0.85
            circle.position = CGPoint(x: x, y: y)
            cloud.addChild(circle)
        }
        return cloud
    }

    private func animateCloud(_ cloud: SKNode) {
        let duration = Double.random(in: 18...28)
        let moveLeft = SKAction.moveBy(x: -size.width - 200, y: 0, duration: duration)
        let reset = SKAction.run { [weak self, weak cloud] in
            guard let self = self, let cloud = cloud else { return }
            cloud.position.x = self.size.width + 100
        }
        cloud.run(SKAction.repeatForever(SKAction.sequence([moveLeft, reset])))
    }

    private func setupGround() {
        groundNode = SKNode()
        addChild(groundNode)

        let groundBody = SKPhysicsBody(rectangleOf: CGSize(width: size.width * 10, height: groundHeight))
        groundBody.isDynamic = false
        groundBody.categoryBitMask = PhysicsCategory.ground
        groundBody.contactTestBitMask = PhysicsCategory.bird
        groundBody.collisionBitMask = PhysicsCategory.bird
        groundNode.physicsBody = groundBody
        groundNode.position = CGPoint(x: size.width / 2, y: groundHeight / 2)

        // Visual ground
        let groundRect = SKShapeNode(rectOf: CGSize(width: size.width * 10, height: groundHeight))
        groundRect.fillColor = UIColor(red: 0.55, green: 0.76, blue: 0.29, alpha: 1.0)
        groundRect.strokeColor = .clear
        groundNode.addChild(groundRect)

        // Dirt stripe
        let dirtRect = SKShapeNode(rectOf: CGSize(width: size.width * 10, height: groundHeight * 0.5))
        dirtRect.fillColor = UIColor(red: 0.82, green: 0.59, blue: 0.27, alpha: 1.0)
        dirtRect.strokeColor = .clear
        dirtRect.position = CGPoint(x: 0, y: -groundHeight * 0.25)
        groundNode.addChild(dirtRect)
    }

    private func setupBird() {
        bird = SKSpriteNode(color: .clear, size: birdSize)
        bird.position = CGPoint(x: size.width * 0.25, y: size.height * 0.5)
        bird.zPosition = 10

        // Bird body
        let body = SKShapeNode(ellipseOf: CGSize(width: birdSize.width, height: birdSize.height))
        body.fillColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0)
        body.strokeColor = UIColor(red: 0.8, green: 0.6, blue: 0.0, alpha: 1.0)
        body.lineWidth = 2
        body.name = "birdBody"
        bird.addChild(body)

        // Wing
        let wing = SKShapeNode(ellipseOf: CGSize(width: 16, height: 10))
        wing.fillColor = UIColor(red: 1.0, green: 0.65, blue: 0.0, alpha: 1.0)
        wing.strokeColor = .clear
        wing.position = CGPoint(x: -4, y: -2)
        wing.name = "wing"
        bird.addChild(wing)

        // Eye
        let eye = SKShapeNode(circleOfRadius: 6)
        eye.fillColor = .white
        eye.strokeColor = UIColor(red: 0.6, green: 0.4, blue: 0.0, alpha: 1.0)
        eye.lineWidth = 1.5
        eye.position = CGPoint(x: 10, y: 6)
        bird.addChild(eye)

        let pupil = SKShapeNode(circleOfRadius: 3)
        pupil.fillColor = UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        pupil.strokeColor = .clear
        pupil.position = CGPoint(x: 11, y: 6)
        bird.addChild(pupil)

        // Beak
        let beakPath = CGMutablePath()
        beakPath.move(to: CGPoint(x: 16, y: 3))
        beakPath.addLine(to: CGPoint(x: 26, y: 0))
        beakPath.addLine(to: CGPoint(x: 16, y: -3))
        beakPath.closeSubpath()
        let beak = SKShapeNode(path: beakPath)
        beak.fillColor = UIColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1.0)
        beak.strokeColor = .clear
        bird.addChild(beak)

        addChild(bird)
        setupBirdPhysics()
    }

    private func setupBirdPhysics() {
        let physicsBody = SKPhysicsBody(ellipseOf: CGSize(width: birdSize.width - 4, height: birdSize.height - 4))
        physicsBody.isDynamic = false
        physicsBody.allowsRotation = true
        physicsBody.categoryBitMask = PhysicsCategory.bird
        physicsBody.contactTestBitMask = PhysicsCategory.pipe | PhysicsCategory.ground | PhysicsCategory.scoreZone
        physicsBody.collisionBitMask = PhysicsCategory.pipe | PhysicsCategory.ground
        physicsBody.restitution = 0
        physicsBody.friction = 0
        bird.physicsBody = physicsBody
    }

    private func setupUI() {
        // Score label
        scoreLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        scoreLabel.fontSize = 48
        scoreLabel.fontColor = .white
        scoreLabel.position = CGPoint(x: size.width / 2, y: size.height - 100)
        scoreLabel.zPosition = 20
        scoreLabel.shadowColor = UIColor(white: 0, alpha: 0.5)
        scoreLabel.shadowOffset = CGSize(width: 2, height: -2)
        scoreLabel.text = "0"
        scoreLabel.isHidden = true
        addChild(scoreLabel)

        // Best score label
        bestScoreLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
        bestScoreLabel.fontSize = 20
        bestScoreLabel.fontColor = UIColor(white: 1, alpha: 0.9)
        bestScoreLabel.position = CGPoint(x: size.width / 2, y: size.height - 140)
        bestScoreLabel.zPosition = 20
        bestScoreLabel.isHidden = true
        addChild(bestScoreLabel)

        setupGameOverPanel()
    }

    private func setupGameOverPanel() {
        gameOverNode = SKNode()
        gameOverNode.zPosition = 30
        gameOverNode.isHidden = true
        addChild(gameOverNode)

        // Panel background
        let panel = SKShapeNode(rectOf: CGSize(width: 280, height: 220), cornerRadius: 20)
        panel.fillColor = UIColor(white: 0, alpha: 0.75)
        panel.strokeColor = UIColor(white: 1, alpha: 0.3)
        panel.lineWidth = 2
        panel.position = CGPoint(x: size.width / 2, y: size.height / 2)
        gameOverNode.addChild(panel)

        let gameOverTitle = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        gameOverTitle.text = "GAME OVER"
        gameOverTitle.fontSize = 30
        gameOverTitle.fontColor = UIColor(red: 1.0, green: 0.35, blue: 0.35, alpha: 1.0)
        gameOverTitle.position = CGPoint(x: size.width / 2, y: size.height / 2 + 70)
        gameOverNode.addChild(gameOverTitle)

        let scoreTitle = SKLabelNode(fontNamed: "AvenirNext-Medium")
        scoreTitle.text = "SCORE"
        scoreTitle.fontSize = 18
        scoreTitle.fontColor = UIColor(white: 0.8, alpha: 1.0)
        scoreTitle.name = "scoreTitle"
        scoreTitle.position = CGPoint(x: size.width / 2 - 60, y: size.height / 2 + 25)
        gameOverNode.addChild(scoreTitle)

        let bestTitle = SKLabelNode(fontNamed: "AvenirNext-Medium")
        bestTitle.text = "BEST"
        bestTitle.fontSize = 18
        bestTitle.fontColor = UIColor(white: 0.8, alpha: 1.0)
        bestTitle.name = "bestTitle"
        bestTitle.position = CGPoint(x: size.width / 2 + 60, y: size.height / 2 + 25)
        gameOverNode.addChild(bestTitle)

        let scoreVal = SKLabelNode(fontNamed: "AvenirNext-Bold")
        scoreVal.fontSize = 36
        scoreVal.fontColor = .white
        scoreVal.name = "gameOverScore"
        scoreVal.position = CGPoint(x: size.width / 2 - 60, y: size.height / 2 - 10)
        gameOverNode.addChild(scoreVal)

        let bestVal = SKLabelNode(fontNamed: "AvenirNext-Bold")
        bestVal.fontSize = 36
        bestVal.fontColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0)
        bestVal.name = "gameOverBest"
        bestVal.position = CGPoint(x: size.width / 2 + 60, y: size.height / 2 - 10)
        gameOverNode.addChild(bestVal)

        // Divider line
        let divider = SKShapeNode(rectOf: CGSize(width: 2, height: 60))
        divider.fillColor = UIColor(white: 0.6, alpha: 0.5)
        divider.strokeColor = .clear
        divider.position = CGPoint(x: size.width / 2, y: size.height / 2 + 10)
        gameOverNode.addChild(divider)

        // Restart button
        let restartBtn = SKShapeNode(rectOf: CGSize(width: 180, height: 48), cornerRadius: 24)
        restartBtn.fillColor = UIColor(red: 0.27, green: 0.76, blue: 0.35, alpha: 1.0)
        restartBtn.strokeColor = .clear
        restartBtn.name = "restartButton"
        restartBtn.position = CGPoint(x: size.width / 2, y: size.height / 2 - 75)
        gameOverNode.addChild(restartBtn)

        let restartLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        restartLabel.text = "Play Again"
        restartLabel.fontSize = 20
        restartLabel.fontColor = .white
        restartLabel.verticalAlignmentMode = .center
        restartLabel.name = "restartButton"
        restartBtn.addChild(restartLabel)
    }

    private func showIdleState() {
        gameState = .idle
        bird.physicsBody?.isDynamic = false
        bird.position = CGPoint(x: size.width * 0.25, y: size.height * 0.5)
        bird.zRotation = 0

        // Tap to start label
        tapToStartLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        tapToStartLabel.text = "Tap to Start!"
        tapToStartLabel.fontSize = 28
        tapToStartLabel.fontColor = .white
        tapToStartLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 + 100)
        tapToStartLabel.zPosition = 20
        tapToStartLabel.shadowColor = UIColor(white: 0, alpha: 0.5)
        tapToStartLabel.shadowOffset = CGSize(width: 1, height: -1)
        addChild(tapToStartLabel)

        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.1, duration: 0.5),
            SKAction.scale(to: 0.95, duration: 0.5)
        ])
        tapToStartLabel.run(SKAction.repeatForever(pulse))

        // Idle bird animation
        let bobUp = SKAction.moveBy(x: 0, y: 12, duration: 0.5)
        let bobDown = SKAction.moveBy(x: 0, y: -12, duration: 0.5)
        bobUp.timingMode = .easeInEaseOut
        bobDown.timingMode = .easeInEaseOut
        bird.run(SKAction.repeatForever(SKAction.sequence([bobUp, bobDown])), withKey: "idle")
    }

    // MARK: - Game Control
    private func startGame() {
        gameState = .playing
        score = 0
        scoreLabel.text = "0"
        scoreLabel.isHidden = false
        bestScoreLabel.isHidden = true
        tapToStartLabel?.removeFromParent()
        bird.removeAction(forKey: "idle")
        bird.physicsBody?.isDynamic = true
        bird.position = CGPoint(x: size.width * 0.25, y: size.height * 0.5)
        flap()
        startSpawningPipes()
    }

    private func flap() {
        guard gameState == .playing else { return }
        bird.physicsBody?.velocity = CGVector(dx: 0, dy: 0)
        bird.physicsBody?.applyImpulse(CGVector(dx: 0, dy: flapImpulse / 10))

        // Wing flap animation
        bird.removeAction(forKey: "rotate")
        bird.zRotation = 0.4
        let rotateDown = SKAction.rotate(toAngle: -0.5, duration: 0.4)
        rotateDown.timingMode = .easeIn
        bird.run(rotateDown, withKey: "rotate")

        // Wing animation
        if let wing = bird.childNode(withName: "wing") as? SKShapeNode {
            wing.run(SKAction.sequence([
                SKAction.scaleY(to: 0.3, duration: 0.1),
                SKAction.scaleY(to: 1.0, duration: 0.15)
            ]))
        }
    }

    private func startSpawningPipes() {
        let spawn = SKAction.run { [weak self] in self?.spawnPipes() }
        let wait = SKAction.wait(forDuration: 2.2)
        let sequence = SKAction.sequence([spawn, wait])
        run(SKAction.repeatForever(sequence), withKey: "spawnPipes")
    }

    private func spawnPipes() {
        guard gameState == .playing else { return }

        let minY: CGFloat = groundHeight + pipeGap / 2 + 80
        let maxY: CGFloat = size.height - pipeGap / 2 - 60
        let gapCenterY = CGFloat.random(in: minY...maxY)

        let pipeColor = UIColor(red: 0.27, green: 0.76, blue: 0.35, alpha: 1.0)
        let pipeBorderColor = UIColor(red: 0.18, green: 0.55, blue: 0.24, alpha: 1.0)

        // Bottom pipe
        let bottomPipeHeight = gapCenterY - pipeGap / 2 - groundHeight
        let bottomPipe = makePipe(height: bottomPipeHeight, color: pipeColor, border: pipeBorderColor, isTop: false)
        bottomPipe.position = CGPoint(x: size.width + pipeWidth, y: groundHeight + bottomPipeHeight / 2)
        addChild(bottomPipe)

        // Top pipe
        let topPipeHeight = size.height - (gapCenterY + pipeGap / 2)
        let topPipe = makePipe(height: topPipeHeight, color: pipeColor, border: pipeBorderColor, isTop: true)
        topPipe.position = CGPoint(x: size.width + pipeWidth, y: size.height - topPipeHeight / 2)
        addChild(topPipe)

        // Invisible score zone
        let scoreZone = SKNode()
        scoreZone.position = CGPoint(x: size.width + pipeWidth, y: gapCenterY)
        let scoreBody = SKPhysicsBody(rectangleOf: CGSize(width: 2, height: pipeGap))
        scoreBody.isDynamic = false
        scoreBody.categoryBitMask = PhysicsCategory.scoreZone
        scoreBody.contactTestBitMask = PhysicsCategory.bird
        scoreBody.collisionBitMask = PhysicsCategory.none
        scoreZone.physicsBody = scoreBody
        scoreZone.name = "scoreZone"
        addChild(scoreZone)

        // Move pipes across screen
        let travelDistance = size.width + pipeWidth * 2 + 100
        let duration = Double(travelDistance / pipeSpeed)
        let move = SKAction.moveBy(x: -travelDistance, y: 0, duration: duration)
        let remove = SKAction.removeFromParent()
        let moveAndRemove = SKAction.sequence([move, remove])

        bottomPipe.run(moveAndRemove)
        topPipe.run(moveAndRemove)
        scoreZone.run(moveAndRemove)
    }

    private func makePipe(height: CGFloat, color: UIColor, border: UIColor, isTop: Bool) -> SKNode {
        let node = SKNode()

        // Main pipe body
        let body = SKShapeNode(rectOf: CGSize(width: pipeWidth, height: height))
        body.fillColor = color
        body.strokeColor = border
        body.lineWidth = 2
        node.addChild(body)

        // Pipe cap
        let capHeight: CGFloat = 24
        let capWidth = pipeWidth + 14
        let capOffsetY = isTop ? -(height / 2 + capHeight / 2 - 1) : (height / 2 + capHeight / 2 - 1)
        let cap = SKShapeNode(rectOf: CGSize(width: capWidth, height: capHeight), cornerRadius: 4)
        cap.fillColor = color
        cap.strokeColor = border
        cap.lineWidth = 2
        cap.position = CGPoint(x: 0, y: capOffsetY)
        node.addChild(cap)

        // Physics
        let pipeBody = SKPhysicsBody(rectangleOf: CGSize(width: pipeWidth, height: height))
        let capBody = SKPhysicsBody(rectangleOf: CGSize(width: capWidth, height: capHeight),
                                     center: CGPoint(x: 0, y: capOffsetY))
        let compound = SKPhysicsBody(bodies: [pipeBody, capBody])
        compound.isDynamic = false
        compound.categoryBitMask = PhysicsCategory.pipe
        compound.contactTestBitMask = PhysicsCategory.bird
        compound.collisionBitMask = PhysicsCategory.bird
        node.physicsBody = compound

        return node
    }

    // MARK: - Game Over
    private func triggerGameOver() {
        guard gameState == .playing else { return }
        gameState = .gameOver

        removeAction(forKey: "spawnPipes")
        bird.physicsBody?.isDynamic = false

        // Update best score
        if score > bestScore {
            bestScore = score
            UserDefaults.standard.set(bestScore, forKey: "bestScore")
        }

        // Screen flash
        let flash = SKShapeNode(rectOf: size)
        flash.fillColor = .white
        flash.strokeColor = .clear
        flash.position = CGPoint(x: size.width / 2, y: size.height / 2)
        flash.zPosition = 50
        addChild(flash)
        flash.run(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.7, duration: 0.05),
            SKAction.fadeOut(withDuration: 0.15),
            SKAction.removeFromParent()
        ]))

        // Bird fall animation
        let fallRotate = SKAction.rotate(toAngle: -.pi / 2, duration: 0.3)
        bird.run(fallRotate)

        // Show game over after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.showGameOverPanel()
        }
    }

    private func showGameOverPanel() {
        if let scoreNode = gameOverNode.childNode(withName: "gameOverScore") as? SKLabelNode {
            scoreNode.text = "\(score)"
        }
        if let bestNode = gameOverNode.childNode(withName: "gameOverBest") as? SKLabelNode {
            bestNode.text = "\(bestScore)"
        }

        gameOverNode.isHidden = false
        gameOverNode.alpha = 0
        gameOverNode.setScale(0.8)
        gameOverNode.run(SKAction.group([
            SKAction.fadeIn(withDuration: 0.3),
            SKAction.scale(to: 1.0, duration: 0.3)
        ]))
    }

    private func restartGame() {
        gameOverNode.isHidden = true

        // Remove pipes and score zones
        enumerateChildNodes(withName: "//scoreZone") { node, _ in node.removeFromParent() }
        children.filter { node in
            node.physicsBody?.categoryBitMask == PhysicsCategory.pipe
        }.forEach { $0.removeFromParent() }

        // Also remove pipe visual nodes (SKNode without physics or score zone)
        children.filter { node in
            node != bird && node != groundNode && node != scoreLabel &&
            node != bestScoreLabel && node != gameOverNode &&
            node.physicsBody?.categoryBitMask == PhysicsCategory.pipe ||
            (node.physicsBody == nil && node.name == nil && node != groundNode)
        }

        // Remove all pipe nodes by checking for children with pipe physics
        var nodesToRemove: [SKNode] = []
        enumerateChildNodes(withName: "//*") { node, _ in
            if node.physicsBody?.categoryBitMask == PhysicsCategory.pipe {
                nodesToRemove.append(node.parent ?? node)
            }
        }
        nodesToRemove.forEach { $0.removeFromParent() }

        score = 0
        bird.zRotation = 0
        bird.position = CGPoint(x: size.width * 0.25, y: size.height * 0.5)
        bird.physicsBody?.velocity = CGVector.zero
        gameState = .playing
        scoreLabel.text = "0"

        bird.physicsBody?.isDynamic = true
        flap()
        startSpawningPipes()
    }

    // MARK: - Touch Handling
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        switch gameState {
        case .idle:
            startGame()
        case .playing:
            flap()
        case .gameOver:
            let nodes = self.nodes(at: location)
            if nodes.contains(where: { $0.name == "restartButton" }) {
                restartGame()
            }
        }
    }

    // MARK: - Physics Contact
    func didBegin(_ contact: SKPhysicsContact) {
        let categoryA = contact.bodyA.categoryBitMask
        let categoryB = contact.bodyB.categoryBitMask

        if (categoryA == PhysicsCategory.bird && categoryB == PhysicsCategory.scoreZone) ||
           (categoryA == PhysicsCategory.scoreZone && categoryB == PhysicsCategory.bird) {
            incrementScore()
            // Remove the score zone so it only triggers once
            if categoryA == PhysicsCategory.scoreZone {
                contact.bodyA.node?.removeFromParent()
            } else {
                contact.bodyB.node?.removeFromParent()
            }
            return
        }

        if (categoryA == PhysicsCategory.bird || categoryB == PhysicsCategory.bird) &&
           (categoryA == PhysicsCategory.pipe || categoryB == PhysicsCategory.pipe ||
            categoryA == PhysicsCategory.ground || categoryB == PhysicsCategory.ground) {
            triggerGameOver()
        }
    }

    private func incrementScore() {
        score += 1
        scoreLabel.text = "\(score)"

        // Pop animation
        scoreLabel.removeAllActions()
        scoreLabel.setScale(1.4)
        scoreLabel.run(SKAction.scale(to: 1.0, duration: 0.15))
    }

    // MARK: - Update
    override func update(_ currentTime: TimeInterval) {
        guard gameState == .playing else { return }

        // Cap downward velocity
        if let vel = bird.physicsBody?.velocity.dy, vel < -400 {
            bird.physicsBody?.velocity = CGVector(dx: 0, dy: -400)
        }
    }
}
