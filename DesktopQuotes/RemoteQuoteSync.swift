//
//  RemoteQuoteSync.swift
//  DesktopQuotes
//
//  Created by Kiro on Enhanced Quote System Implementation
//

import Foundation

/// Protocol for URLSession abstraction to enable testing
protocol URLSessionProtocol {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

/// Make URLSession conform to the protocol
extension URLSession: URLSessionProtocol {}

/// Protocol defining remote quote synchronization operations
protocol RemoteQuoteSync {
    func fetchQuotes(from source: QuoteSource) async throws -> [Quote]
    func fetchAllSources() async throws -> [Quote]
    func validateSource(_ source: QuoteSource) async throws -> Bool
}

/// Errors that can occur during remote synchronization
enum SyncError: Error, LocalizedError {
    case networkUnavailable
    case invalidResponse
    case parseError
    case sourceUnavailable
    case invalidURL
    case nonHTTPSURL
    case responseTimeout
    case responseTooLarge
    case invalidContentType
    case invalidJSONSchema
    case sslValidationFailed
    
    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "Network connection unavailable"
        case .invalidResponse:
            return "Invalid response from server"
        case .parseError:
            return "Failed to parse quote data"
        case .sourceUnavailable:
            return "Quote source is unavailable"
        case .invalidURL:
            return "Invalid source URL"
        case .nonHTTPSURL:
            return "Only HTTPS URLs are allowed"
        case .responseTimeout:
            return "Request timed out after 30 seconds"
        case .responseTooLarge:
            return "Response exceeds 1 MB size limit"
        case .invalidContentType:
            return "Response content type must be JSON"
        case .invalidJSONSchema:
            return "Response does not match expected JSON schema"
        case .sslValidationFailed:
            return "SSL certificate validation failed"
        }
    }
}

/// Implementation of RemoteQuoteSync using URLSession
final class URLSessionRemoteQuoteSync: RemoteQuoteSync {
    private let session: URLSessionProtocol
    private let logger = SyncLogger()
    private let maxResponseSize: Int = 1_048_576 // 1 MB
    private let timeout: TimeInterval = 30.0
    private let maxConcurrentRequests = 3
    
    init(session: URLSessionProtocol? = nil) {
        if let session = session {
            self.session = session
        } else {
            // Configure URLSession with security and performance settings
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = timeout
            configuration.timeoutIntervalForResource = timeout
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            configuration.httpMaximumConnectionsPerHost = maxConcurrentRequests
            configuration.httpAdditionalHeaders = [
                "Accept": "application/json",
                "Accept-Encoding": "gzip, deflate"
            ]
            
            self.session = URLSession(configuration: configuration)
        }
    }
    
    /// Fetch quotes from a single source
    func fetchQuotes(from source: QuoteSource) async throws -> [Quote] {
        logger.log("🔍 Fetching quotes from source: \(source.name)")
        print("🔍 [RemoteQuoteSync] Fetching quotes from source: \(source.name)")
        
        // Validate source URL
        guard let url = URL(string: source.url) else {
            logger.log("❌ ERROR: Invalid URL: \(source.url)")
            print("❌ [RemoteQuoteSync] ERROR: Invalid URL: \(source.url)")
            throw SyncError.invalidURL
        }
        
        // Enforce HTTPS only
        guard url.scheme == "https" else {
            logger.log("❌ ERROR: Non-HTTPS URL: \(source.url)")
            print("❌ [RemoteQuoteSync] ERROR: Non-HTTPS URL: \(source.url)")
            throw SyncError.nonHTTPSURL
        }
        
        logger.log("📡 Making request to: \(url.absoluteString)")
        print("📡 [RemoteQuoteSync] Making request to: \(url.absoluteString)")
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        
        do {
            // Perform network request
            logger.log("⏳ Sending network request...")
            print("⏳ [RemoteQuoteSync] Sending network request...")
            let (data, response) = try await session.data(for: request)
            
            logger.log("✅ Received response: \(data.count) bytes")
            print("✅ [RemoteQuoteSync] Received response: \(data.count) bytes")
            
            // Log response for debugging
            if let httpResponse = response as? HTTPURLResponse {
                logger.log("HTTP Status: \(httpResponse.statusCode)")
                logger.log("Content-Type: \(httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "none")")
            }
            
            // Validate response
            try validateResponse(response, data: data)
            
            // Parse and validate JSON
            let quotes = try parseQuotes(from: data, source: source)
            
            logger.log("Successfully fetched \(quotes.count) quotes from \(source.name)")
            return quotes
            
        } catch let error as SyncError {
            logger.log("❌ Sync error from \(source.name): \(error.localizedDescription)")
            print("❌ [RemoteQuoteSync] Sync error from \(source.name): \(error.localizedDescription)")
            throw error
        } catch {
            logger.log("❌ Network error from \(source.name): \(error.localizedDescription)")
            print("❌ [RemoteQuoteSync] Network error from \(source.name): \(error.localizedDescription)")
            print("❌ [RemoteQuoteSync] Error details: \(error)")
            throw SyncError.networkUnavailable
        }
    }
    
    /// Fetch quotes from all enabled sources
    func fetchAllSources() async throws -> [Quote] {
        logger.log("🌐 Fetching quotes from ZenQuotes API")
        print("🌐 [RemoteQuoteSync] Fetching quotes from ZenQuotes API")
        
        // Use ZenQuotes API as default source
        let zenQuotesSource = QuoteSource(
            id: "zenquotes",
            url: "https://zenquotes.io/api/quotes",
            name: "ZenQuotes",
            enabled: true
        )
        
        do {
            let quotes = try await fetchQuotes(from: zenQuotesSource)
            logger.log("✅ Successfully fetched \(quotes.count) quotes from ZenQuotes")
            print("✅ [RemoteQuoteSync] Successfully fetched \(quotes.count) quotes from ZenQuotes")
            return quotes
        } catch {
            logger.log("❌ Failed to fetch from ZenQuotes: \(error.localizedDescription)")
            print("❌ [RemoteQuoteSync] Failed to fetch from ZenQuotes: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Validate a quote source
    func validateSource(_ source: QuoteSource) async throws -> Bool {
        logger.log("Validating source: \(source.name)")
        
        // Validate URL format
        guard let url = URL(string: source.url) else {
            throw SyncError.invalidURL
        }
        
        // Enforce HTTPS only
        guard url.scheme == "https" else {
            throw SyncError.nonHTTPSURL
        }
        
        // Try to fetch from the source
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            request.timeoutInterval = timeout
            
            let (_, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }
            
            // Check status code
            guard (200...299).contains(httpResponse.statusCode) else {
                return false
            }
            
            // Validate content type
            guard let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type"),
                  contentType.lowercased().contains("json") else {
                return false
            }
            
            logger.log("Source validation successful: \(source.name)")
            return true
            
        } catch {
            logger.log("Source validation failed: \(source.name) - \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Private Helper Methods
    
    /// Validate HTTP response
    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SyncError.invalidResponse
        }
        
        // Check status code
        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 404 {
                throw SyncError.sourceUnavailable
            }
            throw SyncError.invalidResponse
        }
        
        // Check response size
        guard data.count <= maxResponseSize else {
            throw SyncError.responseTooLarge
        }
        
        // Validate content type (allow both application/json and text/plain for ZenQuotes)
        if let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") {
            let isValidContentType = contentType.lowercased().contains("json") || 
                                    contentType.lowercased().contains("plain")
            guard isValidContentType else {
                throw SyncError.invalidContentType
            }
        }
    }
    
    /// Parse quotes from JSON data
    private func parseQuotes(from data: Data, source: QuoteSource) throws -> [Quote] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        // Log raw JSON for debugging
        if let jsonString = String(data: data, encoding: .utf8) {
            logger.log("Raw JSON response: \(jsonString.prefix(500))...")
        }
        
        do {
            // Check if this is ZenQuotes API format
            if source.id == "zenquotes" {
                logger.log("Parsing as ZenQuotes format")
                let zenQuotes = try decoder.decode([ZenQuoteDTO].self, from: data)
                
                logger.log("Decoded \(zenQuotes.count) ZenQuotes")
                
                // Validate we have quotes
                guard !zenQuotes.isEmpty else {
                    logger.log("ERROR: Empty quotes array from ZenQuotes")
                    throw SyncError.invalidJSONSchema
                }
                
                // Convert to Quote objects
                let quotes = zenQuotes.compactMap { dto -> Quote? in
                    guard !dto.q.isEmpty, !dto.a.isEmpty else {
                        logger.log("Skipping invalid quote: empty text or author")
                        return nil
                    }
                    
                    logger.log("Parsed quote: \"\(dto.q.prefix(50))...\" by \(dto.a)")
                    
                    return Quote(
                        id: UUID(),
                        text: dto.q,
                        author: dto.a,
                        language: "en",
                        tags: [],
                        source: source.name,
                        dateAdded: Date()
                    )
                }
                
                logger.log("Converted to \(quotes.count) Quote objects")
                
                // Limit to 100 quotes per source
                return Array(quotes.prefix(100))
            }
            
            // Try to decode as QuoteResponse (array of quotes)
            logger.log("Parsing as standard format")
            let response = try decoder.decode(QuoteResponse.self, from: data)
            
            // Validate JSON schema
            guard !response.quotes.isEmpty else {
                throw SyncError.invalidJSONSchema
            }
            
            // Convert to Quote objects with source information
            let quotes = response.quotes.compactMap { dto -> Quote? in
                // Validate required fields
                guard !dto.text.isEmpty,
                      !dto.author.isEmpty,
                      dto.language.count == 2 else {
                    return nil
                }
                
                return Quote(
                    id: UUID(),
                    text: dto.text,
                    author: dto.author,
                    language: dto.language,
                    tags: dto.tags ?? [],
                    source: source.name,
                    dateAdded: Date()
                )
            }
            
            // Limit to 100 quotes per source
            let limitedQuotes = Array(quotes.prefix(100))
            
            return limitedQuotes
            
        } catch {
            logger.log("Parse error: \(error.localizedDescription)")
            if let decodingError = error as? DecodingError {
                logger.log("Decoding error details: \(decodingError)")
            }
            throw SyncError.parseError
        }
    }
}

// MARK: - Data Transfer Objects

/// ZenQuotes API response structure
private struct ZenQuoteDTO: Codable {
    let q: String  // quote text
    let a: String  // author
    let h: String? // HTML (optional)
}

/// Response structure for quote API
private struct QuoteResponse: Codable {
    let quotes: [QuoteDTO]
}

/// Data transfer object for quote from API
private struct QuoteDTO: Codable {
    let text: String
    let author: String
    let language: String
    let tags: [String]?
}

// MARK: - Logger

/// Simple logger for sync operations
private struct SyncLogger {
    func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[\(timestamp)] RemoteQuoteSync: \(message)")
    }
}
