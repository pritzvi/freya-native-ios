//
//  ApiClient.swift
//  freya
//
//  API client for backend routes
//

import Foundation
import FirebaseAuth

class ApiClient {
    static let shared = ApiClient()
    
    // Production URL
    private let baseURL = "https://us-central1-freya-7c812.cloudfunctions.net/api"
    
    private init() {}
    
    // MARK: - Auth Helper
    private func getAuthToken() async throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw APIError.notAuthenticated
        }
        return try await user.getIDToken()
    }
    
    // MARK: - DeepScan
    func submitDeepScan(uid: String, images: [String], emphasis: String? = nil) async throws -> DeepScanResponse {
        let token = try await getAuthToken()
        let url = URL(string: "\(baseURL)/deepscan/score")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "uid": uid,
            "images": images,
            "emphasis": emphasis ?? "onboarding"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: errorMsg)
        }
        
        return try JSONDecoder().decode(DeepScanResponse.self, from: data)
    }
    
    func submitDeepScan(uid: String, gcsPaths: [String], emphasis: String? = nil) async throws -> DeepScanResponse {
        let token = try await getAuthToken()
        let url = URL(string: "\(baseURL)/deepscan/score")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "uid": uid,
            "gcsPaths": gcsPaths,
            "emphasis": emphasis ?? "onboarding"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: errorMsg)
        }
        
        return try JSONDecoder().decode(DeepScanResponse.self, from: data)
    }
    
    // MARK: - Survey
    func saveSurvey(uid: String, surveyData: [String: Any]) async throws -> SurveySaveResponse {
        let token = try await getAuthToken()
        let url = URL(string: "\(baseURL)/survey/save")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body = surveyData
        body["uid"] = uid
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: errorMsg)
        }
        
        return try JSONDecoder().decode(SurveySaveResponse.self, from: data)
    }
}

// MARK: - Response Models
struct DeepScanResponse: Codable {
    let scoreId: String
    let overall: Int
    let subscores: [String: Int]
    let confidence: Int
}

struct SurveySaveResponse: Codable {
    let ok: Bool
    let message: String
}

// MARK: - Errors
enum APIError: LocalizedError {
    case notAuthenticated
    case invalidResponse
    case serverError(statusCode: Int, message: String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .invalidResponse:
            return "Invalid server response"
        case .serverError(let statusCode, let message):
            return "Server error (\(statusCode)): \(message)"
        }
    }
}

