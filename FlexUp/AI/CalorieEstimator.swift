import Foundation
import UIKit

/// AI calorie estimation from a meal photo.
///
/// The app never talks to Anthropic directly: it sends the downscaled photo
/// (plus the person's cooking context and any correction) to the FlexUp
/// server in `backend/`, which holds the API key, owns the prompt and the
/// JSON schema, and returns an itemised breakdown — one row per component,
/// each with calories and macros, because a plate is many portions and the
/// person needs to correct them individually.
struct MealEstimate: Decodable {
    let mealName: String
    let items: [Item]
    let confidence: String
    let notes: String

    struct Item: Decodable {
        let name: String
        let calories: Int
        let portion: String
        // Optional on our side so a reply without them still decodes; the
        // schema asks for them on every item.
        let proteinG: Double?
        let carbsG: Double?
        let fatG: Double?
        let fiberG: Double?
        let sugarG: Double?
        let sodiumMg: Double?

        enum CodingKeys: String, CodingKey {
            case name, calories, portion
            case proteinG = "protein_g"
            case carbsG = "carbs_g"
            case fatG = "fat_g"
            case fiberG = "fiber_g"
            case sugarG = "sugar_g"
            case sodiumMg = "sodium_mg"
        }

        var macros: Macros? {
            guard proteinG != nil || carbsG != nil || fatG != nil else { return nil }
            return Macros(
                protein: max(0, proteinG ?? 0),
                carbs: max(0, carbsG ?? 0),
                fat: max(0, fatG ?? 0),
                fiber: max(0, fiberG ?? 0),
                sugar: max(0, sugarG ?? 0),
                sodiumMg: max(0, sodiumMg ?? 0)
            )
        }
    }

    enum CodingKeys: String, CodingKey {
        case mealName = "meal_name"
        case items
        case confidence
        case notes
    }

    /// Convert to the editable model the review UI drives.
    var foodItems: [FoodItem] {
        items.map {
            FoodItem(name: $0.name, baseCalories: max(0, $0.calories), portion: $0.portion, baseMacros: $0.macros)
        }
    }
}

enum CalorieEstimatorError: LocalizedError {
    case notConfigured
    case badImage
    case offline
    case malformed

    var errorDescription: String? {
        switch self {
        case .notConfigured: "AI estimates aren't switched on in this build yet. Log it by hand for now."
        case .badImage: "Couldn't read that photo."
        case .offline: "You're offline — log it by hand, or try again when you're connected."
        case .malformed: "Got an unexpected response — try again."
        }
    }
}

enum CalorieEstimator {

    /// Server errors (`ServerError`) and App Attest failures
    /// (`AppAttestClient.Failure`) surface with messages written for the
    /// person holding the phone.
    static func estimate(
        image: UIImage,
        cuisineContext: String = "",
        correction: String = ""
    ) async throws -> MealEstimate {
        guard let baseURL = BackendConfig.baseURL else { throw CalorieEstimatorError.notConfigured }
        guard let jpeg = downscaledJPEG(from: image) else { throw CalorieEstimatorError.badImage }

        // Serialized once: App Attest signs these exact bytes.
        let body = try JSONSerialization.data(withJSONObject: [
            "image": jpeg.base64EncodedString(),
            "media_type": "image/jpeg",
            "cuisine_context": cuisineContext.trimmingCharacters(in: .whitespacesAndNewlines),
            "correction": correction.trimmingCharacters(in: .whitespacesAndNewlines),
        ])

        do {
            return try await send(body, to: baseURL, isRetry: false)
        } catch let error as URLError where error.code == .notConnectedToInternet || error.code == .networkConnectionLost {
            throw CalorieEstimatorError.offline
        }
    }

    private static func send(_ body: Data, to baseURL: URL, isRetry: Bool) async throws -> MealEstimate {
        var request = URLRequest(url: baseURL.appendingPathComponent("v1/estimate"))
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (field, value) in try await AppAttestClient.shared.headers(for: body, baseURL: baseURL) {
            request.setValue(value, forHTTPHeaderField: field)
        }
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        do {
            try ServerError.check(data: data, response: response)
        } catch let error as ServerError where !isRetry {
            switch error.type {
            case "attestation_required":
                // The server doesn't know this install (or its key) — register again.
                await AppAttestClient.shared.forgetKey()
                return try await send(body, to: baseURL, isRetry: true)
            case "challenge_expired":
                return try await send(body, to: baseURL, isRetry: true)
            default:
                throw error
            }
        }

        do {
            return try JSONDecoder().decode(MealEstimate.self, from: data)
        } catch {
            throw CalorieEstimatorError.malformed
        }
    }

    /// Meal photos don't need full resolution — cap the long edge so the
    /// upload is fast and the image token cost stays small (~1,000 tokens).
    private static func downscaledJPEG(from image: UIImage, maxEdge: CGFloat = 1024) -> Data? {
        let size = image.size
        let longEdge = max(size.width, size.height)
        guard longEdge > maxEdge else {
            return image.jpegData(compressionQuality: 0.7)
        }
        let scale = maxEdge / longEdge
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: 0.7)
    }
}
