import Foundation

struct SeedExerciseData: Codable, Sendable {
    let id: String
    let name: String
    let description: String
    let equipmentType: String
    let isSingleHand: Bool
    let muscleGroups: [String]
    let iconName: String
    let defaultLoggingType: String?

    init(
        id: String,
        name: String,
        description: String,
        equipmentType: String,
        isSingleHand: Bool,
        muscleGroups: [String],
        iconName: String,
        defaultLoggingType: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.equipmentType = equipmentType
        self.isSingleHand = isSingleHand
        self.muscleGroups = muscleGroups
        self.iconName = iconName
        self.defaultLoggingType = defaultLoggingType
    }
}

private struct SeedDataFile: Codable {
    let exercises: [SeedExerciseData]
}

enum SeedDataError: Error, Equatable {
    case fileNotFound
    case decodingFailed(String)
}

struct SeedDataService: Sendable {
    static func loadExercises(from bundle: Bundle = .main) throws -> [SeedExerciseData] {
        guard let url = bundle.url(forResource: "IroniqExercises", withExtension: "json") else {
            throw SeedDataError.fileNotFound
        }
        do {
            let data = try Data(contentsOf: url)
            let file = try JSONDecoder().decode(SeedDataFile.self, from: data)
            return file.exercises
        } catch let error as DecodingError {
            throw SeedDataError.decodingFailed(error.localizedDescription)
        }
    }
}
