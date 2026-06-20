import Foundation

struct DTStartingState: Codable {
    var level: Int
    var coins: Int
    var cash: Int
    var energy: Int
    var goods: Int
    var goodsCapacity: Int
    var populationCapacity: Int
    var availableWorkers: Int
}

struct DTCropDefinition: Codable, Equatable {
    var id: String
    var name: String
    var unlockLevel: Int
    var coinCost: Int
    var yieldGoods: Int
    var growSeconds: TimeInterval
}

struct DTRawBuildingDefinition: Codable {
    var id: String
    var name: String
    var unlockLevel: Int? = nil
    var coinCost: Int? = nil
    var coinCostObserved: Int? = nil
    var cashCost: Int? = nil
    var requiredWorkers: Int? = nil
    var goodsRequired: Int? = nil
    var workSeconds: TimeInterval? = nil
    var rewardCoins: Int? = nil
    var rewardPoints: Int? = nil
    var populationBonus: Int? = nil
    var goodsCapacityBonus: Int? = nil
    var housingLimitBonus: Int? = nil
}

struct DTBuildingCatalog: Codable {
    var housing: [DTRawBuildingDefinition]
    var farming: [DTRawBuildingDefinition]
    var business: [DTRawBuildingDefinition]
    var community: [DTRawBuildingDefinition]
    var expansion: [DTRawBuildingDefinition]
}

struct DTReward: Codable, Equatable {
    var coins: Int? = nil
    var cash: Int? = nil
    var energy: Int? = nil
    var goods: Int? = nil
    var points: Int? = nil
}

struct DTGoalStepDefinition: Codable, Equatable {
    var type: String
    var target: String
    var label: String?

    var eventKey: String {
        "\(type):\(target)"
    }
}

struct DTGoalDefinition: Codable, Equatable {
    var id: String
    var title: String
    var steps: [DTGoalStepDefinition]
    var reward: DTReward?
}

struct DTSpec: Codable {
    var startingState: DTStartingState
    var crops: [DTCropDefinition]
    var buildings: DTBuildingCatalog
    var storeCategories: [String]
    var goals: [DTGoalDefinition]

    enum CodingKeys: String, CodingKey {
        case startingState = "starting_state"
        case crops
        case buildings
        case storeCategories = "store_categories"
        case goals
    }
}

struct DTStoreItem: Equatable {
    enum Kind: String, Codable, Equatable {
        case building
        case crop
        case mock
    }

    var id: String
    var name: String
    var category: String
    var kind: Kind
    var unlockLevel: Int
    var coinCost: Int
    var cashCost: Int
    var requiredWorkers: Int
    var goodsRequired: Int
    var workSeconds: TimeInterval
    var rewardCoins: Int
    var rewardPoints: Int
    var populationBonus: Int
    var goodsCapacityBonus: Int
    var housingLimitBonus: Int

    init(raw: DTRawBuildingDefinition, category: String) {
        id = raw.id
        name = raw.name
        self.category = category
        kind = .building
        unlockLevel = raw.unlockLevel ?? 1
        coinCost = raw.coinCost ?? raw.coinCostObserved ?? 0
        cashCost = raw.cashCost ?? 0
        requiredWorkers = raw.requiredWorkers ?? 0
        goodsRequired = raw.goodsRequired ?? 0
        workSeconds = raw.workSeconds ?? 0
        rewardCoins = raw.rewardCoins ?? 0
        rewardPoints = raw.rewardPoints ?? 0
        populationBonus = raw.populationBonus ?? 0
        goodsCapacityBonus = raw.goodsCapacityBonus ?? 0
        housingLimitBonus = raw.housingLimitBonus ?? 0
    }

    init(crop: DTCropDefinition) {
        id = crop.id
        name = crop.name
        category = "Farming"
        kind = .crop
        unlockLevel = crop.unlockLevel
        coinCost = crop.coinCost
        cashCost = 0
        requiredWorkers = 0
        goodsRequired = 0
        workSeconds = crop.growSeconds
        rewardCoins = 0
        rewardPoints = max(1, crop.yieldGoods / 10)
        populationBonus = 0
        goodsCapacityBonus = 0
        housingLimitBonus = 0
    }

    init(id: String, name: String, category: String, cashCost: Int = 0, coinCost: Int = 0) {
        self.id = id
        self.name = name
        self.category = category
        kind = .mock
        unlockLevel = 1
        self.coinCost = coinCost
        self.cashCost = cashCost
        requiredWorkers = 0
        goodsRequired = 0
        workSeconds = 0
        rewardCoins = 0
        rewardPoints = 0
        populationBonus = 0
        goodsCapacityBonus = 0
        housingLimitBonus = 0
    }

    func isLocked(at level: Int) -> Bool {
        level < unlockLevel
    }
}

struct DesertTycoonGameData {
    let spec: DTSpec
    let buildingItems: [DTStoreItem]
    let storeItems: [DTStoreItem]
    let levelThresholds = [0, 20, 60, 130, 250, 420, 650, 950]

    @MainActor
    static func load() -> DesertTycoonGameData {
        if let url = BundleAssetResolver.url(candidates: ["GameData/desert_tycoon_spec.json"]),
           let data = try? Data(contentsOf: url),
           let spec = try? JSONDecoder().decode(DTSpec.self, from: data) {
            return DesertTycoonGameData(spec: spec)
        }

        return DesertTycoonGameData(spec: .fallback)
    }

    init(spec: DTSpec) {
        self.spec = spec

        var buildings: [DTStoreItem] = []
        buildings += spec.buildings.housing.map { DTStoreItem(raw: $0, category: "Housing") }
        buildings += spec.buildings.business.map { DTStoreItem(raw: $0, category: "Business") }
        buildings += spec.buildings.farming.map { DTStoreItem(raw: $0, category: "Farming") }
        buildings += spec.buildings.community.map { DTStoreItem(raw: $0, category: "Community") }
        buildings += spec.buildings.expansion.map { DTStoreItem(raw: $0, category: "Expansion") }
        buildingItems = buildings

        let mockItems = [
            DTStoreItem(id: "reward_video", name: "شاهد فيديو", category: "Video"),
            DTStoreItem(id: "energy_5", name: "+5 طاقة", category: "Energy", cashCost: 8),
            DTStoreItem(id: "energy_10", name: "+10 طاقة", category: "Energy", cashCost: 15),
            DTStoreItem(id: "coins_5000", name: "5000 عملات", category: "Currency", cashCost: 10),
            DTStoreItem(id: "dinars_10", name: "10 دنانير", category: "Currency")
        ]
        storeItems = buildings + mockItems
    }

    func item(id: String) -> DTStoreItem? {
        storeItems.first { $0.id == id }
    }

    func crop(id: String) -> DTCropDefinition? {
        spec.crops.first { $0.id == id }
    }

    func items(in category: String, level: Int) -> [DTStoreItem] {
        if category == "New" {
            return storeItems
                .filter { $0.unlockLevel <= level && $0.unlockLevel >= max(1, level - 1) }
                .sorted { $0.unlockLevel < $1.unlockLevel }
        }

        return storeItems.filter { $0.category == category }
    }

    func level(for points: Int) -> Int {
        var level = 1
        for (index, threshold) in levelThresholds.enumerated() where points >= threshold {
            level = max(1, index + 1)
        }
        return level
    }
}

extension DTSpec {
    static let fallback = DTSpec(
        startingState: DTStartingState(
            level: 1,
            coins: 1000,
            cash: 10,
            energy: 5,
            goods: 0,
            goodsCapacity: 25,
            populationCapacity: 1,
            availableWorkers: 1
        ),
        crops: [
            DTCropDefinition(id: "dates", name: "تمر", unlockLevel: 1, coinCost: 10, yieldGoods: 10, growSeconds: 30),
            DTCropDefinition(id: "cucumbers", name: "خيار", unlockLevel: 3, coinCost: 15, yieldGoods: 20, growSeconds: 60),
            DTCropDefinition(id: "okra", name: "بامية", unlockLevel: 4, coinCost: 25, yieldGoods: 35, growSeconds: 300),
            DTCropDefinition(id: "tomatoes", name: "طماطم", unlockLevel: 7, coinCost: 45, yieldGoods: 70, growSeconds: 600)
        ],
        buildings: DTBuildingCatalog(
            housing: [
                DTRawBuildingDefinition(id: "small_tent", name: "خيمة صغيرة", unlockLevel: 1, coinCost: 150, populationBonus: 1),
                DTRawBuildingDefinition(id: "small_hut", name: "كوخ صغير", unlockLevel: 5, coinCost: 290, populationBonus: 2)
            ],
            farming: [
                DTRawBuildingDefinition(id: "farm_plot", name: "أرض زراعة", unlockLevel: 1, coinCost: 100),
                DTRawBuildingDefinition(id: "small_silo", name: "صومعة صغيرة", unlockLevel: 1, coinCost: 500, goodsCapacityBonus: 25)
            ],
            business: [
                DTRawBuildingDefinition(id: "vegetable_kiosk", name: "كشك خضار", unlockLevel: 1, coinCost: 100, requiredWorkers: 1, goodsRequired: 10, workSeconds: 30, rewardCoins: 15, rewardPoints: 1),
                DTRawBuildingDefinition(id: "bakery", name: "مخبز", unlockLevel: 5, coinCost: 300, requiredWorkers: 1, goodsRequired: 35, workSeconds: 90, rewardCoins: 55, rewardPoints: 2)
            ],
            community: [
                DTRawBuildingDefinition(id: "water_well", name: "بئر ماء", unlockLevel: 1, coinCost: 350, housingLimitBonus: 5),
                DTRawBuildingDefinition(id: "road", name: "طريق", unlockLevel: 1, coinCost: 10)
            ],
            expansion: [
                DTRawBuildingDefinition(id: "coin_expansion", name: "توسعة بالعملات", unlockLevel: 1, coinCost: 5000)
            ]
        ),
        storeCategories: ["New", "Video", "Housing", "Business", "Farming", "Community", "Expansion", "Energy", "Currency"],
        goals: [
            DTGoalDefinition(id: "move_visitor_into_tent", title: "مهمة السكن", steps: [DTGoalStepDefinition(type: "assign_neighbor", target: "starting_tent", label: "انقل جارًا إلى الخيمة")], reward: DTReward(coins: 0, cash: nil, energy: nil, goods: nil, points: nil)),
            DTGoalDefinition(id: "first_farm", title: "مهمة الزراعة", steps: [DTGoalStepDefinition(type: "build", target: "farm_plot", label: "ابنِ أرض زراعة"), DTGoalStepDefinition(type: "harvest_crop", target: "dates", label: "ازرع واحصد التمر")], reward: DTReward(coins: 25, cash: nil, energy: nil, goods: nil, points: nil))
        ]
    )
}
