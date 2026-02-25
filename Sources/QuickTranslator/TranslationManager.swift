import Observation
import AppKit
import Foundation

@MainActor
@Observable
class TranslationManager {
    private struct GeminiRequest: Codable {
        struct Content: Codable { let role: String; let parts: [Part] }
        struct Part: Codable { let text: String }
        let contents: [Content]
    }

    private struct GeminiResponse: Codable {
        struct Candidate: Codable { let content: Content? }
        struct Content: Codable { let parts: [Part]? }
        struct Part: Codable { let text: String? }
        let candidates: [Candidate]?
    }

    private struct ListModelsResponse: Codable {
        struct Model: Codable { let name: String? }
        let models: [Model]?
    }

    var sourceText: String = ""
    var translatedText: String = ""
    var isTranslating: Bool = false
    
    // API Key Placeholder - User needs to replace this
    private let apiKey = "AIzaSyDHwLVFFWiRhXgHIwPb6e5RgxCcoontGDI"
    
    // Preferred model name; update as needed. If unavailable, we fall back.
    private var modelName: String = "gemini-3-flash"
    private let apiVersionPath: String = "v1" // use v1 for broad availability
    
    // Cache the resolved latest model to avoid listing every time
    private var resolvedModelName: String?

    private func resolveLatestModelName(preferredFamily: String = "flash") async -> String {
        if let cached = resolvedModelName { return cached }
        // Try List Models
        guard let url = URL(string: "https://generativelanguage.googleapis.com/\(apiVersionPath)/models?key=\(self.apiKey)") else {
            return modelName
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                return modelName
            }
            let decoded = try JSONDecoder().decode(ListModelsResponse.self, from: data)
            let names = (decoded.models ?? []).compactMap { $0.name }
            // Filter to models that include the preferred family (e.g., flash) and support generateContent aliases (heuristic: contain "gemini" and family)
            let candidates = names.filter { name in
                name.contains("gemini") && name.contains(preferredFamily)
            }
            // Prefer explicit "-latest" aliases first
            if let latestAlias = candidates.first(where: { $0.hasSuffix("-latest") }) {
                resolvedModelName = latestAlias.replacingOccurrences(of: "models/", with: "")
                return resolvedModelName!
            }
            // Otherwise, sort by a semantic-like descending order heuristic (numbers within the name)
            let sorted = candidates.sorted { a, b in
                // Extract numeric tokens (e.g., 1.5, 2.0, 3.0)
                func version(_ s: String) -> [Int] {
                    let comps = s.replacingOccurrences(of: "models/", with: "").components(separatedBy: CharacterSet(charactersIn: "-._"))
                    var nums: [Int] = []
                    for c in comps {
                        if let v = Int(c) { nums.append(v) }
                    }
                    return nums
                }
                let va = version(a)
                let vb = version(b)
                return va.lexicographicallyPrecedes(vb) == false
            }
            if let top = sorted.first {
                resolvedModelName = top.replacingOccurrences(of: "models/", with: "")
                return resolvedModelName!
            }
            return modelName
        } catch {
            return modelName
        }
    }
    
    func translateCopiedText() {
        print("DEBUG: translateCopiedText called (Gemini)")
        let pasteboard = NSPasteboard.general
        if let clipboardString = pasteboard.string(forType: .string) {
            print("DEBUG: Clipboard Content: \(clipboardString)")
            sourceText = clipboardString
            isTranslating = true
            translatedText = ""
            
            Task {
                do {
                    print("DEBUG: Requesting translation from Gemini via REST...")
                    // Resolve latest available model name (cached)
                    self.modelName = await resolveLatestModelName(preferredFamily: "flash")
                    // Build REST request to Gemini API
                    var base = "https://generativelanguage.googleapis.com/\(apiVersionPath)/models/\(modelName):generateContent"
                    guard let url = URL(string: base + "?key=\(self.apiKey)") else {
                        throw URLError(.badURL)
                    }

                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                    let prompt = "Translate the following text to English (US). Only provide the translation, no explanations:\n\n\(clipboardString)"
                    let payload = GeminiRequest(
                        contents: [
                            .init(role: "user", parts: [.init(text: prompt)])
                        ]
                    )

                    let encoder = JSONEncoder()
                    request.httpBody = try encoder.encode(payload)

                    func performRequest(_ request: URLRequest) async throws -> GeminiResponse {
                        let (data, response) = try await URLSession.shared.data(for: request)
                        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                            let body = String(data: data, encoding: .utf8) ?? "<no body>"
                            throw NSError(domain: "GeminiHTTP", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode): \(body)"])
                        }
                        let decoder = JSONDecoder()
                        return try decoder.decode(GeminiResponse.self, from: data)
                    }

                    var gemini: GeminiResponse
                    do {
                        gemini = try await performRequest(request)
                    } catch let error as NSError where error.domain == "GeminiHTTP" && error.code == 404 {
                        print("DEBUG: Model not found at \(apiVersionPath)/\(modelName). Falling back to gemini-3-flash on v1...")
                        // Fallback to a broadly available model
                        self.modelName = "gemini-3-flash"
                        base = "https://generativelanguage.googleapis.com/\(apiVersionPath)/models/\(self.modelName):generateContent"
                        guard let fallbackURL = URL(string: base + "?key=\(self.apiKey)") else { throw URLError(.badURL) }
                        var fallbackRequest = URLRequest(url: fallbackURL)
                        fallbackRequest.httpMethod = "POST"
                        fallbackRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                        fallbackRequest.httpBody = request.httpBody
                        gemini = try await performRequest(fallbackRequest)
                    }

                    if let text = gemini.candidates?.first?.content?.parts?.first?.text, !text.isEmpty {
                        print("DEBUG: Gemini Translation received: \(text)")
                        self.translatedText = text
                    } else {
                        print("DEBUG ERROR: Gemini returned empty response")
                        self.translatedText = "Error: Empty response from Gemini."
                    }
                    self.isTranslating = false
                } catch {
                    print("DEBUG ERROR: Gemini translation failed: \(error.localizedDescription)")
                    self.translatedText = "Translation failed: \(error.localizedDescription)"
                    self.isTranslating = false
                }
            }
        } else {
            print("DEBUG ERROR: No text found on clipboard.")
            translatedText = "Error: No text found on clipboard."
            isTranslating = false
        }
    }
}

