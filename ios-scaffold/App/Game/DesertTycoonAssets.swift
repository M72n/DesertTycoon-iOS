enum DesertTycoonPhase: CaseIterable {
    case phaseOne
    case phaseTwo
    case phaseThree

    var mapCandidates: [String] {
        switch self {
        case .phaseOne:
            return [
                "GeneratedMaps/DT_Phase1_ortho_full.png",
                "iphone-hd-upscaled/maps/DT_Phase1_ortho_full.png",
                "iphone-hd/maps/DT_Phase1_ortho.png",
                "preview_phase1_map.png"
            ]
        case .phaseTwo:
            return [
                "GeneratedMaps/DT_Phase2_ortho_full.png",
                "iphone-hd-upscaled/maps/DT_Phase2_ortho_full.png",
                "iphone-hd/maps/DT_Phase2_ortho.png",
                "preview_phase2_map.png"
            ]
        case .phaseThree:
            return [
                "GeneratedMaps/DT_Phase3_ortho_full.png",
                "iphone-hd-upscaled/maps/DT_Phase3_ortho_full.png",
                "iphone-hd/maps/DT_Phase3_ortho.png",
                "preview_phase3_map.png"
            ]
        }
    }
}
