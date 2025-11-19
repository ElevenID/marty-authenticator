//
//  HttpClientWrapper.swift
//  SpruceID SDK Integration - iOS HTTP Client Wrapper
//

import Foundation

/**
 * iOS HTTP client wrapper using URLSession for SpruceID SDK operations.
 * 
 * Mirrors the Android HttpClientWrapper to provide consistent async HTTP
 * interface across platforms for Oid4vci and credential exchange flows.
 * 
 * Uses URLSession for native iOS async networking with proper error handling
 * and timeout management for credential exchange protocols.
 */
class HttpClientWrapper {
    private let urlSession: URLSession
    
    private static let TAG = "HttpClientWrapper"
    
    // Default timeouts for credential operations
    private static let DEFAULT_TIMEOUT: TimeInterval = 30.0
    private static let DEFAULT_RESOURCE_TIMEOUT: TimeInterval = 60.0
    
    /**
     * Initialize HTTP client with custom session configuration.
     * 
     * @param timeoutInterval Request timeout (default: 30s)
     * @param resourceTimeout Resource timeout for large transfers (default: 60s)
     */
    init(timeoutInterval: TimeInterval = DEFAULT_TIMEOUT, 
         resourceTimeout: TimeInterval = DEFAULT_RESOURCE_TIMEOUT) {
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeoutInterval
        config.timeoutIntervalForResource = resourceTimeout
        
        // Security and reliability settings for credential exchange
        config.httpShouldUsePipelining = false
        config.httpShouldSetCookies = false
        config.requestCachePolicy = .reloadIgnoringCacheData
        
        // Headers for credential protocols
        config.httpAdditionalHeaders = [
            "User-Agent": "SpruceID-Authenticator-iOS/1.0",
            "Accept": "application/json"
        ]
        
        self.urlSession = URLSession(configuration: config)
        print("\(Self.TAG): Initialized with timeout: \(timeoutInterval)s")
    }
    
    /**
     * Perform async GET request.
     * 
     * @param url The URL to request
     * @param headers Additional headers (optional)
     * @returns The response data and HTTP status
     * @throws HttpError for various HTTP failures
     */
    func get(url: String, headers: [String: String] = [:]) async throws -> HttpResponse {
        print("\(Self.TAG): GET \(url)")
        
        guard let requestUrl = URL(string: url) else {
            throw HttpError.invalidUrl("Invalid URL: \(url)")
        }
        
        var request = URLRequest(url: requestUrl)
        request.httpMethod = "GET"
        
        // Add custom headers
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        return try await performRequest(request)
    }
    
    /**
     * Perform async POST request with JSON body.
     * 
     * @param url The URL to post to
     * @param body The JSON body data
     * @param headers Additional headers (optional)
     * @returns The response data and HTTP status
     * @throws HttpError for various HTTP failures
     */
    func post(url: String, body: Data? = nil, headers: [String: String] = [:]) async throws -> HttpResponse {
        print("\(Self.TAG): POST \(url) with \(body?.count ?? 0) bytes")
        
        guard let requestUrl = URL(string: url) else {
            throw HttpError.invalidUrl("Invalid URL: \(url)")
        }
        
        var request = URLRequest(url: requestUrl)
        request.httpMethod = "POST"
        request.httpBody = body
        
        // Default content type for credential protocols
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        // Add custom headers
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        return try await performRequest(request)
    }
    
    /**
     * Perform async POST request with form data.
     * 
     * @param url The URL to post to
     * @param formData The form data parameters
     * @param headers Additional headers (optional)
     * @returns The response data and HTTP status
     * @throws HttpError for various HTTP failures
     */
    func postForm(url: String, formData: [String: String], headers: [String: String] = [:]) async throws -> HttpResponse {
        let body = formData.map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        var formHeaders = headers
        formHeaders["Content-Type"] = "application/x-www-form-urlencoded"
        
        return try await post(url: url, body: body, headers: formHeaders)
    }
    
    /**
     * Internal method to perform URLSession request with error handling.
     */
    private func performRequest(_ request: URLRequest) async throws -> HttpResponse {
        do {
            let (data, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw HttpError.invalidResponse("Response is not HTTPURLResponse")
            }
            
            let statusCode = httpResponse.statusCode
            print("\(Self.TAG): Response \(statusCode) with \(data.count) bytes")
            
            let result = HttpResponse(
                data: data,
                statusCode: statusCode,
                headers: httpResponse.allHeaderFields as? [String: String] ?? [:]
            )
            
            // Check for HTTP error codes
            if statusCode >= 400 {
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw HttpError.httpError(statusCode, "HTTP \(statusCode): \(errorBody)")
            }
            
            return result
        } catch let error as URLError {
            throw HttpError.networkError("URLError: \(error.localizedDescription)")
        } catch let error as HttpError {
            throw error
        } catch {
            throw HttpError.unknownError("Unexpected error: \(error)")
        }
    }
    
    /**
     * Get the underlying URLSession for advanced usage.
     * 
     * @returns The configured URLSession instance
     */
    func getUrlSession() -> URLSession {
        return urlSession
    }
    
    /**
     * Clean up resources.
     */
    func invalidate() {
        print("\(Self.TAG): Invalidating URLSession")
        urlSession.invalidateAndCancel()
    }
}

// MARK: - Response Model

/**
 * HTTP response wrapper containing data, status, and headers.
 */
struct HttpResponse {
    let data: Data
    let statusCode: Int
    let headers: [String: String]
    
    /**
     * Get response body as UTF-8 string.
     */
    var bodyString: String {
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    /**
     * Check if response indicates success (2xx status codes).
     */
    var isSuccess: Bool {
        return statusCode >= 200 && statusCode < 300
    }
    
    /**
     * Parse JSON response to dictionary.
     */
    func parseJson() throws -> [String: Any] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw HttpError.parseError("Response is not valid JSON dictionary")
        }
        return json
    }
}

// MARK: - Error Types

enum HttpError: Error, LocalizedError {
    case invalidUrl(String)
    case invalidResponse(String)
    case httpError(Int, String)
    case networkError(String)
    case parseError(String)
    case unknownError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidUrl(let message):
            return "Invalid URL: \(message)"
        case .invalidResponse(let message):
            return "Invalid response: \(message)"
        case .httpError(let code, let message):
            return "HTTP \(code): \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .parseError(let message):
            return "Parse error: \(message)"
        case .unknownError(let message):
            return "Unknown error: \(message)"
        }
    }
}
