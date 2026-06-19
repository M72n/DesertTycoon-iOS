import SpriteKit
import UIKit

final class DesertTycoonScene: SKScene {
    private final class PlacedAsset {
        let id: Int
        let type: DesertTycoonBuildType
        let tileColumn: Int
        let tileRow: Int
        let node: SKNode
        let bubbleNode: SKNode

        var buildEndsAt: TimeInterval
        var nextProductionAt: TimeInterval
        var isBuilt = false
        var isReadyToCollect = false

        init(
            id: Int,
            type: DesertTycoonBuildType,
            tileColumn: Int,
            tileRow: Int,
            node: SKNode,
            bubbleNode: SKNode,
            currentTime: TimeInterval
        ) {
            self.id = id
            self.type = type
            self.tileColumn = tileColumn
            self.tileRow = tileRow
            self.node = node
            self.bubbleNode = bubbleNode
            buildEndsAt = currentTime + type.buildDuration
            nextProductionAt = buildEndsAt + type.productionInterval
        }
    }

    private let worldNode = SKNode()
    private let mapLayer = SKNode()
    private let buildLayer = SKNode()
    private let entityLayer = SKNode()
    private let cameraNode = SKCameraNode()
    private let hudNode = SKNode()
    private var musicNode: SKAudioNode?

    private var gameAtlas: CocosTextureAtlas?
    private var soukAtlas: CocosTextureAtlas?
    private var balloonAtlas: CocosTextureAtlas?
    private var camelAtlas: CocosTextureAtlas?
    private var rigAtlas: CocosTextureAtlas?

    private var currentPhase: DesertTycoonPhase = .phaseOne
    private var resources = DesertTycoonResources()
    private var resourceLabels: [DesertTycoonResource: SKLabelNode] = [:]
    private var selectedBuildType: DesertTycoonBuildType = .residential
    private var placedAssets: [Int: PlacedAsset] = [:]
    private var occupiedTiles = Set<String>()
    private var nextPlacedAssetID = 1

    private var mapNode: SKSpriteNode?
    private var mapSize: CGSize = .zero
    private var didSetUpScene = false
    private var didFitInitialCamera = false
    private var touchStartLocation: CGPoint?
    private var touchStartedOnHUD = false
    private var lastUpdateTime: TimeInterval = 0

    private let minimumCameraScale: CGFloat = 0.75
    private let maximumCameraScale: CGFloat = 24.0

    override init(size: CGSize) {
        super.init(size: size)
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = .black
        physicsWorld.gravity = .zero
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = .black
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

        if !didFitInitialCamera {
            resetCameraToPlayableZoom()
            didFitInitialCamera = true
        } else {
            clampCameraToMap()
        }

        layoutHUD()
    }

    private func setUpScene() {
        removeAllChildren()
        worldNode.removeAllChildren()
        cameraNode.removeAllChildren()

        gameAtlas = CocosTextureAtlas(plistCandidates: ["iphone-hd/game-images.plist"])
        soukAtlas = CocosTextureAtlas(plistCandidates: ["iphone-hd/souk-images.plist"])
        balloonAtlas = CocosTextureAtlas(plistCandidates: ["iphone-hd/balloons-images.plist"])
        camelAtlas = CocosTextureAtlas(plistCandidates: ["iphone-hd/traveling/CamelTraveling/TravelingCamel-hd.plist"])
        rigAtlas = CocosTextureAtlas(plistCandidates: ["iphone-hd/traveling/MediumRigTraveling/TravelingMediumRig-hd.plist"])

        worldNode.position = .zero
        addChild(worldNode)
        worldNode.addChild(mapLayer)
        worldNode.addChild(buildLayer)
        worldNode.addChild(entityLayer)

        cameraNode.position = .zero
        addChild(cameraNode)
        cameraNode.addChild(hudNode)
        camera = cameraNode

        loadPhase(currentPhase)
        spawnTraveler()
        startBackgroundMusic()
        layoutHUD()
    }

    private func loadPhase(_ phase: DesertTycoonPhase) {
        currentPhase = phase
        mapLayer.removeAllChildren()
        buildLayer.removeAllChildren()
        entityLayer.removeAllChildren()
        worldNode.physicsBody = nil
        mapNode = nil
        mapSize = .zero
        didFitInitialCamera = false
        placedAssets.removeAll()
        occupiedTiles.removeAll()

        guard let texture = BundleAssetResolver.texture(candidates: phase.mapCandidates) else {
            return
        }

        let mapSprite = SKSpriteNode(texture: texture)
        mapSprite.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        mapSprite.position = .zero
        mapSprite.zPosition = 0
        mapSprite.name = "phase-map"
        mapLayer.addChild(mapSprite)

        mapNode = mapSprite
        mapSize = mapSprite.size

        let mapRect = CGRect(
            x: -mapSize.width / 2,
            y: -mapSize.height / 2,
            width: mapSize.width,
            height: mapSize.height
        )
        worldNode.physicsBody = SKPhysicsBody(edgeLoopFrom: mapRect)
        worldNode.physicsBody?.isDynamic = false
    }

    private func layoutHUD() {
        hudNode.removeAllChildren()
        resourceLabels.removeAll()

        let topY = size.height / 2 - 34
        let leftX = -size.width / 2 + 20
        var currentX = leftX
        let resourceSpacing = min(CGFloat(72), max(CGFloat(56), (size.width - 40) / CGFloat(DesertTycoonResource.allCases.count)))

        for resource in DesertTycoonResource.allCases {
            let group = SKNode()
            group.position = CGPoint(x: currentX, y: topY)
            hudNode.addChild(group)

            let icon = sprite(from: atlas(for: resource), frameName: resource.iconFrame, fallbackSize: CGSize(width: 24, height: 24))
            icon.size = CGSize(width: 24, height: 24)
            icon.position = CGPoint(x: 12, y: 0)
            icon.zPosition = 1001
            group.addChild(icon)

            let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
            label.fontColor = .white
            label.fontSize = 15
            label.horizontalAlignmentMode = .left
            label.verticalAlignmentMode = .center
            label.position = CGPoint(x: 30, y: 0)
            label.zPosition = 1001
            group.addChild(label)
            resourceLabels[resource] = label

            currentX += resourceSpacing
        }

        let bottomY = -size.height / 2 + 46
        if let bottomBarTexture = gameAtlas?.texture(named: "main_screen_ui/bottom_bar/bottom_bar.png") {
            let bottomBar = SKSpriteNode(texture: bottomBarTexture)
            bottomBar.size = CGSize(width: min(size.width, 520), height: 86)
            bottomBar.position = CGPoint(x: 0, y: -size.height / 2 + 38)
            bottomBar.alpha = 0.94
            bottomBar.zPosition = 998
            hudNode.addChild(bottomBar)
        }

        let buttonSpacing: CGFloat = 52
        let totalWidth = CGFloat(DesertTycoonBuildType.allCases.count - 1) * buttonSpacing
        let startX = -totalWidth / 2

        for (index, buildType) in DesertTycoonBuildType.allCases.enumerated() {
            let position = CGPoint(x: startX + CGFloat(index) * buttonSpacing, y: bottomY)
            let button = buildButton(for: buildType)
            button.position = position
            hudNode.addChild(button)
        }

        updateResourceLabels()
    }

    private func buildButton(for buildType: DesertTycoonBuildType) -> SKNode {
        let root = SKNode()
        root.name = "build:\(buildType.rawValue)"
        root.zPosition = 1000

        let background = SKShapeNode(rectOf: CGSize(width: 46, height: 46), cornerRadius: 8)
        background.fillColor = selectedBuildType == buildType ? UIColor(red: 0.94, green: 0.76, blue: 0.26, alpha: 0.9) : UIColor(white: 0.02, alpha: 0.72)
        background.strokeColor = selectedBuildType == buildType ? .white : UIColor(white: 1.0, alpha: 0.35)
        background.lineWidth = selectedBuildType == buildType ? 2 : 1
        background.name = root.name
        root.addChild(background)

        let icon = sprite(from: soukAtlas, frameName: buildType.iconFrame, fallbackSize: CGSize(width: 30, height: 30))
        icon.size = CGSize(width: 30, height: 30)
        icon.zPosition = 1001
        icon.name = root.name
        root.addChild(icon)

        let cost = SKLabelNode(fontNamed: "AvenirNext-Bold")
        cost.text = "\(buildType.cost)"
        cost.fontSize = 8
        cost.fontColor = .white
        cost.verticalAlignmentMode = .top
        cost.horizontalAlignmentMode = .center
        cost.position = CGPoint(x: 0, y: -25)
        cost.zPosition = 1001
        cost.name = root.name
        root.addChild(cost)

        return root
    }

    private func atlas(for resource: DesertTycoonResource) -> CocosTextureAtlas? {
        switch resource {
        case .population:
            return soukAtlas
        default:
            return gameAtlas
        }
    }

    private func startBackgroundMusic() {
        guard musicNode == nil,
              let url = BundleAssetResolver.url(candidates: ["music_sound/BackgroundSound.mp3"]) else {
            return
        }

        let node = SKAudioNode(url: url)
        node.autoplayLooped = true
        node.run(.changeVolume(to: 0.35, duration: 0))
        musicNode = node
        addChild(node)
    }

    private func sprite(from atlas: CocosTextureAtlas?, frameName: String, fallbackSize: CGSize) -> SKSpriteNode {
        if let texture = atlas?.texture(named: frameName) {
            return SKSpriteNode(texture: texture)
        }

        return SKSpriteNode(color: UIColor(white: 0.15, alpha: 0.85), size: fallbackSize)
    }

    private func updateResourceLabels() {
        for resource in DesertTycoonResource.allCases {
            resourceLabels[resource]?.text = "\(resources.value(for: resource))"
        }
    }

    private func resetCameraToPlayableZoom() {
        guard mapSize.width > 0, mapSize.height > 0, size.width > 0, size.height > 0 else {
            cameraNode.position = .zero
            cameraNode.setScale(1)
            return
        }

        let widthScale = mapSize.width / size.width
        let heightScale = mapSize.height / size.height
        let fitScale = max(widthScale, heightScale)
        let playableScale = fitScale * 0.45

        cameraNode.position = .zero
        cameraNode.setScale(clampedScale(playableScale))
        clampCameraToMap()
    }

    private func clampedScale(_ scale: CGFloat) -> CGFloat {
        min(max(scale, minimumCameraScale), maximumCameraScale)
    }

    private func clampCameraToMap() {
        guard mapSize.width > 0, mapSize.height > 0, size.width > 0, size.height > 0 else {
            cameraNode.position = .zero
            return
        }

        let visibleWidth = size.width * cameraNode.xScale
        let visibleHeight = size.height * cameraNode.yScale
        let halfMapWidth = mapSize.width / 2
        let halfMapHeight = mapSize.height / 2

        cameraNode.position.x = clampedCameraCoordinate(
            cameraNode.position.x,
            minimum: -halfMapWidth + visibleWidth / 2,
            maximum: halfMapWidth - visibleWidth / 2
        )
        cameraNode.position.y = clampedCameraCoordinate(
            cameraNode.position.y,
            minimum: -halfMapHeight + visibleHeight / 2,
            maximum: halfMapHeight - visibleHeight / 2
        )
    }

    private func clampedCameraCoordinate(_ value: CGFloat, minimum: CGFloat, maximum: CGFloat) -> CGFloat {
        if minimum > maximum {
            return 0
        }

        return min(max(value, minimum), maximum)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        touchStartLocation = location
        touchStartedOnHUD = hudActionName(at: location) != nil
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        let activeTouches = Array(event?.allTouches ?? touches)

        if activeTouches.count >= 2 {
            handlePinchZoom(activeTouches)
        } else if !touchStartedOnHUD, let touch = touches.first {
            handleCameraPan(touch)
        }

        clampCameraToMap()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let startLocation = touchStartLocation ?? location
        let travel = distance(startLocation, location)
        touchStartLocation = nil

        guard travel < 18 else { return }

        if let actionName = hudActionName(at: location) {
            handleHUDAction(actionName)
            return
        }

        handleMapTap(at: location)
    }

    private func hudActionName(at location: CGPoint) -> String? {
        for node in nodes(at: location) {
            var current: SKNode? = node
            while let candidate = current {
                if let name = candidate.name, name.hasPrefix("build:") {
                    return name
                }
                current = candidate.parent
            }
        }

        return nil
    }

    private func handleHUDAction(_ actionName: String) {
        if actionName.hasPrefix("build:") {
            let rawValue = String(actionName.dropFirst("build:".count))
            if let buildType = DesertTycoonBuildType(rawValue: rawValue) {
                selectedBuildType = buildType
                layoutHUD()
            }
        }
    }

    private func handleMapTap(at location: CGPoint) {
        if collectAsset(at: location) {
            return
        }

        guard let tile = tileCoordinate(for: location), resources.spendCoins(selectedBuildType.cost) else {
            showTapFeedback(at: location, color: .red)
            return
        }

        let key = tileKey(column: tile.column, row: tile.row)
        guard !occupiedTiles.contains(key) else {
            showTapFeedback(at: location, color: .red)
            return
        }

        occupiedTiles.insert(key)
        placeAsset(selectedBuildType, atColumn: tile.column, row: tile.row)
        updateResourceLabels()
    }

    private func collectAsset(at location: CGPoint) -> Bool {
        for node in nodes(at: location) {
            var current: SKNode? = node
            while let candidate = current {
                if let name = candidate.name, name.hasPrefix("asset:") {
                    let idText = String(name.dropFirst("asset:".count))
                    if let id = Int(idText), let asset = placedAssets[id], asset.isReadyToCollect {
                        resources.add(asset.type.productionAmount, to: asset.type.productionResource)
                        asset.isReadyToCollect = false
                        asset.nextProductionAt = lastUpdateTime + asset.type.productionInterval
                        asset.bubbleNode.isHidden = true
                        updateResourceLabels()
                        showTapFeedback(at: asset.node.position, color: .green)
                    }
                    return true
                }
                current = candidate.parent
            }
        }

        return false
    }

    private func placeAsset(_ buildType: DesertTycoonBuildType, atColumn column: Int, row: Int) {
        let id = nextPlacedAssetID
        nextPlacedAssetID += 1

        let root = SKNode()
        root.name = "asset:\(id)"
        root.position = positionForTile(column: column, row: row)
        root.zPosition = 10_000 - root.position.y

        let icon: SKSpriteNode
        if buildType == .oil, let firstRigTexture = rigAtlas?.textures(withPrefix: "Oil_Production_Medium_Rig_SE_").first {
            icon = SKSpriteNode(texture: firstRigTexture)
            icon.size = CGSize(width: 88, height: 88)
            let rigTextures = rigAtlas?.textures(withPrefix: "Oil_Production_Medium_Rig_SE_") ?? []
            if !rigTextures.isEmpty {
                icon.run(.repeatForever(.animate(with: rigTextures, timePerFrame: 0.08)))
            }
        } else {
            icon = sprite(from: soukAtlas, frameName: buildType.iconFrame, fallbackSize: CGSize(width: 58, height: 58))
            icon.size = CGSize(width: 58, height: 58)
        }
        icon.name = root.name
        icon.position = CGPoint(x: 0, y: 24)
        root.addChild(icon)

        let buildBubble = sprite(from: balloonAtlas, frameName: "status_baloons/Build_Bubble.png", fallbackSize: CGSize(width: 54, height: 42))
        buildBubble.size = CGSize(width: 54, height: 42)
        buildBubble.position = CGPoint(x: 0, y: 80)
        buildBubble.name = root.name
        root.addChild(buildBubble)

        let placedAsset = PlacedAsset(
            id: id,
            type: buildType,
            tileColumn: column,
            tileRow: row,
            node: root,
            bubbleNode: buildBubble,
            currentTime: lastUpdateTime
        )
        placedAssets[id] = placedAsset
        buildLayer.addChild(root)
    }

    private func showTapFeedback(at location: CGPoint, color: UIColor) {
        let ring = SKShapeNode(circleOfRadius: 28)
        ring.position = location
        ring.strokeColor = color
        ring.lineWidth = 3
        ring.fillColor = .clear
        ring.zPosition = 40_000
        worldNode.addChild(ring)
        ring.run(.sequence([
            .group([
                .scale(to: 1.8, duration: 0.28),
                .fadeOut(withDuration: 0.28)
            ]),
            .removeFromParent()
        ]))
    }

    private func handleCameraPan(_ touch: UITouch) {
        let currentLocation = touch.location(in: self)
        let previousLocation = touch.previousLocation(in: self)
        let delta = CGPoint(
            x: currentLocation.x - previousLocation.x,
            y: currentLocation.y - previousLocation.y
        )

        cameraNode.position.x -= delta.x * cameraNode.xScale
        cameraNode.position.y -= delta.y * cameraNode.yScale
    }

    private func handlePinchZoom(_ touches: [UITouch]) {
        let firstTouch = touches[0]
        let secondTouch = touches[1]

        let currentDistance = distance(
            firstTouch.location(in: self),
            secondTouch.location(in: self)
        )
        let previousDistance = distance(
            firstTouch.previousLocation(in: self),
            secondTouch.previousLocation(in: self)
        )

        guard currentDistance > 0, previousDistance > 0 else { return }

        let nextScale = cameraNode.xScale * previousDistance / currentDistance
        cameraNode.setScale(clampedScale(nextScale))
    }

    private func tileCoordinate(for scenePoint: CGPoint) -> (column: Int, row: Int)? {
        guard mapSize.width > 0, mapSize.height > 0 else { return nil }

        let halfTileWidth = currentPhase.tileSize.width / 2
        let halfTileHeight = currentPhase.tileSize.height / 2
        let imageX = scenePoint.x + mapSize.width / 2
        let imageY = mapSize.height / 2 - scenePoint.y
        let shiftedX = imageX - CGFloat(currentPhase.mapRows - 1) * halfTileWidth - halfTileWidth
        let shiftedY = imageY - halfTileHeight

        let a = shiftedX / halfTileWidth
        let b = shiftedY / halfTileHeight
        let column = Int(floor((a + b) / 2))
        let row = Int(floor((b - a) / 2))

        guard column >= 0, row >= 0, column < currentPhase.mapColumns, row < currentPhase.mapRows else {
            return nil
        }

        return (column, row)
    }

    private func positionForTile(column: Int, row: Int) -> CGPoint {
        let halfTileWidth = currentPhase.tileSize.width / 2
        let halfTileHeight = currentPhase.tileSize.height / 2
        let imageX = CGFloat(column - row) * halfTileWidth + CGFloat(currentPhase.mapRows - 1) * halfTileWidth + halfTileWidth
        let imageY = CGFloat(column + row) * halfTileHeight + halfTileHeight

        return CGPoint(
            x: imageX - mapSize.width / 2,
            y: mapSize.height / 2 - imageY
        )
    }

    private func tileKey(column: Int, row: Int) -> String {
        "\(column):\(row)"
    }

    private func spawnTraveler() {
        guard let textures = camelAtlas?.textures(withPrefix: "Camel_Happy_Pen_FINAL"), let firstTexture = textures.first else {
            return
        }

        let traveler = SKSpriteNode(texture: firstTexture)
        traveler.size = CGSize(width: 72, height: 72)
        traveler.position = positionForTile(column: 45, row: 54)
        traveler.zPosition = 20_000
        entityLayer.addChild(traveler)

        traveler.run(.repeatForever(.animate(with: textures, timePerFrame: 0.06)))

        let route = [
            positionForTile(column: 45, row: 54),
            positionForTile(column: 52, row: 48),
            positionForTile(column: 58, row: 58),
            positionForTile(column: 49, row: 63)
        ]
        let moves = route.map { SKAction.move(to: $0, duration: 3.2) }
        traveler.run(.repeatForever(.sequence(moves)))
    }

    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 {
            lastUpdateTime = currentTime
        }
        lastUpdateTime = currentTime

        for asset in placedAssets.values {
            if !asset.isBuilt, currentTime >= asset.buildEndsAt {
                asset.isBuilt = true
                if let texture = balloonAtlas?.texture(named: asset.type.bubbleFrame),
                   let bubble = asset.bubbleNode as? SKSpriteNode {
                    bubble.texture = texture
                    bubble.size = CGSize(width: 54, height: 42)
                }
                asset.bubbleNode.isHidden = true
            }

            if asset.isBuilt, !asset.isReadyToCollect, currentTime >= asset.nextProductionAt {
                asset.isReadyToCollect = true
                asset.bubbleNode.isHidden = false
                asset.bubbleNode.run(.sequence([
                    .scale(to: 1.12, duration: 0.18),
                    .scale(to: 1.0, duration: 0.18)
                ]))
            }
        }
    }

    private func distance(_ first: CGPoint, _ second: CGPoint) -> CGFloat {
        hypot(first.x - second.x, first.y - second.y)
    }
}
