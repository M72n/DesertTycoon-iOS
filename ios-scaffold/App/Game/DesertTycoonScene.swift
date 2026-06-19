import SpriteKit
import UIKit

final class DesertTycoonScene: SKScene {
    private let worldNode = SKNode()
    private let cameraNode = SKCameraNode()

    private var currentPhase: DesertTycoonPhase = .phaseOne
    private var mapNode: SKSpriteNode?
    private var mapSize: CGSize = .zero
    private var didSetUpScene = false
    private var didFitInitialCamera = false

    private let minimumCameraScale: CGFloat = 0.55
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
            resetCameraToFitMap()
            didFitInitialCamera = true
        } else {
            clampCameraToMap()
        }
    }

    private func setUpScene() {
        removeAllChildren()
        worldNode.removeAllChildren()
        worldNode.position = .zero
        addChild(worldNode)

        cameraNode.position = .zero
        addChild(cameraNode)
        camera = cameraNode

        loadPhase(currentPhase)
    }

    private func loadPhase(_ phase: DesertTycoonPhase) {
        currentPhase = phase
        worldNode.removeAllChildren()
        worldNode.physicsBody = nil
        mapNode = nil
        mapSize = .zero
        didFitInitialCamera = false

        guard let texture = BundleAssetResolver.texture(candidates: phase.mapCandidates) else {
            return
        }

        let mapSprite = SKSpriteNode(texture: texture)
        mapSprite.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        mapSprite.position = .zero
        mapSprite.zPosition = 0
        mapSprite.name = "phase-map"
        worldNode.addChild(mapSprite)

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

    private func resetCameraToFitMap() {
        guard mapSize.width > 0, mapSize.height > 0, size.width > 0, size.height > 0 else {
            cameraNode.position = .zero
            cameraNode.setScale(1)
            return
        }

        let widthScale = mapSize.width / size.width
        let heightScale = mapSize.height / size.height
        let fitScale = max(widthScale, heightScale)

        cameraNode.position = .zero
        cameraNode.setScale(clampedScale(fitScale))
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

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        let activeTouches = Array(event?.allTouches ?? touches)

        if activeTouches.count >= 2 {
            handlePinchZoom(activeTouches)
        } else if let touch = touches.first {
            handleCameraPan(touch)
        }

        clampCameraToMap()
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

    private func distance(_ first: CGPoint, _ second: CGPoint) -> CGFloat {
        hypot(first.x - second.x, first.y - second.y)
    }
}
