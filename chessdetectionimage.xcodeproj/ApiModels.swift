import Foundation

struct ProgressResponse: Decodable {
    let current: Int
    let total: Int
    let running: Bool
    let trained: Bool
    let run_id: Int
}

struct PredictResponse: Decodable {
    let label: String
    let confidence: Double
}
