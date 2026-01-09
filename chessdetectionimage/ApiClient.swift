import Foundation
import UIKit

final class ApiClient {
    static let shared = ApiClient()
    private init() {}

    private let base = URL(string: "https://projectgit-production.up.railway.app")!

    func fetchProgress() async throws -> ProgressResponse {
        let url = base.appendingPathComponent("progress")
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(ProgressResponse.self, from: data)
    }

    func startTraining(epochs: Int) async throws {
        let url = base.appendingPathComponent("train")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = "epochs=\(epochs)"
        req.httpBody = body.data(using: .utf8)

        let (_, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    func predict(imageData: Data) async throws -> PredictResponse {
        let url = base.appendingPathComponent("predict")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"

        let boundary = UUID().uuidString
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let fieldName = "image"
        let fileName = "photo.jpg"
        let mimeType = "image/jpeg"

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        let (data, response) = try await URLSession.shared.upload(for: req, from: body)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(PredictResponse.self, from: data)
    }

    /// Uploads to root ("/") endpoint as multipart/form-data and follows the server redirect
    /// to extract `res` and `conf` query parameters. Returns a PredictResponse-like model.
    func uploadToRootForm(imageData: Data) async throws -> PredictResponse {
        var req = URLRequest(url: base)
        req.httpMethod = "POST"

        let boundary = UUID().uuidString
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let fieldName = "image"
        let fileName = "photo.jpg"
        let mimeType = "image/jpeg"

        print("[Upload] Preparing form field 'image' with size: \(imageData.count) bytes")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        // Use data(for:) to upload and get response HTML directly
        let (data, response) = try await URLSession.shared.data(for: req, delegate: nil)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        print("[Upload] Status:", http.statusCode)
        print("[Upload] Final URL:", http.url?.absoluteString ?? "nil")

        // Parse POST response HTML directly
        if let html = String(data: data, encoding: .utf8) {
            let norm = html
                .replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\r", with: "\n")
                .replacingOccurrences(of: "\t", with: " ")
                .replacingOccurrences(of: "  ", with: " ")

            func parse(from source: String) -> (res: String, conf: Double, img: String?) {
                let resultBlock = Self.firstMatch(in: source, pattern: "<div\\s+class=\\\"result\\\">([\\s\\S]*?)</div>")
                let confidenceBlock = Self.firstMatch(in: source, pattern: "<div\\s+class=\\\"confidence\\\">([\\s\\S]*?)</div>")
                let previewBlock = Self.firstMatch(in: source, pattern: "<div\\s+class=\\\"preview\\\">([\\s\\S]*?)</div>")

                var res = ""
                if let resultBlock {
                    res = Self.firstMatch(in: resultBlock, pattern: "Tahmin\\s*:\\s*([^<]+)")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                }

                var conf: Double = 0.0
                if let confidenceBlock {
                    let raw = Self.firstMatch(in: confidenceBlock, pattern: "Güven\\s*:\\s*%?([0-9]+(?:[.,][0-9]+)?)") ?? ""
                    conf = Double(raw.replacingOccurrences(of: ",", with: ".")) ?? 0.0
                }

                var absoluteImg: String? = nil
                if let previewBlock, let src = Self.firstMatch(in: previewBlock, pattern: "<img[^>]*src=\\\"([^\\\"]+)\\\"") {
                    if src.lowercased().hasPrefix("http") {
                        absoluteImg = src
                    } else {
                        var comps = URLComponents(url: base, resolvingAgainstBaseURL: false)
                        comps?.path = src.hasPrefix("/") ? src : "/" + src
                        absoluteImg = comps?.url?.absoluteString
                    }
                }
                return (res, conf, absoluteImg)
            }

            var parsed = parse(from: html)
            if parsed.res.isEmpty && parsed.img == nil {
                parsed = parse(from: norm)
            }
            if parsed.res.isEmpty {
                if let r = Self.firstMatch(in: norm, pattern: "Tahmin\\s*:\\s*([^<\\n]+)")?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    parsed.res = r
                }
            }
            if parsed.conf == 0.0 {
                if let raw = Self.firstMatch(in: norm, pattern: "Güven\\s*:\\s*%?([0-9]+(?:[.,][0-9]+)?)") {
                    parsed.conf = Double(raw.replacingOccurrences(of: ",", with: ".")) ?? 0.0
                }
            }
            if parsed.img == nil {
                if let src = Self.firstMatch(in: norm, pattern: "<img[^>]*src=\\\"(/static/uploads/[^\\\"]+)\\\"") ?? Self.firstMatch(in: norm, pattern: "<img[^>]*src=\\\"(/static/[^\\\"]+)\\\"") {
                    var comps = URLComponents(url: base, resolvingAgainstBaseURL: false)
                    comps?.path = src
                    parsed.img = comps?.url?.absoluteString
                }
            }

            print("[Upload][HTML] Parsed res=\(parsed.res), conf=\(parsed.conf), img=\(parsed.img ?? "nil")")
            if !parsed.res.isEmpty || parsed.img != nil {
                return PredictResponse(label: parsed.res, confidence: parsed.conf, additionalInfo: parsed.img)
            }
        }

        throw URLError(.cannotParseResponse)
    }

    /// Posts image to root ("/") then performs a GET to fetch HTML and parse result/confidence/preview.
    func postThenGet(imageData: Data) async throws -> PredictResponse {
        // 1) POST upload
        var postReq = URLRequest(url: base)
        postReq.httpMethod = "POST"

        let boundary = UUID().uuidString
        postReq.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let fieldName = "image"
        let fileName = "photo.jpg"
        let mimeType = "image/jpeg"

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        print("[POST-GET] Uploading 'image' size: \(imageData.count) bytes to \(base)")
        _ = try await URLSession.shared.upload(for: postReq, from: body)

        // 2) GET fetch
        var getReq = URLRequest(url: base)
        getReq.httpMethod = "GET"
        let (data, response) = try await URLSession.shared.data(for: getReq)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        print("[POST-GET] GET Status: \(http.statusCode)")

        guard let html = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeRawData)
        }
        let snippet = String(html.prefix(500))
        print("[POST-GET][HTML] Snippet:\n\(snippet)\n---")

        // Normalize HTML for robust matching
        let norm = html
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "  ", with: " ")

        func parse(from source: String) -> (res: String, conf: Double, img: String?) {
            let resultBlock = Self.firstMatch(in: source, pattern: "<div\\s+class=\\\"result\\\">([\\s\\S]*?)</div>")
            let confidenceBlock = Self.firstMatch(in: source, pattern: "<div\\s+class=\\\"confidence\\\">([\\s\\S]*?)</div>")
            let previewBlock = Self.firstMatch(in: source, pattern: "<div\\s+class=\\\"preview\\\">([\\s\\S]*?)</div>")

            var res = ""
            if let resultBlock {
                res = Self.firstMatch(in: resultBlock, pattern: "Tahmin\\s*:\\s*([^<]+)")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            }

            var conf: Double = 0.0
            if let confidenceBlock {
                let raw = Self.firstMatch(in: confidenceBlock, pattern: "Güven\\s*:\\s*%?([0-9]+(?:[.,][0-9]+)?)") ?? ""
                conf = Double(raw.replacingOccurrences(of: ",", with: ".")) ?? 0.0
            }

            var absoluteImg: String? = nil
            if let previewBlock, let src = Self.firstMatch(in: previewBlock, pattern: "<img[^>]*src=\\\"([^\\\"]+)\\\"") {
                if src.lowercased().hasPrefix("http") {
                    absoluteImg = src
                } else {
                    var comps = URLComponents(url: base, resolvingAgainstBaseURL: false)
                    comps?.path = src.hasPrefix("/") ? src : "/" + src
                    absoluteImg = comps?.url?.absoluteString
                }
            }
            return (res, conf, absoluteImg)
        }

        // Try original HTML first
        var parsed = parse(from: html)
        // If not found, try normalized HTML
        if parsed.res.isEmpty && parsed.img == nil {
            parsed = parse(from: norm)
        }
        // Fallback: search across full normalized HTML without scoping to blocks
        if parsed.res.isEmpty {
            if let r = Self.firstMatch(in: norm, pattern: "Tahmin\\s*:\\s*([^<\\n]+)")?.trimmingCharacters(in: .whitespacesAndNewlines) {
                parsed.res = r
            }
        }
        if parsed.conf == 0.0 {
            if let raw = Self.firstMatch(in: norm, pattern: "Güven\\s*:\\s*%?([0-9]+(?:[.,][0-9]+)?)") {
                parsed.conf = Double(raw.replacingOccurrences(of: ",", with: ".")) ?? 0.0
            }
        }
        if parsed.img == nil {
            if let src = Self.firstMatch(in: norm, pattern: "<img[^>]*src=\\\"(/static/uploads/[^\\\"]+)\\\"") ?? Self.firstMatch(in: norm, pattern: "<img[^>]*src=\\\"(/static/[^\\\"]+)\\\"") {
                var comps = URLComponents(url: base, resolvingAgainstBaseURL: false)
                comps?.path = src
                parsed.img = comps?.url?.absoluteString
            }
        }

        print("[POST-GET][HTML] Parsed res=\(parsed.res), conf=\(parsed.conf), img=\(parsed.img ?? "nil")")
        if parsed.res.isEmpty && parsed.img == nil {
            throw URLError(.cannotParseResponse)
        }
        return PredictResponse(label: parsed.res, confidence: parsed.conf, additionalInfo: parsed.img)
    }

    private static func extractValue(in text: String, keys: [String]) -> String? {
        for key in keys {
            // Look for key=value or key\":\"value\" patterns
            if let range = text.range(of: "\(key)=") {
                let substring = text[range.upperBound...]
                if let end = substring.firstIndex(of: "&") ?? substring.firstIndex(of: "\"") ?? substring.firstIndex(of: "<") {
                    let value = substring[..<end]
                    return String(value)
                } else {
                    return String(substring)
                }
            }
            if let range = text.range(of: "\"\(key)\"\\s*:\\s*\"") {
                let substring = text[range.upperBound...]
                if let end = substring.firstIndex(of: "\"") {
                    let value = substring[..<end]
                    return String(value)
                }
            }
        }
        return nil
    }

    private static func firstMatch(in text: String, pattern: String) -> String? {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
            let nsrange = NSRange(text.startIndex..<text.endIndex, in: text)
            if let match = regex.firstMatch(in: text, options: [], range: nsrange), match.numberOfRanges >= 2,
               let range = Range(match.range(at: 1), in: text) {
                return String(text[range])
            }
        } catch {
            return nil
        }
        return nil
    }
}

