import Foundation
import SpriteKit

@MainActor
final class CocosTextureAtlas {
    private struct Frame {
        let rect: CGRect
    }

    private let texture: SKTexture
    private let textureSize: CGSize
    private let frames: [String: Frame]

    init?(plistCandidates: [String]) {
        guard let loaded = Self.loadAtlas(plistCandidates: plistCandidates) else {
            return nil
        }

        texture = loaded.texture
        textureSize = loaded.textureSize
        frames = loaded.frames
    }

    private static func loadAtlas(plistCandidates: [String]) -> (texture: SKTexture, textureSize: CGSize, frames: [String: Frame])? {
        for plistCandidate in plistCandidates {
            guard let plistURL = BundleAssetResolver.url(candidates: [plistCandidate]),
                  let plist = NSDictionary(contentsOf: plistURL) as? [String: Any],
                  let frameDictionary = plist["frames"] as? [String: Any],
                  let metadata = plist["metadata"] as? [String: Any],
                  let textureFileName = (metadata["realTextureFileName"] as? String) ?? (metadata["textureFileName"] as? String) else {
                continue
            }

            let plistDirectory = (plistCandidate as NSString).deletingLastPathComponent
            let texturePath = plistDirectory.isEmpty ? textureFileName : "\(plistDirectory)/\(textureFileName)"

            guard let baseTexture = BundleAssetResolver.texture(candidates: [texturePath]) else {
                continue
            }

            var parsedFrames: [String: Frame] = [:]
            for (name, value) in frameDictionary {
                guard let frameData = value as? [String: Any],
                      let frameString = frameData["frame"] as? String,
                      let rect = Self.parseTexturePackerRect(frameString) else {
                    continue
                }

                parsedFrames[name] = Frame(rect: rect)
            }

            return (baseTexture, baseTexture.size(), parsedFrames)
        }

        return nil
    }

    func texture(named frameName: String) -> SKTexture? {
        guard let frame = frames[frameName], textureSize.width > 0, textureSize.height > 0 else {
            return nil
        }

        let normalized = CGRect(
            x: frame.rect.minX / textureSize.width,
            y: (textureSize.height - frame.rect.maxY) / textureSize.height,
            width: frame.rect.width / textureSize.width,
            height: frame.rect.height / textureSize.height
        )
        let childTexture = SKTexture(rect: normalized, in: texture)
        childTexture.filteringMode = .linear
        return childTexture
    }

    func textures(withPrefix prefix: String) -> [SKTexture] {
        frames.keys
            .filter { $0.hasPrefix(prefix) }
            .sorted()
            .compactMap { texture(named: $0) }
    }

    private static func parseTexturePackerRect(_ value: String) -> CGRect? {
        let numbers = value
            .split { character in
                !(character == "-" || character == "." || character.isNumber)
            }
            .compactMap { Double($0) }

        guard numbers.count >= 4 else {
            return nil
        }

        return CGRect(
            x: CGFloat(numbers[0]),
            y: CGFloat(numbers[1]),
            width: CGFloat(numbers[2]),
            height: CGFloat(numbers[3])
        )
    }
}
