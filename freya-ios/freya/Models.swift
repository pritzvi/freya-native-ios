import Foundation

// Skin score model for the Home header
struct SkinScore: Codable, Equatable {
    let overall: Int
    let subscores: Subscores
    let createdAt: Date?
}

struct Subscores: Codable, Equatable {
    let barrierHydration: Int
    let complexion: Int
    let acneTexture: Int
    let fineLines: Int
    let eyes: Int
}

// Routine structures for sectioned AM/PM lists
struct RoutineStep: Identifiable, Hashable {
    let id: String              // stepId or slotId
    let section: String         // "AM" or "PM"
    let stepName: String        // Cleanser, Serum, etc.
    let productName: String?
    let brand: String?
    let imageUrl: URL?
}

struct RoutineSection: Identifiable, Equatable {
    let id: String              // "AM" / "PM"
    let title: String
    let steps: [RoutineStep]
}

// Recent score list item for history chips
struct ScoreListItem: Identifiable, Equatable {
    let id: String            // scoreId
    let overall: Int
    let createdAt: Date?
    let subscores: Subscores
}


