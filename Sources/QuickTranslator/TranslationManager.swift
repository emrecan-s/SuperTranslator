import Observation
import AppKit
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.emre.SuperTranslator", category: "Translation")

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

    // API key is stored in UserDefaults — never hardcoded.
    // Set via the settings UI in ContentView.
    static let apiKeyDefaultsKey = "gemini_api_key"

    var apiKey: String {
        get { UserDefaults.standard.string(forKey: Self.apiKeyDefaultsKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: Self.apiKeyDefaultsKey) }
    }

    var hasApiKey: Bool { !apiKey.isEmpty }

    // Model auto-resolved at runtime to the latest available flash-lite variant.
    private var modelName: String = "gemini-2.5-flash-lite"
    private let apiVersionPath: String = "v1"

    // Cache the resolved model name to avoid listing on every call.
    private var resolvedModelName: String?

    private func resolveLatestModelName(preferredFamily: String = "flash-lite") async -> String {
        if let cached = resolvedModelName { return cached }
        guard let url = URL(string: "https://generativelanguage.googleapis.com/\(apiVersionPath)/models?key=\(apiKey)") else {
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
            let candidates = names.filter { $0.contains("gemini") && $0.contains(preferredFamily) }

            if let latestAlias = candidates.first(where: { $0.hasSuffix("-latest") }) {
                resolvedModelName = latestAlias.replacingOccurrences(of: "models/", with: "")
                return resolvedModelName!
            }
            let sorted = candidates.sorted { a, b in
                func version(_ s: String) -> [Int] {
                    s.replacingOccurrences(of: "models/", with: "")
                        .components(separatedBy: CharacterSet(charactersIn: "-._"))
                        .compactMap(Int.init)
                }
                return version(a).lexicographicallyPrecedes(version(b)) == false
            }
            if let top = sorted.first {
                resolvedModelName = top.replacingOccurrences(of: "models/", with: "")
                return resolvedModelName!
            }
            return modelName
        } catch {
            logger.warning("Model resolution failed, using default: \(error.localizedDescription)")
            return modelName
        }
    }

    func translateCopiedText() {
        guard hasApiKey else {
            translatedText = "⚠️ No API key set. Open the menu bar icon and add your Gemini API key in Settings."
            return
        }

        let pasteboard = NSPasteboard.general
        guard let clipboardString = pasteboard.string(forType: .string), !clipboardString.isEmpty else {
            translatedText = "Error: No text found on clipboard."
            isTranslating = false
            return
        }

        sourceText = clipboardString
        isTranslating = true
        translatedText = ""

        Task {
            do {
                self.modelName = await resolveLatestModelName(preferredFamily: "flash-lite")
                logger.info("Requesting translation via \(self.modelName)")

                var base = "https://generativelanguage.googleapis.com/\(apiVersionPath)/models/\(modelName):generateContent"
                guard let url = URL(string: base + "?key=\(self.apiKey)") else {
                    throw URLError(.badURL)
                }

                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                let prompt = "Translate the following text to English (US). Only provide the translation, no explanations:\n\n\(clipboardString)"
                let payload = GeminiRequest(
                    contents: [.init(role: "user", parts: [.init(text: prompt)])]
                )
                request.httpBody = try JSONEncoder().encode(payload)

                func performRequest(_ req: URLRequest) async throws -> GeminiResponse {
                    let (data, response) = try await URLSession.shared.data(for: req)
                    if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                        let body = String(data: data, encoding: .utf8) ?? "<no body>"
                        throw NSError(domain: "GeminiHTTP", code: http.statusCode,
                                      userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode): \(body)"])
                    }
                    return try JSONDecoder().decode(GeminiResponse.self, from: data)
                }

                var gemini: GeminiResponse
                do {
                    gemini = try await performRequest(request)
                } catch let error as NSError where error.domain == "GeminiHTTP" && error.code == 404 {
                    logger.warning("Model \(self.modelName) not found, falling back to gemini-2.0-flash")
                    self.modelName = "gemini-2.0-flash"
                    base = "https://generativelanguage.googleapis.com/\(apiVersionPath)/models/\(self.modelName):generateContent"
                    guard let fallbackURL = URL(string: base + "?key=\(self.apiKey)") else { throw URLError(.badURL) }
                    var fallbackRequest = URLRequest(url: fallbackURL)
                    fallbackRequest.httpMethod = "POST"
                    fallbackRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    fallbackRequest.httpBody = request.httpBody
                    gemini = try await performRequest(fallbackRequest)
                }

                if let text = gemini.candidates?.first?.content?.parts?.first?.text, !text.isEmpty {
                    logger.info("Translation received (\(text.count) chars)")
                    self.translatedText = text
                } else {
                    logger.error("Gemini returned an empty response")
                    self.translatedText = "Error: Empty response from Gemini."
                }
                self.isTranslating = false
            } catch {
                logger.error("Translation failed: \(error.localizedDescription)")
                self.translatedText = "Translation failed: \(error.localizedDescription)"
                self.isTranslating = false
            }
        }
    }
}
