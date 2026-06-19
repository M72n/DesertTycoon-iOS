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

    private enum MapVisualMode {
        case referenceBackdrop
        case renderedTileMap
    }

    private let worldNode = SKNode()
    private let mapLayer = SKNode()
    private let buildLayer = SKNode()
    private let entityLayer = SKNode()
    private let cameraNode = SKCameraNode()
    private let hudNode = SKNode()
    private var musicNode: SKAudioNode?
    private var videoNode: SKVideoNode?
    private var splashNode: SKSpriteNode?
    private var referenceOverlayNode: SKNode?

    private var gameAtlas: CocosTextureAtlas?
    private var soukAtlas: CocosTextureAtlas?
    private var balloonAtlas: CocosTextureAtlas?
    private var camelAtlas: CocosTextureAtlas?
    private var rigAtlas: CocosTextureAtlas?

    private var currentPhase: DesertTycoonPhase = .phaseThree
    private var mapVisualMode: MapVisualMode = .renderedTileMap
    private var referenceBackdropIndex = 0
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
    private var didShowLaunchSplash = false
    private var touchStartLocation: CGPoint?
    private var touchStartedOnHUD = false
    private var lastUpdateTime: TimeInterval = 0

    private let minimumCameraScale: CGFloat = 0.75
    private let maximumCameraScale: CGFloat = 24.0

    override init(size: CGSize) {
        super.init(size: size)
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = UIColor(red: 0.72, green: 0.58, blue: 0.38, alpha: 1.0)
        physicsWorld.gravity = .zero
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = UIColor(red: 0.72, green: 0.58, blue: 0.38, alpha: 1.0)
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
        resizeLaunchSplash()
        showLaunchSplashIfNeeded()
    }

    private func setUpScene() {
        removeAllChildren()
        worldNode.removeAllChildren()
        cameraNode.removeAllChildren()

        gameAtlas = CocosTextureAtlas(plistCandidates: ["iphone-hd-upscaled/game-images.plist", "iphone-hd/game-images.plist"])
        soukAtlas = CocosTextureAtlas(plistCandidates: ["iphone-hd-upscaled/souk-images.plist", "iphone-hd/souk-images.plist"])
        balloonAtlas = CocosTextureAtlas(plistCandidates: ["iphone-hd-upscaled/balloons-images.plist", "iphone-hd/balloons-images.plist"])
        camelAtlas = CocosTextureAtlas(plistCandidates: ["iphone-hd-upscaled/traveling/CamelTraveling/TravelingCamel-hd.plist", "iphone-hd/traveling/CamelTraveling/TravelingCamel-hd.plist"])
        rigAtlas = CocosTextureAtlas(plistCandidates: ["iphone-hd-upscaled/traveling/MediumRigTraveling/TravelingMediumRig-hd.plist", "iphone-hd/traveling/MediumRigTraveling/TravelingMediumRig-hd.plist"])

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
        if mapVisualMode == .renderedTileMap {
            spawnTraveler()
        }
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
        referenceOverlayNode?.removeFromParent()
        referenceOverlayNode = nil

        guard let texture = textureForPhase(phase) else {
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

    private func textureForPhase(_ phase: DesertTycoonPhase) -> SKTexture? {
        let referencePaths = phase.referenceBackdropPaths
        if !referencePaths.isEmpty {
            for offset in 0..<referencePaths.count {
                let index = (referenceBackdropIndex + offset) % referencePaths.count
                if let texture = BundleAssetResolver.texture(candidates: [referencePaths[index]]) {
                    referenceBackdropIndex = index
                    mapVisualMode = .referenceBackdrop
                    return texture
                }
            }
        }

        mapVisualMode = .renderedTileMap
        return BundleAssetResolver.texture(candidates: phase.mapCandidates)
    }

    private func showLaunchSplashIfNeeded() {
        guard !didShowLaunchSplash,
              let texture = BundleAssetResolver.texture(candidates: [
                "ReferenceBackdrops/apk_splash.png",
                "iphone-hd/splash/dt_splash_arabic.jpg",
                "iphone-hd/splash/dt_splash_english.jpg"
              ]) else {
            return
        }

        didShowLaunchSplash = true
        let node = SKSpriteNode(texture: texture)
        node.position = .zero
        node.zPosition = 9000
        node.size = coverSize(for: texture.size())
        cameraNode.addChild(node)
        splashNode = node

        node.run(.sequence([
            .wait(forDuration: 1.4),
            .fadeOut(withDuration: 0.35),
            .removeFromParent()
        ]))
    }

    private func resizeLaunchSplash() {
        guard let splashNode, let texture = splashNode.texture else { return }
        splashNode.size = coverSize(for: texture.size())
    }

    private func coverSize(for textureSize: CGSize) -> CGSize {
        guard textureSize.width > 0, textureSize.height > 0, size.width > 0, size.height > 0 else {
            return size
        }

        let scale = max(size.width / textureSize.width, size.height / textureSize.height)
        return CGSize(width: textureSize.width * scale, height: textureSize.height * scale)
    }

    private func layoutHUD() {
        hudNode.removeAllChildren()
        resourceLabels.removeAll()

        if mapVisualMode == .referenceBackdrop {
            layoutReferenceTouchZones()
            return
        }

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

        let videoButton = mediaButton(name: "video:intro", frameName: "souk_screen/icons/VideoIcon.png")
        videoButton.position = CGPoint(x: size.width / 2 - 34, y: topY)
        hudNode.addChild(videoButton)

        let bottomY = -size.height / 2 + 46
        if let bottomBarTexture = gameAtlas?.texture(named: "main_screen_ui/bottom_bar/bottom_bar.png") {
            let bottomBar = SKSpriteNode(texture: bottomBarTexture)
            bottomBar.size = CGSize(width: size.width, height: 92)
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

    private func layoutReferenceTouchZones() {
        addReferenceTouchZone(
            name: "reference:showGoals",
            rect: CGRect(x: -size.width / 2, y: -size.height / 2, width: 120, height: 100)
        )
        addReferenceTouchZone(
            name: "reference:showMenu",
            rect: CGRect(x: size.width / 2 - 120, y: -size.height / 2, width: 120, height: 100)
        )
        addReferenceTouchZone(
            name: "reference:cycleBackdrop",
            rect: CGRect(x: -size.width / 2 + 120, y: -size.height / 2, width: size.width - 240, height: 100)
        )
        addReferenceTouchZone(
            name: "reference:nextPhase",
            rect: CGRect(x: -size.width / 2, y: size.height / 2 - 120, width: size.width * 0.58, height: 120)
        )
        addReferenceTouchZone(
            name: "video:intro",
            rect: CGRect(x: size.width / 2 - 110, y: size.height / 2 - 110, width: 100, height: 100)
        )
    }

    private func addReferenceTouchZone(name: String, rect: CGRect) {
        let node = SKShapeNode(rect: rect)
        node.name = name
        node.fillColor = UIColor(white: 1.0, alpha: 0.01)
        node.strokeColor = .clear
        node.lineWidth = 0
        node.zPosition = 1000
        hudNode.addChild(node)
    }

    private func buildButton(for buildType: DesertTycoonBuildType) -> SKNode {
        let root = SKNode()
        root.name = "build:\(buildType.rawValue)"
        root.zPosition = 1000

        let background = sprite(from: soukAtlas, frameName: "souk_screen/souk_item_frame.png", fallbackSize: CGSize(width: 48, height: 48))
        background.size = CGSize(width: 48, height: 48)
        background.alpha = selectedBuildType == buildType ? 1.0 : 0.78
        background.zPosition = 999
        background.name = root.name
        root.addChild(background)

        if selectedBuildType == buildType {
            let selection = SKShapeNode(rectOf: CGSize(width: 46, height: 46), cornerRadius: 8)
            selection.fillColor = .clear
            selection.strokeColor = UIColor(red: 0.95, green: 0.78, blue: 0.28, alpha: 1.0)
            selection.lineWidth = 3
            selection.zPosition = 1002
            selection.name = root.name
            root.addChild(selection)
        }

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

    private func mediaButton(name: String, frameName: String) -> SKNode {
        let root = SKNode()
        root.name = name
        root.zPosition = 1000

        let background = SKShapeNode(rectOf: CGSize(width: 40, height: 40), cornerRadius: 8)
        background.fillColor = UIColor(white: 0.02, alpha: 0.72)
        background.strokeColor = UIColor(white: 1.0, alpha: 0.35)
        background.lineWidth = 1
        background.name = name
        root.addChild(background)

        let icon = sprite(from: soukAtlas, frameName: frameName, fallbackSize: CGSize(width: 26, height: 26))
        icon.size = CGSize(width: 26, height: 26)
        icon.name = name
        icon.zPosition = 1001
        root.addChild(icon)

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
        let playableScale: CGFloat
        if mapVisualMode == .referenceBackdrop {
            playableScale = min(widthScale, heightScale)
        } else {
            let fitScale = max(widthScale, heightScale)
            playableScale = fitScale * 0.45
        }

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
                if let name = candidate.name, name.hasPrefix("video:") {
                    return name
                }
                if let name = candidate.name, name.hasPrefix("reference:") {
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
        } else if actionName.hasPrefix("video:") {
            playIntroVideo()
        } else if actionName == "reference:closeOverlay" {
            closeReferenceOverlay()
        } else if actionName == "reference:showMenu" {
            presentReferenceOverlay(candidates: ["iphone-hd/souk_screen/souk_bg.jpg"])
        } else if actionName == "reference:showGoals" {
            presentReferenceOverlay(candidates: [
                "iphone-hd/dialogues_ui/tasks/task_menu_bg.png",
                "iphone-hd/dialogues_ui/goal_completion/goal_completion_bg.png"
            ])
        } else if actionName == "reference:nextPhase" {
            advancePhase(by: 1)
        } else if actionName == "reference:previousPhase" {
            advancePhase(by: -1)
        } else if actionName == "reference:cycleBackdrop" {
            cycleReferenceBackdrop()
        }
    }

    private func advancePhase(by delta: Int) {
        let phases = DesertTycoonPhase.allCases
        guard let currentIndex = phases.firstIndex(of: currentPhase) else { return }

        let nextIndex = (currentIndex + delta + phases.count) % phases.count
        referenceBackdropIndex = 0
        loadPhase(phases[nextIndex])
        if mapVisualMode == .renderedTileMap {
            spawnTraveler()
        }
        layoutCamera()
        playSound(candidates: ["music_sound/LevelCompletion.mp3"])
    }

    private func cycleReferenceBackdrop() {
        let count = currentPhase.referenceBackdropPaths.count
        guard mapVisualMode == .referenceBackdrop, count > 1 else {
            showTapFeedback(at: cameraNode.position, color: .green)
            return
        }

        referenceBackdropIndex = (referenceBackdropIndex + 1) % count
        loadPhase(currentPhase)
        layoutCamera()
        playSound(candidates: ["music_sound/GoalCompletion.mp3"])
    }

    private func presentReferenceOverlay(candidates: [String]) {
        guard let texture = BundleAssetResolver.texture(candidates: candidates) else {
            showTapFeedback(at: cameraNode.position, color: .red)
            return
        }

        closeReferenceOverlay()

        let root = SKNode()
        root.zPosition = 8500
        root.name = "reference:closeOverlay"

        let blocker = SKShapeNode(rect: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height))
        blocker.fillColor = UIColor(white: 0.0, alpha: 0.42)
        blocker.strokeColor = .clear
        blocker.name = root.name
        root.addChild(blocker)

        let panel = SKSpriteNode(texture: texture)
        panel.size = fitSize(for: texture.size(), maximum: CGSize(width: size.width * 0.92, height: size.height * 0.92))
        panel.position = .zero
        panel.name = root.name
        root.addChild(panel)

        cameraNode.addChild(root)
        referenceOverlayNode = root
    }

    private func closeReferenceOverlay() {
        referenceOverlayNode?.removeFromParent()
        referenceOverlayNode = nil
    }

    private func fitSize(for textureSize: CGSize, maximum: CGSize) -> CGSize {
        guard textureSize.width > 0, textureSize.height > 0, maximum.width > 0, maximum.height > 0 else {
            return maximum
        }

        let scale = min(maximum.width / textureSize.width, maximum.height / textureSize.height)
        return CGSize(width: textureSize.width * scale, height: textureSize.height * scale)
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
                        playSound(candidates: ["music_sound/GoalCompletion.mp3", "music_sound/LevelCompletion.mp3"])
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
        playSound(candidates: ["music_sound/EnergyPack.mp3"])
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

        if mapVisualMode == .referenceBackdrop {
            let imageX = scenePoint.x + mapSize.width / 2
            let imageY = mapSize.height / 2 - scenePoint.y
            guard imageX >= 0, imageY >= 0, imageX <= mapSize.width, imageY <= mapSize.height else {
                return nil
            }

            let column = Int((imageX / mapSize.width) * CGFloat(currentPhase.mapColumns))
            let row = Int((imageY / mapSize.height) * CGFloat(currentPhase.mapRows))
            return (
                min(max(column, 0), currentPhase.mapColumns - 1),
                min(max(row, 0), currentPhase.mapRows - 1)
            )
        }

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
        if mapVisualMode == .referenceBackdrop, mapSize.width > 0, mapSize.height > 0 {
            let imageX = (CGFloat(column) + 0.5) / CGFloat(currentPhase.mapColumns) * mapSize.width
            let imageY = (CGFloat(row) + 0.5) / CGFloat(currentPhase.mapRows) * mapSize.height
            return CGPoint(
                x: imageX - mapSize.width / 2,
                y: mapSize.height / 2 - imageY
            )
        }

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
        guard mapVisualMode == .renderedTileMap else {
            return
        }

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

    private func playIntroVideo() {
        if let videoNode {
            videoNode.pause()
            videoNode.removeFromParent()
            self.videoNode = nil
            return
        }

        guard let url = BundleAssetResolver.url(candidates: [
            "movies/Narrative-Final_v2012_05_30-ar_subs.mp4",
            "movies/Phase2Tutorial.mp4",
            "movies/Phase3Tutorial.mp4"
        ]) else {
            return
        }

        let node = SKVideoNode(url: url)
        node.size = size
        node.position = .zero
        node.zPosition = 5000
        node.name = "video:close"
        hudNode.addChild(node)
        node.play()
        videoNode = node
    }

    private func playSound(candidates: [String]) {
        guard let url = BundleAssetResolver.url(candidates: candidates) else {
            return
        }

        let node = SKAudioNode(url: url)
        node.autoplayLooped = false
        node.run(.changeVolume(to: 0.45, duration: 0))
        addChild(node)
        node.run(.play())
        node.run(.sequence([
            .wait(forDuration: 2.0),
            .removeFromParent()
        ]))
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
