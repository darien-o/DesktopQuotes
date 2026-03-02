//
//  QuoteRepositoryTests.swift
//  DesktopQuotesTests
//
//  Unit tests for QuoteRepository
//

import Foundation
import Testing
@testable import DesktopQuotes

/// Unit tests for QuoteRepository functionality
/// Requirements: 1.1, 1.3, 5.7, 5.8, 5.9, 10.1, 10.8
struct QuoteRepositoryTests {
    
    // MARK: - Test loadQuotes with existing cache
    
    @Test("loadQuotes returns quotes from existing cache")
    func testLoadQuotesWithExistingCache() async throws {
        let mockStore = MockLocalQuoteStore()
        let mockSync = MockRemoteQuoteSync()
        let repository = LocalQuoteRepository(store: mockStore, remoteSync: mockSync)
        
        // Setup mock data
        let testQuotes = [
            Quote(text: "Test quote 1", author: "Author 1", language: "en"),
            Quote(text: "Test quote 2", author: "Author 2", language: "es")
        ]
        
        mockStore.collectionToReturn = QuoteCollection(
            quotes: testQuotes,
            version: "1.0.0",
            lastUpdated: Date(),
            sources: []
        )
        
        // Load quotes
        let loadedQuotes = try await repository.loadQuotes()
        
        // Verify
        #expect(loadedQuotes.count == 2)
        #expect(loadedQuotes[0].text == "Test quote 1")
        #expect(loadedQuotes[1].text == "Test quote 2")
    }
    
    // MARK: - Test loadQuotes with missing cache
    
    @Test("loadQuotes throws error when cache is missing")
    func testLoadQuotesWithMissingCache() async throws {
        let mockStore = MockLocalQuoteStore()
        let mockSync = MockRemoteQuoteSync()
        let repository = LocalQuoteRepository(store: mockStore, remoteSync: mockSync)
        
        // Don't set collectionToReturn, so read() will throw
        mockStore.collectionToReturn = nil
        
        // Verify error is thrown
        await #expect(throws: RepositoryError.self) {
            try await repository.loadQuotes()
        }
    }
    
    // MARK: - Test saveQuotes operation
    
    @Test("saveQuotes persists quotes to storage")
    func testSaveQuotes() async throws {
        let mockStore = MockLocalQuoteStore()
        let mockSync = MockRemoteQuoteSync()
        let repository = LocalQuoteRepository(store: mockStore, remoteSync: mockSync)
        
        let testQuotes = [
            Quote(text: "Save test 1", author: "Author 1", language: "en"),
            Quote(text: "Save test 2", author: "Author 2", language: "fr")
        ]
        
        // Save quotes
        try await repository.saveQuotes(testQuotes)
        
        // Verify
        #expect(mockStore.lastWrittenCollection != nil)
        #expect(mockStore.lastWrittenCollection?.quotes.count == 2)
        #expect(mockStore.lastWrittenCollection?.quotes[0].text == "Save test 1")
    }
    
    // MARK: - Test getQuotesByLanguage filtering
    
    @Test("getQuotesByLanguage filters quotes correctly")
    func testGetQuotesByLanguage() async throws {
        let mockStore = MockLocalQuoteStore()
        let mockSync = MockRemoteQuoteSync()
        let repository = LocalQuoteRepository(store: mockStore, remoteSync: mockSync)
        
        // Setup mixed language quotes
        let testQuotes = [
            Quote(text: "English quote 1", author: "Author 1", language: "en"),
            Quote(text: "Spanish quote 1", author: "Author 2", language: "es"),
            Quote(text: "English quote 2", author: "Author 3", language: "en"),
            Quote(text: "French quote 1", author: "Author 4", language: "fr")
        ]
        
        mockStore.collectionToReturn = QuoteCollection(
            quotes: testQuotes,
            version: "1.0.0",
            lastUpdated: Date(),
            sources: []
        )
        
        // Load quotes first
        _ = try await repository.loadQuotes()
        
        // Filter by English
        let englishQuotes = repository.getQuotesByLanguage("en")
        #expect(englishQuotes.count == 2)
        #expect(englishQuotes.allSatisfy { $0.language == "en" })
        
        // Filter by Spanish
        let spanishQuotes = repository.getQuotesByLanguage("es")
        #expect(spanishQuotes.count == 1)
        #expect(spanishQuotes[0].language == "es")
        
        // Filter by non-existent language
        let germanQuotes = repository.getQuotesByLanguage("de")
        #expect(germanQuotes.count == 0)
    }
    
    // MARK: - Test quote validation and sanitization
    
    @Test("loadQuotes excludes invalid quotes")
    func testQuoteValidation() async throws {
        let mockStore = MockLocalQuoteStore()
        let mockSync = MockRemoteQuoteSync()
        let repository = LocalQuoteRepository(store: mockStore, remoteSync: mockSync)
        
        // Setup quotes with some invalid ones
        let testQuotes = [
            Quote(text: "Valid quote", author: "Valid Author", language: "en"),
            Quote(text: "", author: "Author", language: "en"),  // Invalid: empty text
            Quote(text: "Quote", author: "", language: "en"),   // Invalid: empty author
            Quote(text: "Quote", author: "Author", language: "english"),  // Invalid: language too long
            Quote(text: "Valid quote 2", author: "Author 2", language: "es")
        ]
        
        mockStore.collectionToReturn = QuoteCollection(
            quotes: testQuotes,
            version: "1.0.0",
            lastUpdated: Date(),
            sources: []
        )
        
        // Load quotes
        let loadedQuotes = try await repository.loadQuotes()
        
        // Should only have 2 valid quotes
        #expect(loadedQuotes.count == 2)
        #expect(loadedQuotes.allSatisfy { $0.isValid })
    }
    
    @Test("loadQuotes sanitizes control characters from quote text")
    func testQuoteSanitization() async throws {
        let mockStore = MockLocalQuoteStore()
        let mockSync = MockRemoteQuoteSync()
        let repository = LocalQuoteRepository(store: mockStore, remoteSync: mockSync)
        
        // Create quote with control characters
        let quoteWithControlChars = Quote(
            text: "Quote with\u{0007}control\u{001B}characters",
            author: "Author",
            language: "en"
        )
        
        mockStore.collectionToReturn = QuoteCollection(
            quotes: [quoteWithControlChars],
            version: "1.0.0",
            lastUpdated: Date(),
            sources: []
        )
        
        // Load quotes
        let loadedQuotes = try await repository.loadQuotes()
        
        // Verify control characters are removed
        #expect(loadedQuotes.count == 1)
        #expect(!loadedQuotes[0].text.contains("\u{0007}"))
        #expect(!loadedQuotes[0].text.contains("\u{001B}"))
    }
    
    @Test("loadQuotes enforces 500 character limit")
    func testQuoteLengthLimit() async throws {
        let mockStore = MockLocalQuoteStore()
        let mockSync = MockRemoteQuoteSync()
        let repository = LocalQuoteRepository(store: mockStore, remoteSync: mockSync)
        
        // Create quotes with different lengths
        let shortQuote = Quote(text: "Short quote", author: "Author", language: "en")
        let longQuote = Quote(
            text: String(repeating: "a", count: 501),  // 501 characters
            author: "Author",
            language: "en"
        )
        let maxLengthQuote = Quote(
            text: String(repeating: "b", count: 500),  // Exactly 500 characters
            author: "Author",
            language: "en"
        )
        
        mockStore.collectionToReturn = QuoteCollection(
            quotes: [shortQuote, longQuote, maxLengthQuote],
            version: "1.0.0",
            lastUpdated: Date(),
            sources: []
        )
        
        // Load quotes
        let loadedQuotes = try await repository.loadQuotes()
        
        // Should exclude the 501-character quote but include the 500-character one
        #expect(loadedQuotes.count == 2)
        #expect(loadedQuotes.allSatisfy { $0.text.count <= 500 })
    }
    
    @Test("loadQuotes excludes quotes with future dates")
    func testFutureDateValidation() async throws {
        let mockStore = MockLocalQuoteStore()
        let mockSync = MockRemoteQuoteSync()
        let repository = LocalQuoteRepository(store: mockStore, remoteSync: mockSync)
        
        let futureDate = Date().addingTimeInterval(86400)  // Tomorrow
        let pastDate = Date().addingTimeInterval(-86400)   // Yesterday
        
        let validQuote = Quote(text: "Valid", author: "Author", language: "en", dateAdded: pastDate)
        let futureQuote = Quote(text: "Future", author: "Author", language: "en", dateAdded: futureDate)
        
        mockStore.collectionToReturn = QuoteCollection(
            quotes: [validQuote, futureQuote],
            version: "1.0.0",
            lastUpdated: Date(),
            sources: []
        )
        
        // Load quotes
        let loadedQuotes = try await repository.loadQuotes()
        
        // Should only have the quote with past date
        #expect(loadedQuotes.count == 1)
        #expect(loadedQuotes[0].text == "Valid")
    }
    
    // MARK: - Test error handling for corrupted cache
    
    @Test("loadQuotes handles storage errors gracefully")
    func testCorruptedCacheHandling() async throws {
        let mockStore = MockLocalQuoteStore()
        let mockSync = MockRemoteQuoteSync()
        let repository = LocalQuoteRepository(store: mockStore, remoteSync: mockSync)
        
        // Simulate storage error
        mockStore.shouldThrowError = true
        
        // Verify error is wrapped in RepositoryError
        await #expect(throws: RepositoryError.self) {
            try await repository.loadQuotes()
        }
    }
    
    @Test("saveQuotes rejects invalid quotes")
    func testSaveInvalidQuotes() async throws {
        let mockStore = MockLocalQuoteStore()
        let mockSync = MockRemoteQuoteSync()
        let repository = LocalQuoteRepository(store: mockStore, remoteSync: mockSync)
        
        let invalidQuotes = [
            Quote(text: "", author: "Author", language: "en")  // Invalid: empty text
        ]
        
        // Verify error is thrown
        await #expect(throws: RepositoryError.self) {
            try await repository.saveQuotes(invalidQuotes)
        }
        
        // Verify nothing was written
        #expect(mockStore.lastWrittenCollection == nil)
    }
    
    @Test("saveQuotes handles storage errors")
    func testSaveQuotesStorageError() async throws {
        let mockStore = MockLocalQuoteStore()
        let mockSync = MockRemoteQuoteSync()
        let repository = LocalQuoteRepository(store: mockStore, remoteSync: mockSync)
        
        mockStore.shouldThrowError = true
        
        let validQuotes = [
            Quote(text: "Valid", author: "Author", language: "en")
        ]
        
        // Verify error is thrown
        await #expect(throws: RepositoryError.self) {
            try await repository.saveQuotes(validQuotes)
        }
    }
}

// MARK: - Mock Remote Sync for Testing

class MockRemoteQuoteSync: RemoteQuoteSync {
    var quotesToReturn: [Quote] = []
    var shouldThrowError = false
    var errorToThrow: Error = SyncError.networkUnavailable
    var validateSourceResult = true
    
    func fetchQuotes(from source: QuoteSource) async throws -> [Quote] {
        if shouldThrowError {
            throw errorToThrow
        }
        return quotesToReturn
    }
    
    func fetchAllSources() async throws -> [Quote] {
        if shouldThrowError {
            throw errorToThrow
        }
        return quotesToReturn
    }
    
    func validateSource(_ source: QuoteSource) async throws -> Bool {
        if shouldThrowError {
            throw errorToThrow
        }
        return validateSourceResult
    }
}
