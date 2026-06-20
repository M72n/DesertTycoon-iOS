import SpriteKit
import UIKit

private struct DTPlacedBuilding: Codable {
    var id: String
    var definitionID: String
    var category: String
    var column: Int
    var row: Int
    var state: String
    var cropID: String?
    var finishAt: TimeInterval?
    var assignedWorkers: Int
}

private struct DTGameState: Codable {
    var level: Int
    var points: Int
    var coins: Int
    var cash: Int
    var energy: Int
    var goods: Int
    var goodsCapacity: Int
    var populationCapacity: Int
    var availableWorkers: Int
    var assignedWorkers: Int
    var activeGoalIndex: Int
    var completedEvents: Set<String>
    var buildings: [DTPlacedBuilding]
    var lastSavedAt: TimeInterval
    var timerSpeed: Double

    static func newGame(from data: DesertTycoonGameData) -> DTGameState {
        let start = data.spec.startingState
        return DTGameState(
            level: start.level,
            points: 0,
            coins: start.coins,
            cash: start.cash,
            energy: start.energy,
            goods: start.goods,
            goodsCapacity: start.goodsCapacity,
            populationCapacity: start.populationCapacity,
            availableWorkers: start.availableWorkers,
            assignedWorkers: 0,
            activeGoalIndex: 0,
            completedEvents: [],
            buildings: [
                DTPlacedBuilding(
                    id: "starting_tent",
                    definitionID: "starting_tent",
                    category: "Housing",
                    column: 7,
                    row: 3,
                    state: "needsNeighbor",
                    cropID: nil,
                    finishAt: nil,
                    assignedWorkers: 0
                )
            ],
            lastSavedAt: Date().timeIntervalSince1970,
            timerSpeed: 1
        )
    }
}

private struct DTPlacement {
    var item: DTStoreItem
    var column: Int
    var row: Int
}

final class DesertTycoonScene: SKScene {
    private let worldNode = SKNode()
    private let tileLayer = SKNode()
    private let buildingLayer = SKNode()
    private let effectLayer = SKNode()
    private let cameraNode = SKCameraNode()
    private let hudNode = SKNode()
    private let overlayNode = SKNode()
    private let placementNode = SKNode()

    private var gameAtlas: CocosTextureAtlas?
    private var soukAtlas: CocosTextureAtlas?
    private var balloonAtlas: CocosTextureAtlas?
    private var backgroundAtlas: CocosTextureAtlas?
    private var workersAtlas: CocosTextureAtlas?
    private var charactersAtlas: CocosTextureAtlas?
    private var characters2Atlas: CocosTextureAtlas?
    private var musicNode: SKAudioNode?

    private var data: DesertTycoonGameData!
    private var state: DTGameState!
    private var selectedSoukCategory = "Farming"
    private var activePlacement: DTPlacement?
    private var didSetUpScene = false
    private var didFitCamera = false
    private var lastTickSecond = -1
    private var lastAutosave = Date().timeIntervalSince1970
    private var tutorialText = "الخطوة الأولى لتصبح سلطان الصحراء هي زيادة سكان مدينتك."

    private let mapColumns = 14
    private let mapRows = 10
    private let tileWidth: CGFloat = 86
    private let tileHeight: CGFloat = 44
    private var mapOffsetY: CGFloat { CGFloat(mapRows) * tileHeight / 2 }

    override init(size: CGSize) {
        super.init(size: size)
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = UIColor(red: 0.76, green: 0.64, blue: 0.45, alpha: 1)
        physicsWorld.gravity = .zero
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = UIColor(red: 0.76, green: 0.64, blue: 0.45, alpha: 1)
        physicsWorld.gravity = .zero
    }

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = true
        view.ignoresSiblingOrder = true
        view.shouldCullNonVisibleNodes = true

        guard !didSetUpScene else {
            layoutCamera()
            return
        }

        didSetUpScene = true
        setUpScene()
        layoutCamera()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutCamera()
    }

    func layoutCamera() {
        guard didSetUpScene, size.width > 0, size.height > 0 else { return }

        if !didFitCamera {
            let bounds = worldBounds()
            let scale = max(bounds.width / max(size.width, 1), (bounds.height + 120) / max(size.height, 1)) * 0.92
            cameraNode.position = CGPoint(x: 40, y: -80)
            cameraNode.setScale(min(max(scale, 0.82), 1.45))
            didFitCamera = true
        }

        clampCamera()
        layoutHUD()
        layoutOverlay()
        layoutPlacementControls()
    }

    private func setUpScene() {
        removeAllChildren()
        worldNode.removeAllChildren()
        cameraNode.removeAllChildren()

        gameAtlas = CocosTextureAtlas(plistCandidates: ["iphone-hd-upscaled/game-images.plist", "iphone-hd/game-images.plist"])
        soukAtlas = CocosTextureAtlas(plistCandidates: ["iphone-hd-upscaled/souk-images.plist", "iphone-hd/souk-images.plist"])
        balloonAtlas = CocosTextureAtlas(plistCandidates: ["iphone-hd-upscaled/balloons-images.plist", "iphone-hd/balloons-images.plist"])
        backgroundAtlas = CocosTextureAtlas(plistCandidates: ["iphone-hd-upscaled/background-images.plist", "iphone-hd/background-images.plist"])
        workersAtlas = CocosTextureAtlas(plistCandidates: ["iphone-hd-upscaled/workers-images.plist", "iphone-hd/workers-images.plist"])
        charactersAtlas = CocosTextureAtlas(plistCandidates: ["iphone-hd-upscaled/characters-images.plist", "iphone-hd/characters-images.plist"])
        characters2Atlas = CocosTextureAtlas(plistCandidates: ["iphone-hd-upscaled/characters2-images.plist", "iphone-hd/characters2-images.plist"])

        data = DesertTycoonGameData.load()
        state = loadState()
        updateTimedBuildings(now: Date().timeIntervalSince1970, shouldRender: false)

        addChild(worldNode)
        worldNode.addChild(tileLayer)
        worldNode.addChild(buildingLayer)
        worldNode.addChild(effectLayer)

        addChild(cameraNode)
        cameraNode.addChild(hudNode)
        cameraNode.addChild(overlayNode)
        cameraNode.addChild(placementNode)
        camera = cameraNode

        drawMap()
        renderBuildings()
        startBackgroundMusic()

        if !state.completedEvents.contains("assign_neighbor:starting_tent") {
            presentGoals()
        }
    }

    private func loadState() -> DTGameState {
        if let saved = UserDefaults.standard.data(forKey: "DesertTycoon.Save.v2"),
           let decoded = try? JSONDecoder().decode(DTGameState.self, from: saved) {
            return decoded
        }

        return DTGameState.newGame(from: data)
    }

    private func saveState() {
        state.lastSavedAt = Date().timeIntervalSince1970
        if let encoded = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(encoded, forKey: "DesertTycoon.Save.v2")
        }
        lastAutosave = state.lastSavedAt
    }

    private func resetSave() {
        UserDefaults.standard.removeObject(forKey: "DesertTycoon.Save.v2")
        state = DTGameState.newGame(from: data)
        activePlacement = nil
        tutorialText = "الخطوة الأولى لتصبح سلطان الصحراء هي زيادة سكان مدينتك."
        renderBuildings()
        layoutHUD()
        closeOverlay()
        presentGoals()
        saveState()
    }

    private func startBackgroundMusic() {
        guard musicNode == nil,
              let url = BundleAssetResolver.url(candidates: ["music_sound/BackgroundSound.mp3"]) else {
            return
        }

        let node = SKAudioNode(url: url)
        node.autoplayLooped = true
        node.run(.changeVolume(to: 0.25, duration: 0))
        musicNode = node
        addChild(node)
    }

    private func drawMap() {
        tileLayer.removeAllChildren()

        let villageTiles = Set([
            "3:3", "4:3", "5:3", "6:3", "7:3", "8:3", "9:3", "10:3",
            "3:4", "4:4", "5:4", "6:4", "7:4", "8:4", "9:4", "10:4",
            "3:5", "4:5", "5:5", "6:5", "7:5", "8:5", "9:5", "10:5",
            "4:6", "5:6", "6:6", "7:6", "8:6", "9:6"
        ])

        let pathTiles = Set([
            "4:2", "5:2", "6:2", "7:2", "8:2",
            "4:3", "8:3", "4:4", "8:4", "4:5", "8:5",
            "4:6", "5:6", "6:6", "7:6", "8:6",
            "9:4", "10:5", "11:6"
        ])

        for row in 0..<mapRows {
            for column in 0..<mapColumns {
                let tile = SKShapeNode(path: diamondPath(width: tileWidth, height: tileHeight))
                tile.position = positionForTile(column: column, row: row)
                tile.zPosition = CGFloat(row + column)
                let key = tileKey(column: column, row: row)
                if pathTiles.contains(key) {
                    tile.fillColor = UIColor(red: 0.70, green: 0.62, blue: 0.48, alpha: 0.92)
                    tile.strokeColor = UIColor(red: 0.82, green: 0.73, blue: 0.56, alpha: 0.85)
                    tile.lineWidth = 1.2
                } else if villageTiles.contains(key) {
                    tile.fillColor = UIColor(red: 0.88, green: 0.78, blue: 0.56, alpha: 1)
                    tile.strokeColor = UIColor(red: 0.78, green: 0.67, blue: 0.47, alpha: 0.42)
                    tile.lineWidth = 0.5
                } else {
                    let alternate = (column + row) % 2 == 0
                    tile.fillColor = alternate
                        ? UIColor(red: 0.82, green: 0.69, blue: 0.48, alpha: 1)
                        : UIColor(red: 0.79, green: 0.66, blue: 0.46, alpha: 1)
                    tile.strokeColor = UIColor(red: 0.70, green: 0.58, blue: 0.40, alpha: 0.25)
                    tile.lineWidth = 0.35
                }
                tileLayer.addChild(tile)
            }
        }

        addBuildPad(atColumn: 6, row: 4)
        addBuildPad(atColumn: 7, row: 5)
        addBuildPad(atColumn: 9, row: 5)
        addPalm(atColumn: 6, row: 2)
        addPalm(atColumn: 8, row: 3)
        addPalm(atColumn: 3, row: 7)
        addRock(atColumn: 1, row: 2)
        addRock(atColumn: 12, row: 8)
    }

    private func diamondPath(width: CGFloat, height: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: height / 2))
        path.addLine(to: CGPoint(x: width / 2, y: 0))
        path.addLine(to: CGPoint(x: 0, y: -height / 2))
        path.addLine(to: CGPoint(x: -width / 2, y: 0))
        path.closeSubpath()
        return path
    }

    private func addPalm(atColumn column: Int, row: Int) {
        let root = SKNode()
        root.position = positionForTile(column: column, row: row)
        root.zPosition = 4_000 - root.position.y
        let trunk = SKShapeNode(rectOf: CGSize(width: 8, height: 36), cornerRadius: 3)
        trunk.fillColor = UIColor(red: 0.46, green: 0.28, blue: 0.13, alpha: 1)
        trunk.strokeColor = .clear
        trunk.position = CGPoint(x: 0, y: 20)
        root.addChild(trunk)
        for index in 0..<6 {
            let leaf = SKShapeNode(ellipseOf: CGSize(width: 46, height: 12))
            leaf.fillColor = UIColor(red: 0.12, green: 0.46, blue: 0.24, alpha: 1)
            leaf.strokeColor = .clear
            leaf.position = CGPoint(x: 0, y: 42)
            leaf.zRotation = CGFloat(index) * .pi / 3
            root.addChild(leaf)
        }
        tileLayer.addChild(root)
    }

    private func addBuildPad(atColumn column: Int, row: Int) {
        let pad = SKShapeNode(path: diamondPath(width: tileWidth * 1.45, height: tileHeight * 1.45))
        pad.fillColor = UIColor(red: 0.86, green: 0.75, blue: 0.56, alpha: 0.42)
        pad.strokeColor = UIColor(red: 0.67, green: 0.55, blue: 0.38, alpha: 0.62)
        pad.lineWidth = 1.2
        pad.position = positionForTile(column: column, row: row)
        pad.zPosition = 4_000 - pad.position.y - 2
        tileLayer.addChild(pad)
    }

    private func addRock(atColumn column: Int, row: Int) {
        let rock = SKShapeNode(ellipseOf: CGSize(width: 22, height: 12))
        rock.fillColor = UIColor(red: 0.53, green: 0.49, blue: 0.41, alpha: 1)
        rock.strokeColor = UIColor(red: 0.39, green: 0.35, blue: 0.29, alpha: 1)
        rock.position = positionForTile(column: column, row: row)
        rock.zPosition = 4_000 - rock.position.y
        tileLayer.addChild(rock)
    }

    private func renderBuildings() {
        buildingLayer.removeAllChildren()

        for building in state.buildings {
            let node = node(for: building)
            buildingLayer.addChild(node)
        }
    }

    private func node(for building: DTPlacedBuilding) -> SKNode {
        let root = SKNode()
        root.name = "building:\(building.id)"
        root.position = positionForTile(column: building.column, row: building.row)
        root.zPosition = 10_000 - root.position.y

        switch building.category {
        case "Farming":
            addFarmPlot(to: root, building: building)
        case "Business":
            addBusiness(to: root, building: building)
        case "Housing":
            addHouse(to: root, building: building)
        case "Community":
            addCommunity(to: root, building: building)
        default:
            addGenericBuilding(to: root, building: building)
        }

        addStatus(for: building, to: root)
        return root
    }

    private func addFarmPlot(to root: SKNode, building: DTPlacedBuilding) {
        let field = SKShapeNode(path: diamondPath(width: tileWidth * 1.35, height: tileHeight * 1.35))
        field.fillColor = UIColor(red: 0.42, green: 0.26, blue: 0.13, alpha: 1)
        field.strokeColor = UIColor(red: 0.75, green: 0.60, blue: 0.34, alpha: 1)
        field.lineWidth = 2
        field.name = root.name
        root.addChild(field)

        for offset in stride(from: -32, through: 32, by: 16) {
            let row = SKShapeNode(rectOf: CGSize(width: 82, height: 3), cornerRadius: 1)
            row.fillColor = UIColor(red: 0.25, green: 0.17, blue: 0.09, alpha: 0.55)
            row.strokeColor = .clear
            row.position = CGPoint(x: 0, y: CGFloat(offset) / 3)
            row.zRotation = -0.45
            row.name = root.name
            root.addChild(row)
        }

        if let cropID = building.cropID, building.state != "empty" {
            for index in 0..<8 {
                let plant = SKShapeNode(ellipseOf: CGSize(width: 12, height: 8))
                plant.fillColor = building.state == "readyCrop"
                    ? UIColor(red: 0.30, green: 0.70, blue: 0.20, alpha: 1)
                    : UIColor(red: 0.18, green: 0.48, blue: 0.18, alpha: 1)
                plant.strokeColor = UIColor(red: 0.10, green: 0.34, blue: 0.12, alpha: 1)
                let x = CGFloat((index % 4) - 1) * 18 - 9
                let y = CGFloat(index / 4) * 12 - 8
                plant.position = CGPoint(x: x, y: y)
                plant.zRotation = -0.45
                plant.name = root.name
                root.addChild(plant)
            }

            let cropLabel = label(data.crop(id: cropID)?.name ?? cropID.capitalized, size: 14, color: .white, alignment: .center)
            cropLabel.position = CGPoint(x: 0, y: 44)
            cropLabel.zPosition = 20
            cropLabel.name = root.name
            root.addChild(cropLabel)
        }
    }

    private func addBusiness(to root: SKNode, building: DTPlacedBuilding) {
        let base = SKShapeNode(path: diamondPath(width: tileWidth * 1.25, height: tileHeight * 1.25))
        base.fillColor = UIColor(red: 0.48, green: 0.31, blue: 0.20, alpha: 1)
        base.strokeColor = UIColor(red: 0.88, green: 0.73, blue: 0.45, alpha: 1)
        base.lineWidth = 2
        base.name = root.name
        root.addChild(base)

        let canopy = SKShapeNode(rectOf: CGSize(width: 74, height: 42), cornerRadius: 5)
        canopy.fillColor = UIColor(red: 0.28, green: 0.10, blue: 0.08, alpha: 1)
        canopy.strokeColor = UIColor(red: 0.95, green: 0.79, blue: 0.45, alpha: 1)
        canopy.position = CGPoint(x: 0, y: 28)
        canopy.name = root.name
        root.addChild(canopy)

        for stripeIndex in -2...2 {
            let stripe = SKShapeNode(rectOf: CGSize(width: 7, height: 36), cornerRadius: 1)
            stripe.fillColor = stripeIndex % 2 == 0 ? UIColor(red: 0.86, green: 0.72, blue: 0.36, alpha: 1) : UIColor(red: 0.43, green: 0.13, blue: 0.10, alpha: 1)
            stripe.strokeColor = .clear
            stripe.position = CGPoint(x: CGFloat(stripeIndex) * 10, y: 28)
            stripe.name = root.name
            root.addChild(stripe)
        }

        let icon = iconSprite(for: "Business", fallbackSize: CGSize(width: 34, height: 34))
        icon.position = CGPoint(x: 0, y: 30)
        icon.size = CGSize(width: 30, height: 30)
        icon.name = root.name
        root.addChild(icon)
    }

    private func addHouse(to root: SKNode, building: DTPlacedBuilding) {
        let base = SKShapeNode(path: diamondPath(width: tileWidth * 1.10, height: tileHeight * 1.10))
        base.fillColor = UIColor(red: 0.43, green: 0.30, blue: 0.20, alpha: 1)
        base.strokeColor = UIColor(red: 0.91, green: 0.77, blue: 0.48, alpha: 1)
        base.lineWidth = 2
        base.name = root.name
        root.addChild(base)

        let tent = SKShapeNode()
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -38, y: 0))
        path.addLine(to: CGPoint(x: 0, y: 58))
        path.addLine(to: CGPoint(x: 38, y: 0))
        path.closeSubpath()
        tent.path = path
        tent.fillColor = UIColor(red: 0.18, green: 0.16, blue: 0.13, alpha: 1)
        tent.strokeColor = UIColor(red: 0.80, green: 0.40, blue: 0.22, alpha: 1)
        tent.lineWidth = 3
        tent.name = root.name
        root.addChild(tent)

        let trim = SKShapeNode(rectOf: CGSize(width: 54, height: 6), cornerRadius: 2)
        trim.fillColor = UIColor(red: 0.82, green: 0.18, blue: 0.11, alpha: 1)
        trim.strokeColor = .clear
        trim.position = CGPoint(x: 0, y: 8)
        trim.name = root.name
        root.addChild(trim)

        let flag = SKShapeNode(rectOf: CGSize(width: 24, height: 18), cornerRadius: 2)
        flag.fillColor = UIColor(red: 0.08, green: 0.50, blue: 0.20, alpha: 1)
        flag.strokeColor = .white
        flag.lineWidth = 1
        flag.position = CGPoint(x: 40, y: 48)
        flag.name = root.name
        root.addChild(flag)
    }

    private func addCommunity(to root: SKNode, building: DTPlacedBuilding) {
        let base = SKShapeNode(path: diamondPath(width: tileWidth * 1.25, height: tileHeight * 1.25))
        base.fillColor = UIColor(red: 0.70, green: 0.62, blue: 0.47, alpha: 1)
        base.strokeColor = UIColor(red: 0.92, green: 0.80, blue: 0.55, alpha: 1)
        base.lineWidth = 2
        base.name = root.name
        root.addChild(base)

        let icon = iconSprite(for: "Community", fallbackSize: CGSize(width: 42, height: 42))
        icon.position = CGPoint(x: 0, y: 34)
        icon.size = CGSize(width: 42, height: 42)
        icon.name = root.name
        root.addChild(icon)
    }

    private func addGenericBuilding(to root: SKNode, building: DTPlacedBuilding) {
        let base = SKShapeNode(path: diamondPath(width: tileWidth, height: tileHeight))
        base.fillColor = UIColor(red: 0.50, green: 0.40, blue: 0.28, alpha: 1)
        base.strokeColor = UIColor(red: 0.87, green: 0.72, blue: 0.46, alpha: 1)
        base.lineWidth = 2
        base.name = root.name
        root.addChild(base)
    }

    private func addStatus(for building: DTPlacedBuilding, to root: SKNode) {
        if let finishAt = building.finishAt, ["growing", "delivering", "constructing"].contains(building.state) {
            let total = duration(for: building)
            let remaining = max(0, finishAt - Date().timeIntervalSince1970)
            let progress = total > 0 ? CGFloat(1 - min(1, remaining / total)) : 1
            addProgressBar(to: root, progress: progress)
        }

        let bubbleFrame: String?
        let statusText: String?
        switch building.state {
        case "empty":
            bubbleFrame = "status_baloons/Farming_Bubble.png"
            statusText = nil
        case "readyCrop":
            bubbleFrame = "status_baloons/Goods_Bubble.png"
            statusText = "احصد"
        case "needsNeighbor":
            bubbleFrame = "status_baloons/House_Visit_Bubble.png"
            statusText = nil
        case "needsWorker":
            bubbleFrame = "status_baloons/hireworker_bubble.png"
            statusText = "عامل"
        case "needsGoods":
            bubbleFrame = "status_baloons/GoodsRequired_Bubble.png"
            statusText = "زوّد"
        case "readyBusiness":
            bubbleFrame = "status_baloons/Coin_Bubble.png"
            statusText = "استلم"
        default:
            bubbleFrame = nil
            statusText = nil
        }

        if let bubbleFrame {
            let bubble = sprite(from: balloonAtlas, frameName: bubbleFrame, fallbackSize: CGSize(width: 54, height: 44))
            bubble.position = CGPoint(x: 18, y: 88)
            bubble.size = CGSize(width: 56, height: 46)
            bubble.zPosition = 50
            bubble.name = root.name
            root.addChild(bubble)
        }

        if let statusText {
            let label = strokedLabel(statusText, size: 14)
            label.position = CGPoint(x: 0, y: 72)
            label.name = root.name
            root.addChild(label)
        }
    }

    private func addProgressBar(to root: SKNode, progress: CGFloat) {
        let empty = sprite(from: gameAtlas, frameName: "main_screen_ui/action_progress_bar/action_progress_bar_empty.png", fallbackSize: CGSize(width: 58, height: 10))
        empty.position = CGPoint(x: 0, y: 64)
        empty.size = CGSize(width: 58, height: 10)
        empty.zPosition = 40
        empty.name = root.name
        root.addChild(empty)

        let full = sprite(from: gameAtlas, frameName: "main_screen_ui/action_progress_bar/action_progress_bar_full.png", fallbackSize: CGSize(width: 58, height: 10))
        full.anchorPoint = CGPoint(x: 0, y: 0.5)
        full.position = CGPoint(x: -29, y: 64)
        full.size = CGSize(width: 58 * max(0.04, progress), height: 10)
        full.zPosition = 41
        full.name = root.name
        root.addChild(full)
    }

    private func duration(for building: DTPlacedBuilding) -> TimeInterval {
        if building.category == "Farming", let cropID = building.cropID {
            return data.crop(id: cropID)?.growSeconds ?? 30
        }
        return data.item(id: building.definitionID)?.workSeconds ?? 30
    }

    private func layoutHUD() {
        hudNode.removeAllChildren()

        if let texture = gameAtlas?.texture(named: "main_screen_ui/bottom_bar/bottom_bar.png") {
            let bar = SKSpriteNode(texture: texture)
            bar.size = CGSize(width: max(460, size.width - 180), height: 88)
            bar.position = CGPoint(x: 0, y: -size.height / 2 + 42)
            bar.alpha = 0.98
            bar.zPosition = 900
            hudNode.addChild(bar)
        }

        let goals = sprite(from: gameAtlas, frameName: "main_screen_ui/goals_menu/goals_button.png", fallbackSize: CGSize(width: 90, height: 74))
        goals.position = CGPoint(x: -size.width / 2 + 58, y: -size.height / 2 + 48)
        goals.size = CGSize(width: 94, height: 74)
        goals.zPosition = 1000
        goals.name = "hud:goals"
        hudNode.addChild(goals)
        addBadge(text: "\(max(0, data.spec.goals.count - state.activeGoalIndex))", at: CGPoint(x: -size.width / 2 + 90, y: -size.height / 2 + 82), to: hudNode)

        let menu = sprite(from: gameAtlas, frameName: "main_screen_ui/right_menu/menu_button.png", fallbackSize: CGSize(width: 90, height: 74))
        menu.position = CGPoint(x: size.width / 2 - 58, y: -size.height / 2 + 48)
        menu.size = CGSize(width: 94, height: 74)
        menu.zPosition = 1000
        menu.name = "hud:menu"
        hudNode.addChild(menu)

        let levelBadge = SKShapeNode(circleOfRadius: 28)
        levelBadge.fillColor = UIColor(red: 0.20, green: 0.30, blue: 0.34, alpha: 1)
        levelBadge.strokeColor = UIColor(red: 0.71, green: 0.84, blue: 0.27, alpha: 1)
        levelBadge.lineWidth = 5
        levelBadge.position = CGPoint(x: -size.width / 2 + 158, y: -size.height / 2 + 74)
        levelBadge.zPosition = 1000
        hudNode.addChild(levelBadge)
        let levelText = label("\(state.level)", size: 23, color: .white, alignment: .center)
        levelText.position = levelBadge.position.applying(CGAffineTransform(translationX: 0, y: -8))
        levelText.zPosition = 1001
        hudNode.addChild(levelText)

        let y = -size.height / 2 + 48
        resourceGroup(icon: "main_screen_ui/bottom_bar/energy_symbol.png", text: "\(state.energy)", x: -size.width / 2 + 248, y: y, width: 86)
        resourceGroup(icon: "main_screen_ui/bottom_bar/goods_symbol.png", text: "\(state.goods)/\(state.goodsCapacity)", x: -size.width / 2 + 368, y: y, width: 118)
        resourceGroup(icon: "main_screen_ui/bottom_bar/coins_symbol.png", text: "\(state.coins)", x: size.width / 2 - 310, y: y, width: 130)
        resourceGroup(icon: "main_screen_ui/bottom_bar/dinars_symbol.png", text: "\(state.cash)", x: size.width / 2 - 168, y: y, width: 108)
        resourceGroup(icon: "souk_screen/icon_population.png", text: "\(max(0, state.availableWorkers - state.assignedWorkers))", x: size.width / 2 - 260, y: y + 66, width: 104, atlas: soukAtlas)

        addTutorialBanner()
        addTutorialControls()
        addDebugTouchTargets()
    }

    private func resourceGroup(icon: String, text: String, x: CGFloat, y: CGFloat, width: CGFloat, atlas: CocosTextureAtlas? = nil) {
        let panel = SKShapeNode(rectOf: CGSize(width: width, height: 38), cornerRadius: 6)
        panel.fillColor = UIColor(red: 0.18, green: 0.10, blue: 0.07, alpha: 0.78)
        panel.strokeColor = UIColor(red: 0.76, green: 0.57, blue: 0.31, alpha: 1)
        panel.lineWidth = 2
        panel.position = CGPoint(x: x, y: y)
        panel.zPosition = 1000
        hudNode.addChild(panel)

        let iconSprite = sprite(from: atlas ?? gameAtlas, frameName: icon, fallbackSize: CGSize(width: 28, height: 28))
        iconSprite.size = CGSize(width: 30, height: 30)
        iconSprite.position = CGPoint(x: x - width / 2 + 21, y: y + 1)
        iconSprite.zPosition = 1001
        hudNode.addChild(iconSprite)

        let value = label(text, size: 19, color: .white, alignment: .right)
        value.position = CGPoint(x: x + width / 2 - 14, y: y - 7)
        value.zPosition = 1001
        hudNode.addChild(value)

        let plus = label("+", size: 30, color: UIColor(red: 0.45, green: 0.94, blue: 0.20, alpha: 1), alignment: .center)
        plus.position = CGPoint(x: x + width / 2 + 18, y: y - 12)
        plus.name = "hud:menu"
        plus.zPosition = 1001
        hudNode.addChild(plus)
    }

    private func addTutorialBanner() {
        guard !tutorialText.isEmpty else { return }
        let bannerWidth = min(size.width - 190, 650)
        let banner = SKShapeNode(rectOf: CGSize(width: bannerWidth, height: 54), cornerRadius: 8)
        banner.fillColor = UIColor(red: 0.17, green: 0.10, blue: 0.07, alpha: 0.88)
        banner.strokeColor = UIColor(red: 0.82, green: 0.65, blue: 0.40, alpha: 1)
        banner.lineWidth = 2
        banner.position = CGPoint(x: 18, y: size.height / 2 - 42)
        banner.zPosition = 1000
        hudNode.addChild(banner)

        let text = label(tutorialText, size: 15, color: .white, alignment: .center)
        text.position = CGPoint(x: banner.position.x, y: banner.position.y - 7)
        text.preferredMaxLayoutWidth = bannerWidth - 32
        text.numberOfLines = 2
        text.zPosition = 1001
        hudNode.addChild(text)
    }

    private func addTutorialControls() {
        guard !tutorialText.isEmpty else { return }

        let skip = sprite(from: gameAtlas, frameName: "tutorial/skip_tutorial_button.png", fallbackSize: CGSize(width: 74, height: 44))
        skip.position = CGPoint(x: -size.width / 2 + 56, y: size.height / 2 - 34)
        skip.size = CGSize(width: 74, height: 44)
        skip.name = "tutorial:skip"
        skip.zPosition = 1100
        hudNode.addChild(skip)

        let cue: (position: CGPoint, rotation: CGFloat)?
        if !state.completedEvents.contains("assign_neighbor:starting_tent") {
            cue = (CGPoint(x: -size.width / 2 + 82, y: -size.height / 2 + 124), -.pi / 2)
        } else if activeGoal()?.steps.contains(where: { $0.type == "build" }) == true {
            cue = (CGPoint(x: size.width / 2 - 118, y: -size.height / 2 + 62), 0)
        } else {
            cue = nil
        }

        if let cue {
            addTutorialArrow(to: hudNode, at: cue.position, rotation: cue.rotation, size: CGSize(width: 64, height: 48))
        }
    }

    private func addTutorialArrow(to parent: SKNode, at position: CGPoint, rotation: CGFloat = 0, size: CGSize = CGSize(width: 58, height: 44)) {
        let arrow = sprite(from: gameAtlas, frameName: "tutorial/red_arrow.png", fallbackSize: size)
        arrow.position = position
        arrow.size = size
        arrow.zRotation = rotation
        arrow.zPosition = 1200
        parent.addChild(arrow)
        let dx: CGFloat = abs(rotation) < 0.1 ? 8 : 0
        let dy: CGFloat = abs(rotation) < 0.1 ? 0 : (rotation > 0 ? 8 : -8)
        arrow.run(.repeatForever(.sequence([
            .moveBy(x: dx, y: dy, duration: 0.45),
            .moveBy(x: -dx, y: -dy, duration: 0.45)
        ])))
    }

    private func addDebugTouchTargets() {
        addInvisibleHUDZone(name: "debug:coins", rect: CGRect(x: size.width / 2 - 96, y: size.height / 2 - 78, width: 40, height: 40))
        addInvisibleHUDZone(name: "debug:speed", rect: CGRect(x: size.width / 2 - 52, y: size.height / 2 - 78, width: 40, height: 40))
        addInvisibleHUDZone(name: "debug:reset", rect: CGRect(x: size.width / 2 - 8, y: size.height / 2 - 78, width: 40, height: 40))
    }

    private func addInvisibleHUDZone(name: String, rect: CGRect) {
        let node = SKShapeNode(rect: rect)
        node.fillColor = UIColor(white: 1, alpha: 0.01)
        node.strokeColor = .clear
        node.name = name
        node.zPosition = 1100
        hudNode.addChild(node)
    }

    private func addBadge(text: String, at position: CGPoint, to node: SKNode) {
        let badge = SKShapeNode(circleOfRadius: 18)
        badge.fillColor = UIColor(red: 0.88, green: 0.12, blue: 0.05, alpha: 1)
        badge.strokeColor = .white
        badge.lineWidth = 2
        badge.position = position
        badge.zPosition = 1100
        node.addChild(badge)

        let value = label(text, size: 18, color: .white, alignment: .center)
        value.position = CGPoint(x: position.x, y: position.y - 7)
        value.zPosition = 1101
        node.addChild(value)
    }

    private func layoutOverlay() {
        overlayNode.position = .zero
    }

    private func presentGoals() {
        guard let goal = activeGoal() else {
            presentMessage(title: "المهام", message: "تم إكمال جميع المهام الحالية.")
            return
        }

        let rows = goal.steps.map { step -> (String, Bool) in
            (step.label ?? step.eventKey, state.completedEvents.contains(step.eventKey))
        }
        presentGoalPanel(title: goal.title, rows: rows)
    }

    private func presentGoalPanel(title: String, rows: [(String, Bool)]) {
        closeOverlay()
        addDimOverlay(name: "dialog:close")

        let panel = panelNode(size: CGSize(width: 560, height: 350), title: title)
        panel.position = .zero
        overlayNode.addChild(panel)

        var y: CGFloat = 68
        for row in rows {
            let task = SKShapeNode(rectOf: CGSize(width: 330, height: 48), cornerRadius: 6)
            task.fillColor = UIColor(red: 0.93, green: 0.82, blue: 0.58, alpha: 1)
            task.strokeColor = UIColor(red: 0.58, green: 0.32, blue: 0.18, alpha: 1)
            task.lineWidth = 2
            task.position = CGPoint(x: -28, y: y)
            panel.addChild(task)

            let taskLabel = label(row.0, size: 15, color: UIColor(red: 0.32, green: 0.18, blue: 0.10, alpha: 1), alignment: .center)
            taskLabel.position = CGPoint(x: -28, y: y - 6)
            taskLabel.preferredMaxLayoutWidth = 300
            taskLabel.numberOfLines = 2
            panel.addChild(taskLabel)

            let status = label(row.1 ? "مكتملة" : "غير مكتملة", size: 14, color: .white, alignment: .center)
            let statusBg = SKShapeNode(rectOf: CGSize(width: 128, height: 28), cornerRadius: 3)
            statusBg.fillColor = row.1 ? UIColor(red: 0.18, green: 0.55, blue: 0.20, alpha: 1) : UIColor(red: 0.74, green: 0.10, blue: 0.10, alpha: 1)
            statusBg.strokeColor = .clear
            statusBg.position = CGPoint(x: -28, y: y - 36)
            panel.addChild(statusBg)
            status.position = CGPoint(x: -28, y: y - 43)
            panel.addChild(status)
            y -= 88
        }

        let guide = sprite(from: charactersAtlas, frameName: "characters/arab.png", fallbackSize: CGSize(width: 100, height: 150))
        guide.position = CGPoint(x: 226, y: 22)
        guide.size = CGSize(width: 108, height: 156)
        panel.addChild(guide)

        addButton(text: "حسنًا", name: "goal:ok", position: CGPoint(x: 0, y: -142), to: panel, width: 130)
        if !state.completedEvents.contains("assign_neighbor:starting_tent") {
            addTutorialArrow(to: panel, at: CGPoint(x: 112, y: -142), rotation: 0, size: CGSize(width: 54, height: 40))
        }
    }

    private func presentSouk(category: String? = nil) {
        if let category {
            selectedSoukCategory = category
        } else if let suggested = suggestedSoukCategoryForActiveGoal() {
            selectedSoukCategory = suggested
        }

        closeOverlay()
        addDimOverlay(name: "dialog:close")

        let panelSize = CGSize(width: min(760, size.width - 58), height: min(430, size.height - 58))
        let panel = panelNode(size: panelSize, title: "السوق")
        overlayNode.addChild(panel)

        addButton(text: "X", name: "dialog:close", position: CGPoint(x: panelSize.width / 2 - 36, y: panelSize.height / 2 - 36), to: panel, width: 42, height: 38, red: true)

        let topY = panelSize.height / 2 - 52
        resourceHeader(text: "\(state.coins)", icon: "main_screen_ui/bottom_bar/coins_symbol.png", x: -90, y: topY, to: panel)
        resourceHeader(text: "\(state.cash)", icon: "main_screen_ui/bottom_bar/dinars_symbol.png", x: 90, y: topY, to: panel)
        resourceHeader(text: "\(max(0, state.availableWorkers - state.assignedWorkers))", icon: "souk_screen/icon_population.png", x: 255, y: topY, to: panel, atlas: soukAtlas)

        let leftX = -panelSize.width / 2 + 112
        let startY = panelSize.height / 2 - 105
        let categories = data.spec.storeCategories
        for (index, categoryName) in categories.enumerated() {
            let rowY = startY - CGFloat(index) * 40
            let selected = categoryName == selectedSoukCategory
            let tab = SKShapeNode(rectOf: CGSize(width: 176, height: 36), cornerRadius: 6)
            tab.fillColor = selected ? UIColor(red: 0.10, green: 0.47, blue: 0.57, alpha: 1) : UIColor(red: 0.79, green: 0.66, blue: 0.44, alpha: 1)
            tab.strokeColor = UIColor(red: 0.42, green: 0.22, blue: 0.12, alpha: 1)
            tab.lineWidth = 2
            tab.position = CGPoint(x: leftX, y: rowY)
            tab.name = "souk:category:\(categoryName)"
            panel.addChild(tab)

            let categoryLabel = label(arabicCategoryName(categoryName), size: 17, color: selected ? .white : UIColor(red: 0.23, green: 0.12, blue: 0.07, alpha: 1), alignment: .center)
            categoryLabel.position = CGPoint(x: leftX + 18, y: rowY - 7)
            categoryLabel.name = tab.name
            panel.addChild(categoryLabel)
            let icon = iconSprite(for: categoryName, fallbackSize: CGSize(width: 26, height: 26))
            icon.position = CGPoint(x: leftX - 62, y: rowY)
            icon.size = CGSize(width: 26, height: 26)
            icon.name = tab.name
            panel.addChild(icon)
        }

        let content = SKShapeNode(rectOf: CGSize(width: panelSize.width - 250, height: panelSize.height - 140), cornerRadius: 8)
        content.fillColor = UIColor(red: 0.42, green: 0.18, blue: 0.50, alpha: 1)
        content.strokeColor = UIColor(red: 0.95, green: 0.79, blue: 0.45, alpha: 1)
        content.lineWidth = 3
        content.position = CGPoint(x: 104, y: -26)
        panel.addChild(content)

        let title = label(arabicCategoryName(selectedSoukCategory), size: 27, color: .white, alignment: .center)
        title.position = CGPoint(x: 104, y: panelSize.height / 2 - 126)
        panel.addChild(title)

        let availableWorkers = max(0, state.availableWorkers - state.assignedWorkers)
        if selectedSoukCategory == "Business" && availableWorkers == 0 {
            let guide = sprite(from: characters2Atlas, frameName: "characters/camel_falcon.png", fallbackSize: CGSize(width: 132, height: 132))
            guide.position = CGPoint(x: 16, y: -26)
            guide.size = CGSize(width: 132, height: 132)
            panel.addChild(guide)

            let bubble = SKShapeNode(rectOf: CGSize(width: 286, height: 152), cornerRadius: 14)
            bubble.fillColor = UIColor(red: 0.94, green: 0.84, blue: 0.58, alpha: 1)
            bubble.strokeColor = UIColor(red: 0.62, green: 0.38, blue: 0.19, alpha: 1)
            bubble.lineWidth = 2
            bubble.position = CGPoint(x: 188, y: -24)
            panel.addChild(bubble)

            let hint = label("المحال تحتاج إلى عمال.\nزد عدد السكان ببناء المساكن.", size: 19, color: UIColor(red: 0.28, green: 0.15, blue: 0.08, alpha: 1), alignment: .center)
            hint.position = CGPoint(x: 188, y: -32)
            hint.preferredMaxLayoutWidth = 240
            hint.numberOfLines = 3
            panel.addChild(hint)
            return
        }

        let items = data.items(in: selectedSoukCategory, level: state.level)
        let cardWidth: CGFloat = 132
        let cardHeight: CGFloat = 132
        let columns = 3
        let startX = content.position.x - 150
        let startCardY = content.position.y + 62

        for (index, item) in items.prefix(6).enumerated() {
            let column = index % columns
            let row = index / columns
            let cardPosition = CGPoint(x: startX + CGFloat(column) * 150, y: startCardY - CGFloat(row) * 150)
            addStoreCard(item: item, position: cardPosition, size: CGSize(width: cardWidth, height: cardHeight), to: panel)
        }
    }

    private func suggestedSoukCategoryForActiveGoal() -> String? {
        guard let goal = activeGoal() else { return nil }
        for step in goal.steps where !state.completedEvents.contains(step.eventKey) {
            if let item = data.item(id: step.target) {
                return item.category
            }
        }
        return nil
    }

    private func resourceHeader(text: String, icon: String, x: CGFloat, y: CGFloat, to panel: SKNode, atlas: CocosTextureAtlas? = nil) {
        let box = SKShapeNode(rectOf: CGSize(width: 124, height: 36), cornerRadius: 5)
        box.fillColor = UIColor(red: 0.18, green: 0.10, blue: 0.07, alpha: 0.78)
        box.strokeColor = UIColor(red: 0.76, green: 0.57, blue: 0.31, alpha: 1)
        box.position = CGPoint(x: x, y: y)
        panel.addChild(box)
        let iconNode = sprite(from: atlas ?? gameAtlas, frameName: icon, fallbackSize: CGSize(width: 28, height: 28))
        iconNode.position = CGPoint(x: x - 42, y: y)
        iconNode.size = CGSize(width: 28, height: 28)
        panel.addChild(iconNode)
        let value = label(text, size: 17, color: .white, alignment: .right)
        value.position = CGPoint(x: x + 48, y: y - 7)
        panel.addChild(value)
    }

    private func addStoreCard(item: DTStoreItem, position: CGPoint, size: CGSize, to panel: SKNode) {
        let locked = item.isLocked(at: state.level)
        let actionName = "souk:buy:\(item.id)"
        let card = sprite(from: soukAtlas, frameName: "souk_screen/souk_item_frame.png", fallbackSize: size)
        card.size = size
        card.position = position
        card.alpha = locked ? 0.58 : 1
        card.name = actionName
        panel.addChild(card)

        let itemName = label(item.name, size: 13, color: UIColor(red: 0.23, green: 0.12, blue: 0.07, alpha: 1), alignment: .center)
        itemName.position = CGPoint(x: position.x, y: position.y + size.height / 2 - 24)
        itemName.preferredMaxLayoutWidth = size.width - 12
        itemName.numberOfLines = 2
        itemName.name = actionName
        panel.addChild(itemName)

        let icon = storeIconSprite(for: item, fallbackSize: CGSize(width: 54, height: 54))
        icon.position = CGPoint(x: position.x, y: position.y + 20)
        icon.size = CGSize(width: 54, height: 54)
        icon.name = actionName
        panel.addChild(icon)

        if locked {
            let lock = label("يتطلب\nالمستوى \(item.unlockLevel)", size: 16, color: .yellow, alignment: .center)
            lock.position = CGPoint(x: position.x, y: position.y - 6)
            lock.numberOfLines = 2
            lock.name = actionName
            panel.addChild(lock)
        } else {
            if let detail = storeDetailText(for: item) {
                let detailLabel = label(detail, size: 10, color: UIColor(red: 0.28, green: 0.15, blue: 0.08, alpha: 1), alignment: .center)
                detailLabel.position = CGPoint(x: position.x, y: position.y - 26)
                detailLabel.preferredMaxLayoutWidth = size.width - 14
                detailLabel.numberOfLines = 2
                detailLabel.name = actionName
                panel.addChild(detailLabel)
            }

            let costText = item.cashCost > 0 ? "\(item.cashCost)" : "\(item.coinCost)"
            let buy = sprite(from: soukAtlas, frameName: "souk_screen/souk_item_button.png", fallbackSize: CGSize(width: 96, height: 30))
            buy.size = CGSize(width: 96, height: 30)
            buy.position = CGPoint(x: position.x, y: position.y - size.height / 2 + 22)
            buy.name = actionName
            panel.addChild(buy)

            let cost = label(costText, size: 17, color: .white, alignment: .center)
            cost.position = CGPoint(x: position.x + 10, y: buy.position.y - 7)
            cost.name = actionName
            panel.addChild(cost)

            let iconFrame = item.cashCost > 0 ? "main_screen_ui/bottom_bar/dinars_symbol.png" : "main_screen_ui/bottom_bar/coins_symbol.png"
            let coin = sprite(from: gameAtlas, frameName: iconFrame, fallbackSize: CGSize(width: 18, height: 18))
            coin.position = CGPoint(x: position.x - 30, y: buy.position.y)
            coin.size = CGSize(width: 20, height: 20)
            coin.name = actionName
            panel.addChild(coin)
        }

        if shouldPointAtStoreItem(item) {
            addTutorialArrow(to: panel, at: CGPoint(x: position.x - 82, y: position.y + 12), rotation: 0, size: CGSize(width: 54, height: 40))
        }
    }

    private func storeDetailText(for item: DTStoreItem) -> String? {
        switch item.category {
        case "Business":
            return "\(item.requiredWorkers) عامل  \(item.goodsRequired) بضائع\n+\(item.rewardCoins) عملات +\(item.rewardPoints) نقطة"
        case "Housing":
            return item.populationBonus > 0 ? "+\(item.populationBonus) سكان" : nil
        case "Farming":
            if item.id.contains("silo") || item.goodsCapacityBonus > 0 {
                return "+\(item.goodsCapacityBonus) سعة بضائع"
            }
            return "ازرع المحاصيل هنا"
        case "Community":
            return item.workSeconds > 0 ? "ينتهي خلال \(shortTime(item.workSeconds))" : nil
        case "Expansion":
            return "افتح أرضًا جديدة"
        default:
            return nil
        }
    }

    private func storeIconSprite(for item: DTStoreItem, fallbackSize: CGSize) -> SKSpriteNode {
        switch item.id {
        case "reward_video":
            return sprite(from: soukAtlas, frameName: "souk_screen/products/Video1.png", fallbackSize: fallbackSize)
        case "coins_5000":
            return sprite(from: soukAtlas, frameName: "souk_screen/products/5000_coins.png", fallbackSize: fallbackSize)
        case "dinars_10":
            return sprite(from: soukAtlas, frameName: "souk_screen/products/10_dinars.png", fallbackSize: fallbackSize)
        default:
            return iconSprite(for: item.category, fallbackSize: fallbackSize)
        }
    }

    private func shouldPointAtStoreItem(_ item: DTStoreItem) -> Bool {
        guard let goal = activeGoal() else { return false }
        return goal.steps.contains { step in
            step.target == item.id && !state.completedEvents.contains(step.eventKey)
        }
    }

    private func presentCropDialog(for farmID: String) {
        closeOverlay()
        addDimOverlay(name: "dialog:close")

        let panel = panelNode(size: CGSize(width: 520, height: 360), title: "ازرع محصولًا")
        overlayNode.addChild(panel)
        let subtitle = label("ازرع، انتظر، ثم احصد بضائعك.", size: 16, color: .white, alignment: .center)
        subtitle.position = CGPoint(x: 0, y: 110)
        panel.addChild(subtitle)

        for (index, crop) in data.spec.crops.enumerated() {
            let column = index % 2
            let row = index / 2
            let pos = CGPoint(x: -116 + CGFloat(column) * 232, y: 38 - CGFloat(row) * 122)
            addCropCard(crop: crop, farmID: farmID, position: pos, to: panel)
        }

        addButton(text: "إغلاق", name: "dialog:close", position: CGPoint(x: 0, y: -146), to: panel, width: 130)
    }

    private func addCropCard(crop: DTCropDefinition, farmID: String, position: CGPoint, to panel: SKNode) {
        let locked = state.level < crop.unlockLevel
        let actionName = "crop:plant:\(crop.id):\(farmID)"
        let card = sprite(from: backgroundAtlas, frameName: "crop-selection_ui/crop_item_bg.png", fallbackSize: CGSize(width: 172, height: 98))
        card.size = CGSize(width: 172, height: 98)
        card.alpha = locked ? 0.58 : 1
        card.position = position
        card.name = actionName
        panel.addChild(card)

        let cropName = label(crop.name, size: 17, color: UIColor(red: 0.22, green: 0.12, blue: 0.07, alpha: 1), alignment: .center)
        cropName.position = CGPoint(x: position.x, y: position.y + 24)
        cropName.name = actionName
        panel.addChild(cropName)

        let detail = locked
            ? "يتطلب\nالمستوى \(crop.unlockLevel)"
            : "\(crop.coinCost) عملات  \(crop.yieldGoods) بضائع\nالحصاد خلال \(shortTime(crop.growSeconds))"
        let detailLabel = label(detail, size: locked ? 16 : 12, color: locked ? .yellow : UIColor(red: 0.22, green: 0.12, blue: 0.07, alpha: 1), alignment: .center)
        detailLabel.position = CGPoint(x: position.x, y: position.y - 28)
        detailLabel.numberOfLines = 2
        detailLabel.name = actionName
        panel.addChild(detailLabel)

        if shouldPointAtCrop(crop) {
            addTutorialArrow(to: panel, at: CGPoint(x: position.x - 106, y: position.y), rotation: 0, size: CGSize(width: 54, height: 40))
        }
    }

    private func shouldPointAtCrop(_ crop: DTCropDefinition) -> Bool {
        guard let goal = activeGoal() else { return false }
        return goal.steps.contains { step in
            step.target == crop.id && !state.completedEvents.contains(step.eventKey)
        }
    }

    private func shortTime(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        if total >= 60 {
            let minutes = total / 60
            return "\(minutes)m"
        }
        return "\(total)s"
    }

    private func presentNeighborPicker() {
        closeOverlay()
        addDimOverlay(name: "dialog:close")
        let panel = panelNode(size: CGSize(width: 540, height: 350), title: "اختر جارًا")
        overlayNode.addChild(panel)
        let subtitle = label("اخترت 1 من 1", size: 16, color: .white, alignment: .center)
        subtitle.position = CGPoint(x: 0, y: 102)
        panel.addChild(subtitle)

        let names = ["سنقور بن\nعبدالله", "ثامر بن\nفيصل", "رياض بن\nضرار", "موزة بنت\nغسان", "سارة بنت\nسليمان", "لولوة بنت\nعبدالعزيز"]
        for index in 0..<6 {
            let x = -160 + CGFloat(index % 3) * 160
            let y = 34 - CGFloat(index / 3) * 92
            let card = SKShapeNode(rectOf: CGSize(width: 92, height: 72), cornerRadius: 6)
            card.fillColor = UIColor(red: 0.86, green: 0.72, blue: 0.50, alpha: 1)
            card.strokeColor = index == 0 ? UIColor(red: 0.16, green: 0.62, blue: 0.18, alpha: 1) : UIColor(red: 0.48, green: 0.27, blue: 0.12, alpha: 1)
            card.lineWidth = index == 0 ? 4 : 2
            card.position = CGPoint(x: x, y: y)
            panel.addChild(card)

            let personSprite = residentSprite(index: index)
            personSprite.position = CGPoint(x: x, y: y + 4)
            personSprite.size = CGSize(width: 44, height: 52)
            panel.addChild(personSprite)

            if index == 0 {
                let check = sprite(from: workersAtlas, frameName: "workers_ui/resident_check.png", fallbackSize: CGSize(width: 34, height: 34))
                check.position = CGPoint(x: x - 34, y: y + 16)
                check.size = CGSize(width: 34, height: 34)
                panel.addChild(check)
            }

            let person = label(names[index], size: 10, color: .white, alignment: .center)
            person.position = CGPoint(x: x, y: y - 50)
            person.numberOfLines = 2
            panel.addChild(person)
        }

        let guide = sprite(from: charactersAtlas, frameName: "characters/arab.png", fallbackSize: CGSize(width: 88, height: 132))
        guide.position = CGPoint(x: 250, y: 20)
        guide.size = CGSize(width: 86, height: 128)
        panel.addChild(guide)

        addButton(text: "حسنًا", name: "neighbor:hire", position: CGPoint(x: 0, y: -142), to: panel, width: 120)
        addTutorialArrow(to: panel, at: CGPoint(x: 116, y: -142), rotation: 0, size: CGSize(width: 54, height: 40))
    }

    private func presentWorkerPicker(for buildingID: String) {
        closeOverlay()
        addDimOverlay(name: "dialog:close")
        let panel = panelNode(size: CGSize(width: 480, height: 300), title: "اختر عاملًا")
        overlayNode.addChild(panel)
        let available = max(0, state.availableWorkers - state.assignedWorkers)
        let subtitle = label("اخترت \(available > 0 ? 1 : 0) من 1", size: 16, color: .white, alignment: .center)
        subtitle.position = CGPoint(x: 0, y: 78)
        panel.addChild(subtitle)

        let card = SKShapeNode(rectOf: CGSize(width: 120, height: 92), cornerRadius: 8)
        card.fillColor = UIColor(red: 0.86, green: 0.72, blue: 0.50, alpha: available > 0 ? 1 : 0.55)
        card.strokeColor = UIColor(red: 0.84, green: 0.68, blue: 0.36, alpha: 1)
        card.position = CGPoint(x: 0, y: 8)
        panel.addChild(card)

        let worker = residentSprite(index: 0)
        worker.position = CGPoint(x: 0, y: 20)
        worker.size = CGSize(width: 50, height: 60)
        worker.alpha = available > 0 ? 1 : 0.45
        panel.addChild(worker)

        let workerText = label(available > 0 ? "سنقور بن\nعبدالله" : "لا يوجد عمال", size: 12, color: .white, alignment: .center)
        workerText.position = CGPoint(x: 0, y: -42)
        workerText.numberOfLines = 2
        panel.addChild(workerText)
        addButton(text: available > 0 ? "تعيين" : "إغلاق", name: available > 0 ? "worker:hire:\(buildingID)" : "dialog:close", position: CGPoint(x: 0, y: -112), to: panel, width: 124)
    }

    private func residentSprite(index: Int) -> SKSpriteNode {
        let frames = [
            "workers_ui/workers/resident_001_v1.png",
            "workers_ui/workers/resident_002_v1.png",
            "workers_ui/workers/resident_003_v1.png",
            "workers_ui/workers/woman_001_v1.png",
            "workers_ui/workers/woman_002_v1.png",
            "workers_ui/workers/woman_003_v1.png"
        ]
        return sprite(from: workersAtlas, frameName: frames[index % frames.count], fallbackSize: CGSize(width: 44, height: 52))
    }

    private func presentMessage(title: String, message: String) {
        closeOverlay()
        addDimOverlay(name: "dialog:close")
        let panel = panelNode(size: CGSize(width: 460, height: 260), title: title)
        overlayNode.addChild(panel)
        let body = label(message, size: 17, color: .white, alignment: .center)
        body.position = CGPoint(x: 0, y: 10)
        body.preferredMaxLayoutWidth = 380
        body.numberOfLines = 4
        panel.addChild(body)
        addButton(text: "حسنًا", name: "dialog:close", position: CGPoint(x: 0, y: -98), to: panel, width: 120)
    }

    private func presentGuideMessage(title: String, message: String, buttonTitle: String = "إغلاق") {
        closeOverlay()
        addDimOverlay(name: "dialog:close")

        let root = SKNode()
        root.zPosition = 3000
        overlayNode.addChild(root)

        let guide = sprite(from: characters2Atlas, frameName: "characters/camel_falcon.png", fallbackSize: CGSize(width: 150, height: 150))
        guide.position = CGPoint(x: -220, y: -12)
        guide.size = CGSize(width: 150, height: 150)
        root.addChild(guide)

        let bubble = SKShapeNode(rectOf: CGSize(width: 420, height: 184), cornerRadius: 18)
        bubble.fillColor = UIColor(red: 0.96, green: 0.87, blue: 0.62, alpha: 1)
        bubble.strokeColor = UIColor(red: 0.74, green: 0.51, blue: 0.25, alpha: 1)
        bubble.lineWidth = 3
        bubble.position = CGPoint(x: 70, y: 10)
        root.addChild(bubble)

        let titleLabel = label(title, size: 23, color: UIColor(red: 0.42, green: 0.18, blue: 0.10, alpha: 1), alignment: .center)
        titleLabel.position = CGPoint(x: 70, y: 62)
        root.addChild(titleLabel)

        let body = label(message, size: 18, color: UIColor(red: 0.32, green: 0.17, blue: 0.09, alpha: 1), alignment: .center)
        body.position = CGPoint(x: 70, y: 10)
        body.preferredMaxLayoutWidth = 340
        body.numberOfLines = 4
        root.addChild(body)

        addButton(text: buttonTitle, name: "dialog:close", position: CGPoint(x: 70, y: -94), to: root, width: 130)
    }

    private func presentGoalComplete(title: String, reward: DTReward?) {
        playSound(candidates: ["music_sound/GoalCompletion.mp3", "music_sound/LevelCompletion.mp3"])
        var rewardText = "أحسنت! تم إنجاز المهمة"
        if let coins = reward?.coins, coins > 0 {
            rewardText += "\n+\(coins) عملات"
        }
        if let points = reward?.points, points > 0 {
            rewardText += "\n+\(points) نقاط"
        }
        presentMessage(title: title, message: rewardText)
    }

    private func presentLevelUp(level: Int) {
        playSound(candidates: ["music_sound/LevelCompletion.mp3"])
        closeOverlay()
        addDimOverlay(name: "dialog:close")

        let panel = panelNode(size: CGSize(width: 620, height: 360), title: "")
        overlayNode.addChild(panel)

        let guide = sprite(from: charactersAtlas, frameName: "characters/arab_camel.png", fallbackSize: CGSize(width: 170, height: 160))
        guide.position = CGPoint(x: -190, y: 60)
        guide.size = CGSize(width: 176, height: 164)
        panel.addChild(guide)

        let ribbon = SKShapeNode(rectOf: CGSize(width: 310, height: 70), cornerRadius: 8)
        ribbon.fillColor = UIColor(red: 0.50, green: 0.14, blue: 0.48, alpha: 1)
        ribbon.strokeColor = UIColor(red: 0.95, green: 0.80, blue: 0.45, alpha: 1)
        ribbon.lineWidth = 3
        ribbon.position = CGPoint(x: 72, y: 66)
        panel.addChild(ribbon)

        let levelText = label("المستوى \(level)", size: 38, color: .white, alignment: .center)
        levelText.position = CGPoint(x: 72, y: 54)
        panel.addChild(levelText)

        let message = label("مبروك! لديك عناصر جديدة في السوق", size: 18, color: .white, alignment: .center)
        message.position = CGPoint(x: 72, y: -18)
        message.preferredMaxLayoutWidth = 470
        panel.addChild(message)

        if let unlocked = data.storeItems.first(where: { $0.unlockLevel == level }) {
            let icon = storeIconSprite(for: unlocked, fallbackSize: CGSize(width: 58, height: 58))
            icon.position = CGPoint(x: 72, y: -70)
            icon.size = CGSize(width: 58, height: 58)
            panel.addChild(icon)
        }

        addButton(text: "حسنًا", name: "dialog:close", position: CGPoint(x: 72, y: -140), to: panel, width: 130)
    }

    private func presentMockVideoReward() {
        closeOverlay()
        addDimOverlay(name: "dialog:close")
        let panel = panelNode(size: CGSize(width: 460, height: 260), title: "مكافأة الفيديو")
        overlayNode.addChild(panel)
        let text = label("تمت مشاهدة فيديو تجريبي.\n+1 دينار", size: 18, color: .white, alignment: .center)
        text.numberOfLines = 2
        text.position = CGPoint(x: 0, y: 18)
        panel.addChild(text)
        addButton(text: "استلام", name: "mock:videoReward", position: CGPoint(x: 0, y: -96), to: panel, width: 140)
    }

    private func panelNode(size: CGSize, title: String) -> SKNode {
        let root = SKNode()
        root.zPosition = 3000

        if let texture = backgroundAtlas?.texture(named: "dialogues_ui/friend_purchase_bg.png") {
            let frame = SKSpriteNode(texture: texture)
            frame.size = size
            frame.zPosition = -1
            root.addChild(frame)
        } else {
            let frame = SKShapeNode(rectOf: size, cornerRadius: 10)
            frame.fillColor = UIColor(red: 0.52, green: 0.24, blue: 0.10, alpha: 0.98)
            frame.strokeColor = UIColor(red: 0.95, green: 0.82, blue: 0.52, alpha: 1)
            frame.lineWidth = 5
            root.addChild(frame)

            let inner = SKShapeNode(rectOf: CGSize(width: size.width - 28, height: size.height - 28), cornerRadius: 8)
            inner.fillColor = UIColor(red: 0.45, green: 0.20, blue: 0.09, alpha: 0.78)
            inner.strokeColor = UIColor(red: 0.86, green: 0.68, blue: 0.38, alpha: 1)
            inner.lineWidth = 2
            root.addChild(inner)
        }

        let titleNode = label(title, size: 30, color: .white, alignment: .center)
        titleNode.position = CGPoint(x: 0, y: size.height / 2 - 48)
        root.addChild(titleNode)
        return root
    }

    private func addButton(text: String, name: String, position: CGPoint, to parent: SKNode, width: CGFloat, height: CGFloat = 48, red: Bool = false) {
        let button = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: 7)
        button.fillColor = red ? UIColor(red: 0.75, green: 0.08, blue: 0.06, alpha: 1) : UIColor(red: 0.18, green: 0.56, blue: 0.18, alpha: 1)
        button.strokeColor = UIColor(red: 0.94, green: 0.78, blue: 0.42, alpha: 1)
        button.lineWidth = 3
        button.position = position
        button.name = name
        button.zPosition = 20
        parent.addChild(button)

        let textNode = label(text, size: red ? 22 : 24, color: .white, alignment: .center)
        textNode.position = CGPoint(x: position.x, y: position.y - 9)
        textNode.name = name
        textNode.zPosition = 21
        parent.addChild(textNode)
    }

    private func addDimOverlay(name: String) {
        let blocker = SKShapeNode(rect: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height))
        blocker.fillColor = UIColor(white: 0, alpha: 0.58)
        blocker.strokeColor = .clear
        blocker.name = name
        blocker.zPosition = 2500
        overlayNode.addChild(blocker)
    }

    private func closeOverlay() {
        overlayNode.removeAllChildren()
    }

    private func layoutPlacementControls() {
        placementNode.removeAllChildren()
        guard let placement = activePlacement else { return }

        let message = SKShapeNode(rectOf: CGSize(width: 330, height: 48), cornerRadius: 8)
        message.fillColor = UIColor(red: 0.15, green: 0.09, blue: 0.06, alpha: 0.86)
        message.strokeColor = UIColor(red: 0.88, green: 0.72, blue: 0.42, alpha: 1)
        message.position = CGPoint(x: 0, y: size.height / 2 - 44)
        message.zPosition = 2200
        placementNode.addChild(message)
        let text = label("ضع \(placement.item.name)", size: 17, color: .white, alignment: .center)
        text.position = CGPoint(x: 0, y: size.height / 2 - 51)
        text.zPosition = 2201
        placementNode.addChild(text)

        addButton(text: "حسنًا", name: "placement:confirm", position: CGPoint(x: size.width / 2 - 84, y: size.height / 2 - 46), to: placementNode, width: 86, height: 42)
        addButton(text: "X", name: "placement:cancel", position: CGPoint(x: size.width / 2 - 174, y: size.height / 2 - 46), to: placementNode, width: 54, height: 42, red: true)
        renderPlacementGhost()
    }

    private func renderPlacementGhost() {
        effectLayer.childNode(withName: "placement-ghost")?.removeFromParent()
        guard let placement = activePlacement else { return }

        let root = SKNode()
        root.name = "placement-ghost"
        root.position = positionForTile(column: placement.column, row: placement.row)
        root.zPosition = 20_000

        let valid = isPlacementValid(column: placement.column, row: placement.row)
        let footprint = SKShapeNode(path: diamondPath(width: tileWidth * 1.3, height: tileHeight * 1.3))
        footprint.fillColor = valid ? UIColor(red: 0.05, green: 0.78, blue: 0.18, alpha: 0.36) : UIColor(red: 0.90, green: 0.06, blue: 0.03, alpha: 0.42)
        footprint.strokeColor = valid ? .green : .red
        footprint.lineWidth = 3
        root.addChild(footprint)

        let icon = iconSprite(for: placement.item.category, fallbackSize: CGSize(width: 54, height: 54))
        icon.size = CGSize(width: 54, height: 54)
        icon.position = CGPoint(x: 0, y: 34)
        icon.alpha = 0.88
        root.addChild(icon)
        effectLayer.addChild(root)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        if let action = actionName(at: location) {
            handleAction(action)
            return
        }

        handleWorldTap(at: location)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        let activeTouches = Array(event?.allTouches ?? touches)
        if activeTouches.count >= 2 {
            handlePinchZoom(activeTouches)
        } else if overlayNode.children.isEmpty, activePlacement == nil, let touch = touches.first {
            let currentLocation = touch.location(in: self)
            let previousLocation = touch.previousLocation(in: self)
            let delta = CGPoint(x: currentLocation.x - previousLocation.x, y: currentLocation.y - previousLocation.y)
            cameraNode.position.x -= delta.x * cameraNode.xScale
            cameraNode.position.y -= delta.y * cameraNode.yScale
            clampCamera()
        }
    }

    private func actionName(at location: CGPoint) -> String? {
        for node in nodes(at: location) {
            var current: SKNode? = node
            while let candidate = current {
                if let name = candidate.name,
                   name.hasPrefix("hud:")
                    || name.hasPrefix("debug:")
                    || name.hasPrefix("dialog:")
                    || name.hasPrefix("goal:")
                    || name.hasPrefix("neighbor:")
                    || name.hasPrefix("worker:")
                    || name.hasPrefix("tutorial:")
                    || name.hasPrefix("souk:")
                    || name.hasPrefix("crop:")
                    || name.hasPrefix("placement:")
                    || name.hasPrefix("mock:") {
                    return name
                }
                current = candidate.parent
            }
        }
        return nil
    }

    private func handleAction(_ action: String) {
        if action == "hud:goals" {
            presentGoals()
        } else if action == "hud:menu" {
            presentSouk()
        } else if action == "dialog:close" {
            closeOverlay()
        } else if action == "goal:ok" {
            handleGoalOK()
        } else if action == "neighbor:hire" {
            completeNeighborGoal()
        } else if action.hasPrefix("worker:hire:") {
            let id = String(action.dropFirst("worker:hire:".count))
            hireWorker(for: id)
        } else if action.hasPrefix("souk:category:") {
            let category = String(action.dropFirst("souk:category:".count))
            presentSouk(category: category)
        } else if action.hasPrefix("souk:buy:") {
            let id = String(action.dropFirst("souk:buy:".count))
            buyStoreItem(id: id)
        } else if action.hasPrefix("crop:plant:") {
            handleCropAction(action)
        } else if action == "placement:confirm" {
            confirmPlacement()
        } else if action == "placement:cancel" {
            activePlacement = nil
            effectLayer.childNode(withName: "placement-ghost")?.removeFromParent()
            layoutPlacementControls()
        } else if action == "mock:videoReward" {
            state.cash += 1
            closeOverlay()
            afterStateChange()
        } else if action == "debug:coins" {
            state.coins += 1000
            state.goods = min(state.goodsCapacity, state.goods + 100)
            state.cash += 10
            afterStateChange()
            presentMessage(title: "اختبار", message: "+1000 عملات، +100 بضائع، +10 دنانير")
        } else if action == "debug:speed" {
            state.timerSpeed = state.timerSpeed == 1 ? 10 : 1
            presentMessage(title: "اختبار", message: "سرعة المؤقت x\(Int(state.timerSpeed))")
            saveState()
        } else if action == "debug:reset" {
            resetSave()
        } else if action == "tutorial:skip" {
            tutorialText = ""
            layoutHUD()
            saveState()
        }
    }

    private func handleGoalOK() {
        guard let goal = activeGoal() else {
            closeOverlay()
            return
        }

        if goal.id == "move_visitor_into_tent" && !state.completedEvents.contains("assign_neighbor:starting_tent") {
            presentNeighborPicker()
        } else {
            closeOverlay()
        }
    }

    private func completeNeighborGoal() {
        if let index = state.buildings.firstIndex(where: { $0.id == "starting_tent" }) {
            state.buildings[index].state = "complete"
        }
        completeEvent("assign_neighbor:starting_tent")
        tutorialText = "افتح السوق، اشترِ أرض زراعة، ثم ازرع التمر."
        closeOverlay()
        renderBuildings()
        checkGoals()
        afterStateChange()
    }

    private func buyStoreItem(id: String) {
        guard let item = data.item(id: id) else { return }
        guard !item.isLocked(at: state.level) else {
            presentMessage(title: item.name, message: "يتطلب المستوى \(item.unlockLevel).")
            return
        }

        if item.kind == .mock {
            handleMockItem(item)
            return
        }

        activePlacement = DTPlacement(item: item, column: mapColumns / 2, row: mapRows / 2)
        closeOverlay()
        tutorialText = "اضغط على مربع مناسب، ثم اضغط حسنًا لوضع \(item.name)."
        layoutHUD()
        layoutPlacementControls()
    }

    private func handleMockItem(_ item: DTStoreItem) {
        switch item.id {
        case "reward_video":
            presentMockVideoReward()
        case "energy_5":
            spendCash(item.cashCost) {
                state.energy += 5
                presentMessage(title: "الطاقة", message: "+5 طاقة")
            }
        case "energy_10":
            spendCash(item.cashCost) {
                state.energy += 10
                presentMessage(title: "الطاقة", message: "+10 طاقة")
            }
        case "coins_5000":
            spendCash(item.cashCost) {
                state.coins += 5000
                presentMessage(title: "العملة", message: "+5000 عملات")
            }
        case "dinars_10":
            state.cash += 10
            presentMessage(title: "العملة", message: "شراء تجريبي: +10 دنانير")
            afterStateChange()
        default:
            presentMessage(title: item.name, message: "تم تنفيذ الإجراء التجريبي.")
        }
    }

    private func spendCash(_ amount: Int, action: () -> Void) {
        guard state.cash >= amount else {
            presentGuideMessage(title: "لا يوجد دنانير كافية", message: "لا تملك دنانير كافية لإتمام هذا الشراء.")
            return
        }
        state.cash -= amount
        action()
        afterStateChange()
    }

    private func handleCropAction(_ action: String) {
        let parts = action.split(separator: ":").map(String.init)
        guard parts.count == 4 else { return }
        plantCrop(parts[2], in: parts[3])
    }

    private func plantCrop(_ cropID: String, in farmID: String) {
        guard let crop = data.crop(id: cropID),
              let index = state.buildings.firstIndex(where: { $0.id == farmID }) else { return }

        guard state.level >= crop.unlockLevel else {
            presentMessage(title: crop.name, message: "يتطلب المستوى \(crop.unlockLevel).")
            return
        }

        guard state.coins >= crop.coinCost else {
            presentGuideMessage(title: "لا يوجد عملات كافية", message: "لا تملك عملات كافية لزراعة هذا المحصول.")
            return
        }

        state.coins -= crop.coinCost
        state.buildings[index].cropID = crop.id
        state.buildings[index].state = "growing"
        state.buildings[index].finishAt = Date().timeIntervalSince1970 + crop.growSeconds / max(1, state.timerSpeed)
        closeOverlay()
        tutorialText = "انتظر مؤقت المحصول، ثم اضغط فقاعة البضائع للحصاد."
        renderBuildings()
        afterStateChange()
    }

    private func hireWorker(for buildingID: String) {
        guard let index = state.buildings.firstIndex(where: { $0.id == buildingID }) else { return }
        guard state.availableWorkers - state.assignedWorkers > 0 else {
            presentGuideMessage(title: "لا يوجد عمال", message: "المحال تحتاج إلى عمال. زد السكان ببناء المساكن.")
            return
        }

        state.assignedWorkers += 1
        state.buildings[index].assignedWorkers += 1
        state.buildings[index].state = "needsGoods"
        closeOverlay()
        tutorialText = "اضغط على المحل وزوده بالبضائع."
        renderBuildings()
        afterStateChange()
    }

    private func confirmPlacement() {
        guard let placement = activePlacement else { return }
        guard isPlacementValid(column: placement.column, row: placement.row) else {
            presentMessage(title: "مكان غير مناسب", message: "اختر مربعًا فارغًا داخل القرية.")
            return
        }

        guard canAfford(placement.item) else {
            let title = placement.item.cashCost > state.cash ? "لا يوجد دنانير كافية" : "لا يوجد عملات كافية"
            let message = placement.item.cashCost > state.cash ? "لا تملك دنانير كافية لإتمام هذا الشراء." : "لا تملك عملات كافية لإتمام هذا الشراء."
            presentGuideMessage(title: title, message: message)
            return
        }

        spend(placement.item)
        let id = "\(placement.item.id)_\(Int(Date().timeIntervalSince1970 * 1000))"
        let stateName: String
        if placement.item.category == "Farming", placement.item.id == "farm_plot" {
            stateName = "empty"
        } else if placement.item.category == "Business" {
            stateName = placement.item.requiredWorkers > 0 ? "needsWorker" : "needsGoods"
        } else if placement.item.category == "Housing" {
            stateName = "complete"
        } else if placement.item.category == "Community", placement.item.id == "school" {
            stateName = "constructing"
        } else {
            stateName = "complete"
        }

        var building = DTPlacedBuilding(
            id: id,
            definitionID: placement.item.id,
            category: placement.item.category,
            column: placement.column,
            row: placement.row,
            state: stateName,
            cropID: nil,
            finishAt: nil,
            assignedWorkers: 0
        )

        if building.state == "constructing" {
            building.finishAt = Date().timeIntervalSince1970 + max(20, placement.item.workSeconds) / max(1, state.timerSpeed)
        }

        if placement.item.populationBonus > 0 {
            state.populationCapacity += placement.item.populationBonus
            state.availableWorkers += placement.item.populationBonus
        }
        if placement.item.goodsCapacityBonus > 0 {
            state.goodsCapacity += placement.item.goodsCapacityBonus
        }

        state.buildings.append(building)
        activePlacement = nil
        effectLayer.childNode(withName: "placement-ghost")?.removeFromParent()
        completeEvent("build:\(placement.item.id)")
        tutorialText = tutorialAfterPlacing(placement.item)
        renderBuildings()
        layoutPlacementControls()
        playSound(candidates: ["music_sound/EnergyPack.mp3"])
        afterStateChange()

        if building.category == "Farming", building.definitionID == "farm_plot" {
            presentCropDialog(for: id)
        } else if building.category == "Business", building.state == "needsWorker" {
            presentWorkerPicker(for: id)
        }
    }

    private func tutorialAfterPlacing(_ item: DTStoreItem) -> String {
        switch item.category {
        case "Farming":
            return "اضغط أرض الزراعة لزراعة محصول."
        case "Business":
            return "عيّن عاملًا، زوّد المحل بالبضائع، ثم اجمع العملات."
        case "Housing":
            return "اضغط المسكن لإدخال زائر."
        default:
            return "واصل إكمال المهام لفتح عناصر أكثر."
        }
    }

    private func canAfford(_ item: DTStoreItem) -> Bool {
        state.coins >= item.coinCost && state.cash >= item.cashCost
    }

    private func spend(_ item: DTStoreItem) {
        state.coins -= item.coinCost
        state.cash -= item.cashCost
    }

    private func isPlacementValid(column: Int, row: Int) -> Bool {
        guard column >= 0, row >= 0, column < mapColumns, row < mapRows else { return false }
        guard !state.buildings.contains(where: { $0.column == column && $0.row == row }) else { return false }
        return true
    }

    private func handleWorldTap(at scenePoint: CGPoint) {
        if activePlacement != nil {
            let worldPoint = worldNode.convert(scenePoint, from: self)
            if let tile = tileCoordinate(for: worldPoint) {
                activePlacement?.column = tile.column
                activePlacement?.row = tile.row
                renderPlacementGhost()
            }
            return
        }

        if let buildingID = buildingID(at: scenePoint) {
            handleBuildingTap(id: buildingID)
        }
    }

    private func buildingID(at scenePoint: CGPoint) -> String? {
        for node in nodes(at: scenePoint) {
            var current: SKNode? = node
            while let candidate = current {
                if let name = candidate.name, name.hasPrefix("building:") {
                    return String(name.dropFirst("building:".count))
                }
                current = candidate.parent
            }
        }
        return nil
    }

    private func handleBuildingTap(id: String) {
        guard let index = state.buildings.firstIndex(where: { $0.id == id }) else { return }
        let building = state.buildings[index]

        switch building.state {
        case "needsNeighbor":
            presentNeighborPicker()
        case "empty":
            presentCropDialog(for: id)
        case "growing":
            presentMessage(title: "ينمو", message: "المحصول ما زال ينمو.")
        case "readyCrop":
            collectCrop(at: index)
        case "needsWorker":
            presentWorkerPicker(for: id)
        case "needsGoods":
            supplyBusiness(at: index)
        case "delivering":
            presentMessage(title: "قيد العمل", message: "المحل يجمع العملات.")
        case "readyBusiness":
            collectBusiness(at: index)
        default:
            if building.definitionID == "small_hut" {
                completeEvent("visit:small_hut")
                checkGoals()
            } else {
                showTapFeedback(at: positionForTile(column: building.column, row: building.row), color: .green)
            }
        }
    }

    private func collectCrop(at index: Int) {
        guard let cropID = state.buildings[index].cropID,
              let crop = data.crop(id: cropID) else { return }
        let availableCapacity = max(0, state.goodsCapacity - state.goods)
        guard availableCapacity > 0 else {
            presentGuideMessage(title: "المخزن ممتلئ", message: "ابنِ صومعة أو استخدم البضائع قبل الحصاد.")
            return
        }

        guard consumeEnergyIfPossible() else {
            presentGuideMessage(title: "لا توجد طاقة كافية", message: "تحتاج إلى طاقة لجمع البضائع وإنهاء الأفعال.")
            return
        }

        let gained = min(availableCapacity, crop.yieldGoods)
        state.goods += gained
        state.points += max(1, crop.yieldGoods / 10)
        state.buildings[index].state = "empty"
        state.buildings[index].cropID = nil
        state.buildings[index].finishAt = nil
        completeEvent("harvest_crop:\(cropID)")
        showReward(text: "-1 طاقة\n+\(gained) بضائع", at: positionForTile(column: state.buildings[index].column, row: state.buildings[index].row))
        renderBuildings()
        checkLevelUp()
        checkGoals()
        afterStateChange()
    }

    private func supplyBusiness(at index: Int) {
        guard let item = data.item(id: state.buildings[index].definitionID) else { return }
        guard state.goods >= item.goodsRequired else {
            presentGuideMessage(title: "لا توجد بضائع كافية", message: "لا تملك بضائع كافية لتزويد المحل! ازرع واحصد المحاصيل لزيادة البضائع.")
            return
        }

        state.goods -= item.goodsRequired
        state.buildings[index].state = "delivering"
        state.buildings[index].finishAt = Date().timeIntervalSince1970 + max(10, item.workSeconds) / max(1, state.timerSpeed)
        tutorialText = "انتظر فقاعة العملات، ثم اضغط المحل للاستلام."
        renderBuildings()
        afterStateChange()
    }

    private func collectBusiness(at index: Int) {
        guard let item = data.item(id: state.buildings[index].definitionID) else { return }
        guard consumeEnergyIfPossible() else {
            presentGuideMessage(title: "لا توجد طاقة كافية", message: "تحتاج إلى طاقة لجمع العملات من هذا المحل.")
            return
        }
        state.coins += item.rewardCoins
        state.points += item.rewardPoints
        state.buildings[index].state = "needsGoods"
        state.buildings[index].finishAt = nil
        completeEvent("collect_business:\(item.id)")
        showReward(text: "-1 طاقة\n+\(item.rewardCoins) عملات\n+\(item.rewardPoints) نقطة", at: positionForTile(column: state.buildings[index].column, row: state.buildings[index].row))
        renderBuildings()
        checkLevelUp()
        checkGoals()
        afterStateChange()
    }

    private func consumeEnergyIfPossible() -> Bool {
        guard state.energy > 0 else { return false }
        state.energy -= 1
        return true
    }

    private func activeGoal() -> DTGoalDefinition? {
        guard state.activeGoalIndex >= 0, state.activeGoalIndex < data.spec.goals.count else { return nil }
        return data.spec.goals[state.activeGoalIndex]
    }

    private func completeEvent(_ key: String) {
        state.completedEvents.insert(key)
    }

    private func checkGoals() {
        guard let goal = activeGoal() else { return }
        let complete = goal.steps.allSatisfy { state.completedEvents.contains($0.eventKey) }
        guard complete else { return }

        applyReward(goal.reward)
        state.activeGoalIndex += 1
        presentGoalComplete(title: goal.title, reward: goal.reward)
    }

    private func applyReward(_ reward: DTReward?) {
        guard let reward else { return }
        state.coins += reward.coins ?? 0
        state.cash += reward.cash ?? 0
        state.energy += reward.energy ?? 0
        state.goods = min(state.goodsCapacity, state.goods + (reward.goods ?? 0))
        state.points += reward.points ?? 0
        checkLevelUp()
    }

    private func checkLevelUp() {
        let nextLevel = data.level(for: state.points)
        guard nextLevel > state.level else { return }
        state.level = nextLevel
        presentLevelUp(level: nextLevel)
    }

    private func afterStateChange() {
        layoutHUD()
        saveState()
    }

    private func updateTimedBuildings(now: TimeInterval, shouldRender: Bool) {
        var changed = false
        for index in state.buildings.indices {
            guard let finishAt = state.buildings[index].finishAt, now >= finishAt else { continue }

            switch state.buildings[index].state {
            case "growing":
                state.buildings[index].state = "readyCrop"
                state.buildings[index].finishAt = nil
                changed = true
            case "delivering":
                state.buildings[index].state = "readyBusiness"
                state.buildings[index].finishAt = nil
                changed = true
            case "constructing":
                state.buildings[index].state = "complete"
                state.buildings[index].finishAt = nil
                completeEvent("complete_construction:\(state.buildings[index].definitionID)")
                changed = true
            default:
                break
            }
        }

        if changed {
            if shouldRender {
                renderBuildings()
                layoutHUD()
            }
            checkGoals()
            saveState()
        }
    }

    override func update(_ currentTime: TimeInterval) {
        let now = Date().timeIntervalSince1970
        let second = Int(now)
        if second != lastTickSecond {
            lastTickSecond = second
            updateTimedBuildings(now: now, shouldRender: true)
            renderBuildings()
            if now - lastAutosave > 5 {
                saveState()
            }
        }
    }

    private func showReward(text: String, at position: CGPoint) {
        let reward = strokedLabel(text, size: 18)
        reward.position = CGPoint(x: position.x, y: position.y + 110)
        reward.zPosition = 50_000
        reward.numberOfLines = 3
        effectLayer.addChild(reward)
        reward.run(.sequence([
            .group([.moveBy(x: 0, y: 52, duration: 0.75), .fadeOut(withDuration: 0.75)]),
            .removeFromParent()
        ]))
        playSound(candidates: ["music_sound/GoalCompletion.mp3"])
    }

    private func showTapFeedback(at position: CGPoint, color: UIColor) {
        let ring = SKShapeNode(circleOfRadius: 28)
        ring.position = position
        ring.strokeColor = color
        ring.lineWidth = 3
        ring.fillColor = .clear
        ring.zPosition = 50_000
        effectLayer.addChild(ring)
        ring.run(.sequence([
            .group([.scale(to: 1.8, duration: 0.25), .fadeOut(withDuration: 0.25)]),
            .removeFromParent()
        ]))
    }

    private func playSound(candidates: [String]) {
        guard let url = BundleAssetResolver.url(candidates: candidates) else { return }
        let node = SKAudioNode(url: url)
        node.autoplayLooped = false
        node.run(.changeVolume(to: 0.45, duration: 0))
        addChild(node)
        node.run(.play())
        node.run(.sequence([.wait(forDuration: 2.0), .removeFromParent()]))
    }

    private func tileCoordinate(for worldPoint: CGPoint) -> (column: Int, row: Int)? {
        let halfWidth = tileWidth / 2
        let halfHeight = tileHeight / 2
        let a = worldPoint.x / halfWidth
        let b = (mapOffsetY - worldPoint.y) / halfHeight
        let column = Int(floor((a + b) / 2))
        let row = Int(floor((b - a) / 2))

        guard column >= 0, row >= 0, column < mapColumns, row < mapRows else { return nil }
        return (column, row)
    }

    private func positionForTile(column: Int, row: Int) -> CGPoint {
        CGPoint(
            x: CGFloat(column - row) * tileWidth / 2,
            y: mapOffsetY - CGFloat(column + row) * tileHeight / 2
        )
    }

    private func tileKey(column: Int, row: Int) -> String {
        "\(column):\(row)"
    }

    private func worldBounds() -> CGRect {
        let left = -CGFloat(mapRows) * tileWidth / 2 - 160
        let right = CGFloat(mapColumns) * tileWidth / 2 + 160
        let top = mapOffsetY + 160
        let bottom = mapOffsetY - CGFloat(mapColumns + mapRows) * tileHeight / 2 - 180
        return CGRect(x: left, y: bottom, width: right - left, height: top - bottom)
    }

    private func clampCamera() {
        let bounds = worldBounds()
        let visibleWidth = size.width * cameraNode.xScale
        let visibleHeight = size.height * cameraNode.yScale
        let minX = bounds.minX + visibleWidth / 2
        let maxX = bounds.maxX - visibleWidth / 2
        let minY = bounds.minY + visibleHeight / 2
        let maxY = bounds.maxY - visibleHeight / 2

        if minX <= maxX {
            cameraNode.position.x = min(max(cameraNode.position.x, minX), maxX)
        }
        if minY <= maxY {
            cameraNode.position.y = min(max(cameraNode.position.y, minY), maxY)
        }
    }

    private func handlePinchZoom(_ touches: [UITouch]) {
        guard touches.count >= 2 else { return }
        let first = touches[0]
        let second = touches[1]
        let currentDistance = distance(first.location(in: self), second.location(in: self))
        let previousDistance = distance(first.previousLocation(in: self), second.previousLocation(in: self))
        guard currentDistance > 0, previousDistance > 0 else { return }
        let nextScale = cameraNode.xScale * previousDistance / currentDistance
        cameraNode.setScale(min(max(nextScale, 0.62), 2.1))
        clampCamera()
    }

    private func iconSprite(for category: String, fallbackSize: CGSize) -> SKSpriteNode {
        let frame: String
        switch category {
        case "Video":
            frame = "souk_screen/icons/VideoIcon.png"
        case "Housing":
            frame = "souk_screen/icons/ResidentialIcon.png"
        case "Business":
            frame = "souk_screen/icons/BusinessIcon.png"
        case "Farming":
            frame = "souk_screen/icons/FarmIcon.png"
        case "Community":
            frame = "souk_screen/icons/CommunityIcon.png"
        case "Expansion":
            frame = "souk_screen/icons/ExpansionIcon.png"
        case "Energy":
            frame = "souk_screen/icons/EnergyIcon.png"
        case "Currency":
            frame = "souk_screen/icons/CurrencyIcon.png"
        default:
            frame = "souk_screen/icons/NewIcon.png"
        }
        return sprite(from: soukAtlas, frameName: frame, fallbackSize: fallbackSize)
    }

    private func arabicCategoryName(_ category: String) -> String {
        switch category {
        case "New":
            return "جديد"
        case "Video":
            return "فيديو"
        case "Housing":
            return "المساكن"
        case "Business":
            return "المحال"
        case "Farming":
            return "الزراعة"
        case "Community":
            return "المجتمع"
        case "Expansion":
            return "التوسعة"
        case "Energy":
            return "الطاقة"
        case "Currency":
            return "العملة"
        default:
            return category
        }
    }

    private func sprite(from atlas: CocosTextureAtlas?, frameName: String, fallbackSize: CGSize) -> SKSpriteNode {
        if let texture = atlas?.texture(named: frameName) {
            return SKSpriteNode(texture: texture)
        }
        return SKSpriteNode(color: UIColor(white: 0.18, alpha: 0.85), size: fallbackSize)
    }

    private func label(_ text: String, size: CGFloat, color: UIColor, alignment: SKLabelHorizontalAlignmentMode) -> SKLabelNode {
        let node = SKLabelNode(fontNamed: containsArabic(text) ? "GeezaPro-Bold" : "AvenirNext-Bold")
        node.text = text
        node.fontSize = size
        node.fontColor = color
        node.horizontalAlignmentMode = alignment
        node.verticalAlignmentMode = .center
        return node
    }

    private func containsArabic(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x0600...0x06FF).contains(Int(scalar.value)) || (0x0750...0x077F).contains(Int(scalar.value))
        }
    }

    private func strokedLabel(_ text: String, size: CGFloat) -> SKLabelNode {
        let node = label(text, size: size, color: .white, alignment: .center)
        node.fontName = containsArabic(text) ? "GeezaPro-Bold" : "AvenirNext-Heavy"
        return node
    }

    private func distance(_ first: CGPoint, _ second: CGPoint) -> CGFloat {
        hypot(first.x - second.x, first.y - second.y)
    }
}
