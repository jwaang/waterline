import Foundation

// MARK: - ConvexService

/// Swift service layer wrapping Convex HTTP API with async/await.
/// Uses URLSession to call Convex query/mutation endpoints.
actor ConvexService {
    let deploymentURL: URL
    private let session: URLSession

    init(deploymentURL: URL, session: URLSession = .shared) {
        self.deploymentURL = deploymentURL
        self.session = session
    }

    // MARK: - Generic HTTP Methods

    func query<T: Decodable>(
        _ path: String,
        args: [String: Any] = [:],
        returning: T.Type = T.self
    ) async throws -> T {
        return try await callFunction(endpoint: "query", path: path, args: args)
    }

    func mutation<T: Decodable>(
        _ path: String,
        args: [String: Any] = [:],
        returning: T.Type = T.self
    ) async throws -> T {
        return try await callFunction(endpoint: "mutation", path: path, args: args)
    }

    func mutationVoid(
        _ path: String,
        args: [String: Any] = [:]
    ) async throws {
        let _: ConvexNull = try await callFunction(endpoint: "mutation", path: path, args: args)
    }

    // MARK: - Auth

    func verifyAndCreateUser(
        appleIdentityToken: String,
        appleUserId: String,
        email: String? = nil,
        fullName: String? = nil
    ) async throws -> AuthResult {
        var args: [String: Any] = [
            "appleIdentityToken": appleIdentityToken,
            "appleUserId": appleUserId,
        ]
        if let email { args["email"] = email }
        if let fullName { args["fullName"] = fullName }
        return try await mutation("auth:verifyAndCreateUser", args: args)
    }

    // MARK: - Users

    func createUser(appleUserId: String, settings: ConvexUserSettings? = nil) async throws -> String {
        var args: [String: Any] = ["appleUserId": appleUserId]
        if let settings {
            args["settings"] = settings.toDictionary()
        }
        return try await mutation("mutations:createUser", args: args)
    }

    // MARK: - Sessions

    func upsertSession(
        userId: String,
        startTime: Double,
        endTime: Double? = nil,
        isActive: Bool,
        computedSummary: ConvexSessionSummary? = nil,
        existingId: String? = nil
    ) async throws -> String {
        var args: [String: Any] = [
            "userId": userId,
            "startTime": startTime,
            "isActive": isActive,
        ]
        if let endTime { args["endTime"] = endTime }
        if let computedSummary { args["computedSummary"] = computedSummary.toDictionary() }
        if let existingId { args["existingId"] = existingId }
        return try await mutation("mutations:upsertSession", args: args)
    }

    func getActiveSession(userId: String) async throws -> ConvexSession? {
        return try await query("queries:getActiveSession", args: ["userId": userId])
    }

    // MARK: - Log Entries

    func addLogEntry(
        sessionId: String,
        timestamp: Double,
        type: String,
        alcoholMeta: ConvexAlcoholMeta? = nil,
        waterMeta: ConvexWaterMeta? = nil,
        source: String
    ) async throws -> String {
        var args: [String: Any] = [
            "sessionId": sessionId,
            "timestamp": timestamp,
            "type": type,
            "source": source,
        ]
        if let alcoholMeta { args["alcoholMeta"] = alcoholMeta.toDictionary() }
        if let waterMeta { args["waterMeta"] = waterMeta.toDictionary() }
        return try await mutation("mutations:addLogEntry", args: args)
    }

    func deleteLogEntry(id: String) async throws {
        try await mutationVoid("mutations:deleteLogEntry", args: ["id": id])
    }

    func getSessionLogs(sessionId: String) async throws -> [ConvexLogEntry] {
        return try await query("queries:getSessionLogs", args: ["sessionId": sessionId])
    }

    // MARK: - Drink Presets

    func upsertDrinkPreset(
        userId: String,
        name: String,
        drinkType: String,
        sizeOz: Double,
        abv: Double? = nil,
        standardDrinkEstimate: Double,
        existingId: String? = nil
    ) async throws -> String {
        var args: [String: Any] = [
            "userId": userId,
            "name": name,
            "drinkType": drinkType,
            "sizeOz": sizeOz,
            "standardDrinkEstimate": standardDrinkEstimate,
        ]
        if let abv { args["abv"] = abv }
        if let existingId { args["existingId"] = existingId }
        return try await mutation("mutations:upsertDrinkPreset", args: args)
    }

    func getUserPresets(userId: String) async throws -> [ConvexDrinkPreset] {
        return try await query("queries:getUserPresets", args: ["userId": userId])
    }

    // MARK: - Internal

    private func callFunction<T: Decodable>(
        endpoint: String,
        path: String,
        args: [String: Any]
    ) async throws -> T {
        let url = deploymentURL.appendingPathComponent("api/\(endpoint)")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "path": path,
            "args": args,
            "format": "json",
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ConvexError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let bodyString = String(data: data, encoding: .utf8) ?? "unknown"
            throw ConvexError.httpError(statusCode: httpResponse.statusCode, body: bodyString)
        }

        let convexResponse = try JSONDecoder().decode(ConvexResponse<T>.self, from: data)

        switch convexResponse.status {
        case "success":
            guard let value = convexResponse.value else {
                if T.self == ConvexNull.self {
                    return ConvexNull() as! T
                }
                throw ConvexError.missingValue
            }
            return value
        case "error":
            throw ConvexError.serverError(
                message: convexResponse.errorMessage ?? "Unknown error",
                data: convexResponse.errorData
            )
        default:
            throw ConvexError.unexpectedStatus(convexResponse.status)
        }
    }
}

// MARK: - Error Types

enum ConvexError: Error, LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int, body: String)
    case missingValue
    case serverError(message: String, data: String?)
    case unexpectedStatus(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from Convex"
        case .httpError(let statusCode, let body):
            return "HTTP \(statusCode): \(body)"
        case .missingValue:
            return "Missing value in Convex response"
        case .serverError(let message, _):
            return "Convex error: \(message)"
        case .unexpectedStatus(let status):
            return "Unexpected status: \(status)"
        }
    }
}

// MARK: - Response Types

struct ConvexResponse<T: Decodable>: Decodable {
    let status: String
    let value: T?
    let errorMessage: String?
    let errorData: String?
    let logLines: [String]?
}

struct ConvexNull: Decodable {}

// MARK: - Convex Data Transfer Objects

struct AuthResult: Decodable {
    let userId: String
    let isNewUser: Bool
}

struct ConvexUserSettings: Codable {
    var waterEveryNDrinks: Int = 1
    var timeRemindersEnabled: Bool = false
    var timeReminderIntervalMinutes: Int = 20
    var warningThreshold: Int = 2
    var defaultWaterAmountOz: Int = 8
    var units: String = "oz"

    func toDictionary() -> [String: Any] {
        return [
            "waterEveryNDrinks": waterEveryNDrinks,
            "timeRemindersEnabled": timeRemindersEnabled,
            "timeReminderIntervalMinutes": timeReminderIntervalMinutes,
            "warningThreshold": warningThreshold,
            "defaultWaterAmountOz": defaultWaterAmountOz,
            "units": units,
        ]
    }
}

struct ConvexSessionSummary: Codable {
    let totalDrinks: Int
    let totalWater: Int
    let totalStandardDrinks: Double
    let durationSeconds: Double
    let pacingAdherence: Double
    let finalWaterlineValue: Double

    func toDictionary() -> [String: Any] {
        return [
            "totalDrinks": totalDrinks,
            "totalWater": totalWater,
            "totalStandardDrinks": totalStandardDrinks,
            "durationSeconds": durationSeconds,
            "pacingAdherence": pacingAdherence,
            "finalWaterlineValue": finalWaterlineValue,
        ]
    }
}

struct ConvexSession: Decodable {
    let _id: String
    let userId: String
    let startTime: Double
    let endTime: Double?
    let isActive: Bool
    let computedSummary: ConvexSessionSummary?
}

struct ConvexAlcoholMeta: Codable {
    let drinkType: String
    let sizeOz: Double
    let abv: Double?
    let standardDrinkEstimate: Double
    let presetId: String?

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "drinkType": drinkType,
            "sizeOz": sizeOz,
            "standardDrinkEstimate": standardDrinkEstimate,
        ]
        if let abv { dict["abv"] = abv }
        if let presetId { dict["presetId"] = presetId }
        return dict
    }
}

struct ConvexWaterMeta: Codable {
    let amountOz: Double

    func toDictionary() -> [String: Any] {
        return ["amountOz": amountOz]
    }
}

struct ConvexLogEntry: Decodable {
    let _id: String
    let sessionId: String
    let timestamp: Double
    let type: String
    let alcoholMeta: ConvexAlcoholMeta?
    let waterMeta: ConvexWaterMeta?
    let source: String
}

struct ConvexDrinkPreset: Decodable {
    let _id: String
    let userId: String
    let name: String
    let drinkType: String
    let sizeOz: Double
    let abv: Double?
    let standardDrinkEstimate: Double
}
