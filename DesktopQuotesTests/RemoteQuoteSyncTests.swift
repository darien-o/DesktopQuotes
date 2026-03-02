//
//  RemoteQuoteSyncTests.swift
//  DesktopQuotesTests
//
//  Created by Kiro on Enhanced Quote System Implementation
//

import XCTest
@testable import DesktopQuotes

final class RemoteQuoteSyncTests: XCTestCase {
    
    var sut: URLSessionRemoteQuoteSync!
    var mockSession: MockURLSession!
    
    override func setUp() {
        super.setUp()
        mockSession = MockURLSession()
        sut = URLSessionRemoteQuoteSync(session: mockSession)
    }
    
    override func tearDown() {
        sut = nil
        mockSession = nil
        super.tearDown()
    }
    
    // MARK: - Test successful fetch from valid source
    
    func testFetchQuotes_WithValidSource_ReturnsQuotes() async throws {
        // Given
        let source = QuoteSource(
            id: "test-source",
            url: "https://api.example.com/quotes",
            name: "Test Source",
            enabled: true
        )
        
        let jsonData = """
        {
            "quotes": [
                {
                    "text": "Test quote",
                    "author": "Test Author",
                    "language": "en",
                    "tags": ["inspiration"]
                }
            ]
        }
        """.data(using: .utf8)!
        
        let response = HTTPURLResponse(
            url: URL(string: source.url)!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        
        mockSession.mockData = jsonData
        mockSession.mockResponse = response
        
        // When
        let quotes = try await sut.fetchQuotes(from: source)
        
        // Then
        XCTAssertEqual(quotes.count, 1)
        XCTAssertEqual(quotes[0].text, "Test quote")
        XCTAssertEqual(quotes[0].author, "Test Author")
        XCTAssertEqual(quotes[0].language, "en")
        XCTAssertEqual(quotes[0].source, "Test Source")
    }
    
    // MARK: - Test HTTPS enforcement
    
    func testFetchQuotes_WithHTTPURL_ThrowsNonHTTPSError() async {
        // Given
        let source = QuoteSource(
            id: "insecure-source",
            url: "http://api.example.com/quotes",
            name: "Insecure Source",
            enabled: true
        )
        
        // When/Then
        do {
            _ = try await sut.fetchQuotes(from: source)
            XCTFail("Expected nonHTTPSURL error")
        } catch let error as SyncError {
            XCTAssertEqual(error, SyncError.nonHTTPSURL)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testValidateSource_WithHTTPURL_ThrowsNonHTTPSError() async {
        // Given
        let source = QuoteSource(
            id: "insecure-source",
            url: "http://api.example.com/quotes",
            name: "Insecure Source",
            enabled: true
        )
        
        // When/Then
        do {
            _ = try await sut.validateSource(source)
            XCTFail("Expected nonHTTPSURL error")
        } catch let error as SyncError {
            XCTAssertEqual(error, SyncError.nonHTTPSURL)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    // MARK: - Test timeout handling
    
    func testFetchQuotes_WithTimeout_ThrowsNetworkUnavailableError() async {
        // Given
        let source = QuoteSource(
            id: "slow-source",
            url: "https://api.example.com/quotes",
            name: "Slow Source",
            enabled: true
        )
        
        mockSession.mockError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorTimedOut,
            userInfo: nil
        )
        
        // When/Then
        do {
            _ = try await sut.fetchQuotes(from: source)
            XCTFail("Expected networkUnavailable error")
        } catch let error as SyncError {
            XCTAssertEqual(error, SyncError.networkUnavailable)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    // MARK: - Test response size limit
    
    func testFetchQuotes_WithOversizedResponse_ThrowsResponseTooLargeError() async {
        // Given
        let source = QuoteSource(
            id: "large-source",
            url: "https://api.example.com/quotes",
            name: "Large Source",
            enabled: true
        )
        
        // Create data larger than 1 MB
        let largeData = Data(repeating: 0, count: 1_048_577)
        
        let response = HTTPURLResponse(
            url: URL(string: source.url)!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        
        mockSession.mockData = largeData
        mockSession.mockResponse = response
        
        // When/Then
        do {
            _ = try await sut.fetchQuotes(from: source)
            XCTFail("Expected responseTooLarge error")
        } catch let error as SyncError {
            XCTAssertEqual(error, SyncError.responseTooLarge)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    // MARK: - Test JSON validation
    
    func testFetchQuotes_WithInvalidJSON_ThrowsParseError() async {
        // Given
        let source = QuoteSource(
            id: "invalid-source",
            url: "https://api.example.com/quotes",
            name: "Invalid Source",
            enabled: true
        )
        
        let invalidJSON = "{ invalid json }".data(using: .utf8)!
        
        let response = HTTPURLResponse(
            url: URL(string: source.url)!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        
        mockSession.mockData = invalidJSON
        mockSession.mockResponse = response
        
        // When/Then
        do {
            _ = try await sut.fetchQuotes(from: source)
            XCTFail("Expected parseError")
        } catch let error as SyncError {
            XCTAssertEqual(error, SyncError.parseError)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testFetchQuotes_WithEmptyQuotesArray_ThrowsInvalidJSONSchemaError() async {
        // Given
        let source = QuoteSource(
            id: "empty-source",
            url: "https://api.example.com/quotes",
            name: "Empty Source",
            enabled: true
        )
        
        let emptyJSON = """
        {
            "quotes": []
        }
        """.data(using: .utf8)!
        
        let response = HTTPURLResponse(
            url: URL(string: source.url)!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        
        mockSession.mockData = emptyJSON
        mockSession.mockResponse = response
        
        // When/Then
        do {
            _ = try await sut.fetchQuotes(from: source)
            XCTFail("Expected invalidJSONSchema error")
        } catch let error as SyncError {
            XCTAssertEqual(error, SyncError.invalidJSONSchema)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    // MARK: - Test network error handling
    
    func testFetchQuotes_WithNetworkError_ThrowsNetworkUnavailableError() async {
        // Given
        let source = QuoteSource(
            id: "offline-source",
            url: "https://api.example.com/quotes",
            name: "Offline Source",
            enabled: true
        )
        
        mockSession.mockError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNotConnectedToInternet,
            userInfo: nil
        )
        
        // When/Then
        do {
            _ = try await sut.fetchQuotes(from: source)
            XCTFail("Expected networkUnavailable error")
        } catch let error as SyncError {
            XCTAssertEqual(error, SyncError.networkUnavailable)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testFetchQuotes_With404Response_ThrowsSourceUnavailableError() async {
        // Given
        let source = QuoteSource(
            id: "missing-source",
            url: "https://api.example.com/quotes",
            name: "Missing Source",
            enabled: true
        )
        
        let response = HTTPURLResponse(
            url: URL(string: source.url)!,
            statusCode: 404,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        
        mockSession.mockData = Data()
        mockSession.mockResponse = response
        
        // When/Then
        do {
            _ = try await sut.fetchQuotes(from: source)
            XCTFail("Expected sourceUnavailable error")
        } catch let error as SyncError {
            XCTAssertEqual(error, SyncError.sourceUnavailable)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    // MARK: - Test content-type validation
    
    func testFetchQuotes_WithInvalidContentType_ThrowsInvalidContentTypeError() async {
        // Given
        let source = QuoteSource(
            id: "html-source",
            url: "https://api.example.com/quotes",
            name: "HTML Source",
            enabled: true
        )
        
        let response = HTTPURLResponse(
            url: URL(string: source.url)!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "text/html"]
        )!
        
        mockSession.mockData = Data()
        mockSession.mockResponse = response
        
        // When/Then
        do {
            _ = try await sut.fetchQuotes(from: source)
            XCTFail("Expected invalidContentType error")
        } catch let error as SyncError {
            XCTAssertEqual(error, SyncError.invalidContentType)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    // MARK: - Test source validation
    
    func testValidateSource_WithValidSource_ReturnsTrue() async throws {
        // Given
        let source = QuoteSource(
            id: "valid-source",
            url: "https://api.example.com/quotes",
            name: "Valid Source",
            enabled: true
        )
        
        let response = HTTPURLResponse(
            url: URL(string: source.url)!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        
        mockSession.mockData = Data()
        mockSession.mockResponse = response
        
        // When
        let isValid = try await sut.validateSource(source)
        
        // Then
        XCTAssertTrue(isValid)
    }
    
    func testValidateSource_WithInvalidURL_ThrowsInvalidURLError() async {
        // Given
        let source = QuoteSource(
            id: "invalid-url",
            url: "not a valid url",
            name: "Invalid URL",
            enabled: true
        )
        
        // When/Then
        do {
            _ = try await sut.validateSource(source)
            XCTFail("Expected invalidURL error")
        } catch let error as SyncError {
            XCTAssertEqual(error, SyncError.invalidURL)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testValidateSource_WithNonJSONContentType_ReturnsFalse() async throws {
        // Given
        let source = QuoteSource(
            id: "text-source",
            url: "https://api.example.com/quotes",
            name: "Text Source",
            enabled: true
        )
        
        let response = HTTPURLResponse(
            url: URL(string: source.url)!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "text/plain"]
        )!
        
        mockSession.mockData = Data()
        mockSession.mockResponse = response
        
        // When
        let isValid = try await sut.validateSource(source)
        
        // Then
        XCTAssertFalse(isValid)
    }
    
    // MARK: - Test quote limit (100 per source)
    
    func testFetchQuotes_WithManyQuotes_LimitsTo100() async throws {
        // Given
        let source = QuoteSource(
            id: "large-source",
            url: "https://api.example.com/quotes",
            name: "Large Source",
            enabled: true
        )
        
        // Create 150 quotes
        var quotesArray = "["
        for i in 0..<150 {
            if i > 0 { quotesArray += "," }
            quotesArray += """
            {
                "text": "Quote \(i)",
                "author": "Author \(i)",
                "language": "en",
                "tags": []
            }
            """
        }
        quotesArray += "]"
        
        let jsonData = """
        {
            "quotes": \(quotesArray)
        }
        """.data(using: .utf8)!
        
        let response = HTTPURLResponse(
            url: URL(string: source.url)!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        
        mockSession.mockData = jsonData
        mockSession.mockResponse = response
        
        // When
        let quotes = try await sut.fetchQuotes(from: source)
        
        // Then
        XCTAssertEqual(quotes.count, 100, "Should limit to 100 quotes per source")
    }
}

// MARK: - Mock URLSession

class MockURLSession: URLSessionProtocol {
    var mockData: Data?
    var mockResponse: URLResponse?
    var mockError: Error?
    
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        if let error = mockError {
            throw error
        }
        
        guard let data = mockData, let response = mockResponse else {
            throw NSError(domain: "MockError", code: -1, userInfo: nil)
        }
        
        return (data, response)
    }
}

// MARK: - SyncError Equatable Extension

extension SyncError: Equatable {
    public static func == (lhs: SyncError, rhs: SyncError) -> Bool {
        switch (lhs, rhs) {
        case (.networkUnavailable, .networkUnavailable),
             (.invalidResponse, .invalidResponse),
             (.parseError, .parseError),
             (.sourceUnavailable, .sourceUnavailable),
             (.invalidURL, .invalidURL),
             (.nonHTTPSURL, .nonHTTPSURL),
             (.responseTimeout, .responseTimeout),
             (.responseTooLarge, .responseTooLarge),
             (.invalidContentType, .invalidContentType),
             (.invalidJSONSchema, .invalidJSONSchema),
             (.sslValidationFailed, .sslValidationFailed):
            return true
        default:
            return false
        }
    }
}
