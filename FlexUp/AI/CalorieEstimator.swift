import Foundation
import UIKit

/// AI calorie estimation from a meal photo, via the Anthropic Messages API.
///
/// The photo is downscaled, base64-encoded, and sent with a JSON-schema
/// structured output so the reply is guaranteed to parse. The model returns
/// an itemised breakdown rather than one number, because a plate is many
/// portions and the user needs to correct them individually.
///
/// Two inputs beyond the photo carry most of the accuracy: the user's
/// cooking context (Western databases badly misjudge regional dishes) and a
/// free-text correction for anything the camera can't see — the spoon of
/// ghee, the deep-frying, the dressing already mixed in.
///
/// v1 calls the API directly with a user-provided key stored on device —
/// before any public release this must move behind a backend proxy so the
/// key never ships in the app.
struct MealEstimate: Decodable {
    let mealName: String
    let items: [Item]
    let confidence: String
    let notes: String

    struct Item: Decodable {
        let name: String
        let calories: Int
        let portion: String
    }

    enum CodingKeys: String, CodingKey {
        case mealName = "meal_name"
        case items
        case confidence
        case notes
    }

    /// Convert to the editable model the review UI drives.
    var foodItems: [FoodItem] {
        items.map { FoodItem(name: $0.name, baseCalories: max(0, $0.calories), portion: $0.portion) }
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

    /// Haiku 4.5 keeps per-photo cost near $0.002 (~5x cheaper than Opus)
    /// with food identification and portion estimates that are good enough
    /// for a calorie-awareness tool, not a lab scale. Swap back to
    /// "claude-opus-4-8" if estimates trend inaccurate.
    private static let model = "claude-haiku-4-5"

    private static let outputSchema: [String: Any] = [
        "type": "object",
        "properties": [
            "meal_name": [
                "type": "string",
                "description": "Short name for the whole meal, max 5 words. Use the dish's real name where you can identify it.",
            ],
            "items": [
                "type": "array",
                "description": "Each distinct component of the meal, listed separately.",
                "items": [
                    "type": "object",
                    "properties": [
                        "name": ["type": "string", "description": "Component name, e.g. 'Dal', 'Rice', 'Roti'"],
                        "calories": ["type": "integer", "description": "Calories for the portion described"],
                        "portion": ["type": "string", "description": "The portion you estimated, e.g. '1 cup', '2 pieces', '150 g'"],
                    ],
                    "required": ["name", "calories", "portion"],
                    "additionalProperties": false,
                ],
            ],
            "confidence": [
                "type": "string",
                "enum": ["low", "medium", "high"],
            ],
            "notes": [
                "type": "string",
                "description": "One short sentence on the main assumption you made, especially about cooking fat or portion size.",
            ],
        ],
        "required": ["meal_name", "items", "confidence", "notes"],
        "additionalProperties": false,
    ]

    static func estimate(
        image: UIImage,
        apiKey: String,
        cuisineContext: String = "",
        correction: String = ""
    ) async throws -> MealEstimate {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw CalorieEstimatorError.missingKey }
        guard let jpeg = downscaledJPEG(from: image) else { throw CalorieEstimatorError.badImage }

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1500,
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
                        ["type": "text", "text": prompt(cuisineContext: cuisineContext, correction: correction)],
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
            return try JSONDecoder().decode(MealEstimate.self, from: jsonData)
        } catch {
            throw CalorieEstimatorError.malformed
        }
    }

    /// The prompt does the heavy lifting on regional accuracy: it names the
    /// user's cuisine, tells the model not to default to Western portions,
    /// and folds in whatever correction the user spoke or typed.
    private static func prompt(cuisineContext: String, correction: String) -> String {
        var lines = [
            """
            Estimate the calories in this meal photo for a tracking app. Break the \
            plate into its distinct components and give each one its own line with \
            the portion you think you see and the calories for that portion.
            """,
            """
            Be realistic about cooking fat. Photos cannot show oil, ghee, butter, \
            cream or sugar that is already cooked into a dish, and under-counting \
            it is the most common way these estimates go wrong. Assume normal \
            home-cooking amounts for the cuisine unless the food looks dry or \
            explicitly plain.
            """,
        ]

        if cuisineContext.trimmingCharacters(in: .whitespaces).isEmpty {
            lines.append(
                """
                Identify the cuisine from the photo and use portion sizes and \
                recipes typical of that cuisine. Do not substitute a generic \
                Western equivalent for a regional dish — name the actual dish \
                where you recognise it.
                """
            )
        } else {
            lines.append(
                """
                The person eating this describes their cooking as: \
                "\(cuisineContext.trimmingCharacters(in: .whitespaces))". Use the \
                dish names, typical recipes, cooking fats and portion sizes of \
                that cuisine rather than Western database equivalents, which \
                routinely misjudge these dishes.
                """
            )
        }

        let trimmedCorrection = correction.trimmingCharacters(in: .whitespaces)
        if !trimmedCorrection.isEmpty {
            lines.append(
                """
                The person has added this correction about the meal, which the \
                photo may not show — treat it as authoritative and fold it into \
                your estimate: "\(trimmedCorrection)"
                """
            )
        }

        return lines.joined(separator: "\n\n")
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
