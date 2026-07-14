import Foundation
import UIKit

/// AI calorie estimation from a meal photo, via the Anthropic Messages API.
///
/// The photo is downscaled, base64-encoded, and sent with a JSON-schema
/// structured output so the reply is guaranteed to parse. v1 calls the API
/// directly with a user-provided key stored on device — before any public
/// release this must move behind a backend proxy so the key never ships
/// in the app.
struct FoodEstimate: Decodable {
    let foodName: String
    let calories: Int
    let confidence: String
    let notes: String

    enum CodingKeys: String, CodingKey {
        case foodName = "food_name"
        case calories
        case confidence
        case notes
    }
}

enum CalorieEstimatorError: LocalizedError {
    case missingKey
    case badImage
    case api(String)
    case refused
    case malformed

    var errorDescription: String? {
        switch self {
        case .missingKey: "Add your Anthropic API key first."
        case .badImage: "Couldn't read that photo."
        case .api(let message): message
        case .refused: "The model declined to analyze this image."
        case .malformed: "Got an unexpected response — try again."
        }
    }
}

enum CalorieEstimator {

    /// Change to "claude-haiku-4-5" for cheaper (less accurate) estimates.
    private static let model = "claude-opus-4-8"

    private static let prompt = """
    Estimate the food in this photo for a calorie-tracking app. Identify \
    what the meal is (a short name, max 4 words) and estimate the total \
    calories for the visible portion, being realistic about portion size. \
    If there are multiple items, sum them and give the meal a brief \
    combined name. In notes, list the main components and portion \
    assumptions in one short sentence.
    """

    private static let outputSchema: [String: Any] = [
        "type": "object",
        "properties": [
            "food_name": [
                "type": "string",
                "description": "Short name for the meal, max 4 words",
            ],
            "calories": [
                "type": "integer",
                "description": "Estimated total kcal for the visible portion",
            ],
            "confidence": [
                "type": "string",
                "enum": ["low", "medium", "high"],
            ],
            "notes": [
                "type": "string",
                "description": "One sentence: components and portion assumptions",
            ],
        ],
        "required": ["food_name", "calories", "confidence", "notes"],
        "additionalProperties": false,
    ]

    static func estimate(image: UIImage, apiKey: String) async throws -> FoodEstimate {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw CalorieEstimatorError.missingKey }
        guard let jpeg = downscaledJPEG(from: image) else { throw CalorieEstimatorError.badImage }

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "output_config": [
                "format": [
                    "type": "json_schema",
                    "schema": outputSchema,
                ],
            ],
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image",
                            "source": [
                                "type": "base64",
                                "media_type": "image/jpeg",
                                "data": jpeg.base64EncodedString(),
                            ],
                        ],
                        ["type": "text", "text": prompt],
                    ],
                ],
            ],
        ]

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw CalorieEstimatorError.api("No response from the API.")
        }
        guard http.statusCode == 200 else {
            if let apiError = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data) {
                throw CalorieEstimatorError.api(apiError.error.message)
            }
            throw CalorieEstimatorError.api("Request failed (\(http.statusCode)).")
        }

        let decoded = try JSONDecoder().decode(APIResponse.self, from: data)
        if decoded.stopReason == "refusal" {
            throw CalorieEstimatorError.refused
        }
        guard let text = decoded.content.first(where: { $0.type == "text" })?.text,
              let jsonData = text.data(using: .utf8) else {
            throw CalorieEstimatorError.malformed
        }
        do {
            return try JSONDecoder().decode(FoodEstimate.self, from: jsonData)
        } catch {
            throw CalorieEstimatorError.malformed
        }
    }

    /// Meal photos don't need full resolution — cap the long edge so the
    /// upload is fast and the image token cost stays small.
    private static func downscaledJPEG(from image: UIImage, maxEdge: CGFloat = 1024) -> Data? {
        let size = image.size
        let longEdge = max(size.width, size.height)
        guard longEdge > maxEdge else {
            return image.jpegData(compressionQuality: 0.7)
        }
        let scale = maxEdge / longEdge
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: 0.7)
    }

    // MARK: - Wire types

    private struct APIResponse: Decodable {
        struct Block: Decodable {
            let type: String
            let text: String?
        }

        let content: [Block]
        let stopReason: String?

        enum CodingKeys: String, CodingKey {
            case content
            case stopReason = "stop_reason"
        }
    }

    private struct APIErrorEnvelope: Decodable {
        struct APIError: Decodable {
            let message: String
        }

        let error: APIError
    }
}
