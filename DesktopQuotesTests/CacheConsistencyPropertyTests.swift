//
//  CacheConsistencyPropertyTests.swift
//  DesktopQuotesTests
//
//  Property-based tests for cache consistency
//

import Foundation
import Testing
@testable import DesktopQuotes

/// **Validates: Requirements 1.7, 14.2, 14.7**
/// Property 5: Cache Consistency - Quote count in metadata always matches actual count
struct CacheConsistencyPropertyTests {
    
    // MARK: - Property Test: Cache Consistency
    
    @Test("Property: Quote count in collection matches actual quote array count")
    func testCacheConsistencyProperty() async throws {
        // Create a mock store for testing
        let mockStore = MockLocalQuoteStore()
        let mockSync = MockRemoteQuoteSync()
        let repository = LocalQuoteRepository(store: mockStore, remoteSync: mockSync)
        
        // Generate random quote sets and verify consistency
        for _ in 0..<50 {
            let quoteCount = Int.random(in: 0...100)
            let quotes = generateValidQuotes(count: quoteCount)
            
            // Save quotes
            try await repository.saveQuotes(quotes)
            
            // Verify the saved collection has consistent count
            if let savedCollection = mockStore.lastWrittenCollection {
                #expect(savedCollection.quotes.count == quoteCount,
                       "Saved collection quote count (\(savedCollection.quotes.count)) should match expected count (\(quoteCount))")
            }
            
            // Load quotes back
            mockStore.collectionToReturn = mockStore.lastWrittenCollection
            let loadedQuotes = try await repository.loadQuotes()
            
            // Verify loaded count matches saved count
            #expect(loadedQuotes.count == quoteCount,
                   "Loaded quote count (\(loadedQuotes.count)) should match saved count (\(quoteCount))")
        }
    }
    
    @Test("Property: Empty quote collection maintains consistency")
    func testEmptyCollectionConsistency() async throws {
        let mockStore = MockLocalQuoteStore()
        let mockSync = MockRemoteQuoteSync()
        let repository = LocalQuoteRepository(store: mockStore, remoteSync: mockSync)
        
        // Save empty collection
        try await repository.saveQuotes([])
        
        // Verify consistency
        if let savedCollection = mockStore.lastWrittenCollection {
            #expect(savedCollection.quotes.count == 0,
                   "Empty collection should have zero quotes")
        }
        
        // Load and verify
        mockStore.collectionToReturn = mockStore.lastWrittenCollection
        let loadedQuotes = try await repository.loadQuotes()
        #expect(loadedQuotes.count == 0, "Loaded empty collection should have zero quotes")
    }
    
    @Test("Property: Large quote collection maintains consistency")
    func testLargeCollectionConsistency() async throws {
        let mockStore = MockLocalQuoteStore()
        let mockSync = MockRemoteQuoteSync()
        let repository = LocalQuoteRepository(store: mockStore, remoteSync: mockSync)
        
        // Test with large collection
        let largeCount = 1000
        let quotes = generateValidQuotes(count: largeCount)
        
        try await repository.saveQuotes(quotes)
        
        if let savedCollection = mockStore.lastWrittenCollection {
            #expect(savedCollection.quotes.count == largeCount,
                   "Large collection should maintain correct count")
        }
        
        mockStore.collectionToReturn = mockStore.lastWrittenCollection
        let loadedQuotes = try await repository.loadQuotes()
        #expect(loadedQuotes.count == largeCount,
               "Loaded large collection should have correct count")
    }
    
    @Test("Property: Multiple save operations maintain consistency")
    func testMultipleSaveConsistency() async throws {
        let mockStore = MockLocalQuoteStore()
        let mockSync = MockRemoteQuoteSync()
        let repository = LocalQuoteRepository(store: mockStore, remoteSync: mockSync)
        
        // Perform multiple save operations with different counts
        let counts = [10, 25, 50, 5, 100, 0, 75]
        
        for count in counts {
            let quotes = generateValidQuotes(count: count)
            try await repository.saveQuotes(quotes)
            
            if let savedCollection = mockStore.lastWrittenCollection {
                #expect(savedCollection.quotes.count == count,
                       "Each save should maintain consistency for count \(count)")
            }
            
            mockStore.collectionToReturn = mockStore.lastWrittenCollection
            let loadedQuotes = try await repository.loadQuotes()
            #expect(loadedQuotes.count == count,
                   "Each load should return consistent count \(count)")
        }
    }
    
    // MARK: - Test Data Generators
    
    private func generateValidQuotes(count: Int) -> [Quote] {
        let sampleTexts = [
            "The only way to do great work is to love what you do.",
            "Innovation distinguishes between a leader and a follower.",
            "Stay hungry, stay foolish.",
            "Life is what happens when you're busy making other plans.",
            "The future belongs to those who believe in the beauty of their dreams."
        ]
        
        let sampleAuthors = [
            "Steve Jobs",
            "Albert Einstein",
            "Maya Angelou",
            "John Lennon",
            "Eleanor Roosevelt"
        ]
        
        let validLanguageCodes = ["en", "es", "fr", "de", "it"]
        
        return (0..<count).map { index in
            Quote(
                id: UUID(),
                text: sampleTexts[index % sampleTexts.count],
                author: sampleAuthors[index % sampleAuthors.count],
                language: validLanguageCodes[index % validLanguageCodes.count],
                tags: ["test"],
                source: "test-source",
                dateAdded: Date()
            )
        }
    }
}

// MARK: - Mock Store for Testing

class MockLocalQuoteStore: LocalQuoteStore {
    var collectionToReturn: QuoteCollection?
    var lastWrittenCollection: QuoteCollection?
    var shouldThrowError = false
    var fileExists = true
    
    func read() async throws -> QuoteCollection {
        if shouldThrowError {
            throw LocalStoreError.fileNotFound
        }
        
        guard let collection = collectionToReturn else {
            throw LocalStoreError.fileNotFound
        }
        
        return collection
    }
    
    func write(_ collection: QuoteCollection) async throws {
        if shouldThrowError {
            throw LocalStoreError.writeFailed(NSError(domain: "test", code: 1))
        }
        
        lastWrittenCollection = collection
    }
    
    func exists() -> Bool {
        return fileExists
    }
    
    func getLastModified() -> Date? {
        return fileExists ? Date() : nil
    }
}
