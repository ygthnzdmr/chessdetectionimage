import Foundation

/// The response for the /progress endpoint.
struct ProgressResponse: Decodable {
    let current: Int
    let total: Int
    let running: Bool
    let trained: Bool
    let run_id: Int
}

/// The response for the /predict endpoint.
struct PredictResponse: Codable {
    let label: String
    let confidence: Double
    let additionalInfo: String?
}
