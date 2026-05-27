import Foundation

struct SeedExerciseData: Codable, Sendable {
    let id: String
    let name: String
    let description: String
    let equipmentType: String
    let isSingleHand: Bool
    let muscleGroups: [String]
    let iconName: String
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
        guard let url = bundle.url(forResource: "ForgeExercises", withExtension: "json") else {
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
