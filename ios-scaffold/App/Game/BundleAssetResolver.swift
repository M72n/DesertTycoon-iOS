import SpriteKit
import UIKit

enum BundleAssetResolver {
    static func texture(candidates: [String]) -> SKTexture? {
        guard let image = image(candidates: candidates) else {
            return nil
        }

        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        return texture
    }

    static func image(candidates: [String]) -> UIImage? {
        for candidate in expandedCandidates(candidates) {
            if let image = UIImage(named: candidate) {
                return image
            }

            let normalizedPath = candidate.replacingOccurrences(of: "\\", with: "/")
            let nsPath = normalizedPath as NSString
            let fileName = nsPath.lastPathComponent as NSString
            let directory = nsPath.deletingLastPathComponent
            let resourceName = fileName.deletingPathExtension
            let resourceExtension = fileName.pathExtension.isEmpty ? nil : fileName.pathExtension
            let bundleDirectory = directory.isEmpty || directory == "." ? nil : directory

            if let path = Bundle.main.path(
                forResource: resourceName,
                ofType: resourceExtension,
                inDirectory: bundleDirectory
            ),
               let image = UIImage(contentsOfFile: path) {
                return image
            }
        }

        return nil
    }

    private static func expandedCandidates(_ candidates: [String]) -> [String] {
        var expanded: [String] = []
        var seen = Set<String>()

        func append(_ candidate: String) {
            guard !seen.contains(candidate) else { return }
            seen.insert(candidate)
            expanded.append(candidate)
        }

        for candidate in candidates {
            append(candidate)

            if candidate.hasPrefix("LegacyAssets/") {
                append(String(candidate.dropFirst("LegacyAssets/".count)))
            } else {
                append("LegacyAssets/\(candidate)")
            }
        }

        return expanded
    }
}
