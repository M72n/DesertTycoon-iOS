import CoreGraphics
import Foundation

enum DesertTycoonPhase: CaseIterable {
    case phaseOne
    case phaseTwo
    case phaseThree

    var mapCandidates: [String] {
        switch self {
        case .phaseOne:
            return [
                "GeneratedMaps/DT_Phase1_iso_full.png",
                "GeneratedMaps/DT_Phase1_ortho_full.png",
                "iphone-hd-upscaled/maps/DT_Phase1_ortho_full.png",
                "iphone-hd/maps/DT_Phase1_ortho.png",
                "preview_phase1_map.png"
            ]
        case .phaseTwo:
            return [
                "GeneratedMaps/DT_Phase2_iso_full.png",
                "GeneratedMaps/DT_Phase2_ortho_full.png",
                "iphone-hd-upscaled/maps/DT_Phase2_ortho_full.png",
                "iphone-hd/maps/DT_Phase2_ortho.png",
                "preview_phase2_map.png"
            ]
        case .phaseThree:
            return [
                "GeneratedMaps/DT_Phase3_iso_full.png",
                "GeneratedMaps/DT_Phase3_ortho_full.png",
                "iphone-hd-upscaled/maps/DT_Phase3_ortho_full.png",
                "iphone-hd/maps/DT_Phase3_ortho.png",
                "preview_phase3_map.png"
            ]
        }
    }

    var mapColumns: Int { 100 }
    var mapRows: Int { 100 }

    var tileSize: CGSize {
        switch self {
        case .phaseOne:
            return CGSize(width: 64, height: 32)
        case .phaseTwo, .phaseThree:
            return CGSize(width: 32, height: 16)
        }
    }
}

enum DesertTycoonResource: String, CaseIterable {
    case coins
    case dinars
    case energy
    case goods
    case oil
    case population

    var iconFrame: String {
        switch self {
        case .coins:
            return "main_screen_ui/bottom_bar/coins_symbol.png"
        case .dinars:
            return "main_screen_ui/bottom_bar/dinars_symbol.png"
        case .energy:
            return "main_screen_ui/bottom_bar/energy_symbol.png"
        case .goods:
            return "main_screen_ui/bottom_bar/goods_symbol.png"
        case .oil:
            return "main_screen_ui/bottom_bar/oil_symbol.png"
        case .population:
            return "souk_screen/icon_population.png"
        }
    }
}

struct DesertTycoonResources {
    var coins = 1200
    var dinars = 25
    var energy = 20
    var goods = 0
    var oil = 0
    var population = 0

    func value(for resource: DesertTycoonResource) -> Int {
        switch resource {
        case .coins:
            return coins
        case .dinars:
            return dinars
        case .energy:
            return energy
        case .goods:
            return goods
        case .oil:
            return oil
        case .population:
            return population
        }
    }

    mutating func add(_ amount: Int, to resource: DesertTycoonResource) {
        switch resource {
        case .coins:
            coins += amount
        case .dinars:
            dinars += amount
        case .energy:
            energy += amount
        case .goods:
            goods += amount
        case .oil:
            oil += amount
        case .population:
            population += amount
        }
    }

    mutating func spendCoins(_ amount: Int) -> Bool {
        guard coins >= amount else { return false }
        coins -= amount
        return true
    }
}

enum DesertTycoonBuildType: String, CaseIterable {
    case residential
    case business
    case community
    case farm
    case energy
    case oil

    var iconFrame: String {
        switch self {
        case .residential:
            return "souk_screen/icons/ResidentialIcon.png"
        case .business:
            return "souk_screen/icons/BusinessIcon.png"
        case .community:
            return "souk_screen/icons/CommunityIcon.png"
        case .farm:
            return "souk_screen/icons/FarmIcon.png"
        case .energy:
            return "souk_screen/icons/EnergyIcon.png"
        case .oil:
            return "souk_screen/icons/OilIcon.png"
        }
    }

    var cost: Int {
        switch self {
        case .residential:
            return 80
        case .business:
            return 120
        case .community:
            return 100
        case .farm:
            return 70
        case .energy:
            return 90
        case .oil:
            return 180
        }
    }

    var productionResource: DesertTycoonResource {
        switch self {
        case .residential:
            return .population
        case .business, .community:
            return .coins
        case .farm:
            return .goods
        case .energy:
            return .energy
        case .oil:
            return .oil
        }
    }

    var productionAmount: Int {
        switch self {
        case .residential:
            return 2
        case .business:
            return 35
        case .community:
            return 20
        case .farm:
            return 12
        case .energy:
            return 8
        case .oil:
            return 6
        }
    }

    var buildDuration: TimeInterval {
        switch self {
        case .oil:
            return 5.0
        default:
            return 3.0
        }
    }

    var productionInterval: TimeInterval {
        switch self {
        case .residential:
            return 12.0
        case .business:
            return 9.0
        case .community:
            return 11.0
        case .farm:
            return 7.0
        case .energy:
            return 10.0
        case .oil:
            return 13.0
        }
    }

    var bubbleFrame: String {
        switch productionResource {
        case .coins:
            return "status_baloons/Coin_Bubble.png"
        case .energy:
            return "status_baloons/green_light_bubble.png"
        case .goods:
            return "status_baloons/Goods_Bubble.png"
        case .oil:
            return "status_baloons/oil_bubble.png"
        case .population:
            return "status_baloons/House_Visit_Bubble.png"
        case .dinars:
            return "status_baloons/Coin_Bubble.png"
        }
    }
}
