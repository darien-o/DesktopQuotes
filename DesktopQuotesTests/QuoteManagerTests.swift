//
//  QuoteManagerTests.swift
//  DesktopQuotesTests
//
//  Created by Kiro on Enhanced Quote System Implementation
//

import XCTest
@testable import DesktopQuotes

final class QuoteManagerTests: XCTestCase {
    
    // MARK: - Mock Dependencies
    
    class MockQuoteRepository: QuoteRepository {
        var quotesToReturn: [Quote] = []
        var shouldThrowOnLoad = false
        var shouldFailSync = false
        var syncCallCount = 0
        var loadCallCount = 0
        
        func loadQuotes() async throws -> [Quote] {
            loadCallCount += 1
            if shouldThrowOnLoad {
                throw NSError(domain: "test", code: 1, userInfo: nil)
            }
            return quotesToReturn
        }
        
        func saveQuotes(_ quotes: [Quote]) async throws {
            // Not used in these tests
        }
        
        func syncWithRemote() async throws -> SyncResult {
            syncCallCount += 1
            if shouldFailSync {
                return SyncResult(
                    newQuotesCount: 0,
                    updatedQuotesCount: 0,
                    timestamp: Date(),
                    success: false,
                    error: NSError(domain: "test", code: 2, userInfo: nil)
                )
            }
            
            // Simulate successful sync
            quotesToReturn = [
                Quote(text: "Test quote 1", author: "Author 1"),
                Quote(text: "Test quote 2", author: "Author 2")
            ]
            
            return SyncResult(
                newQuotesCount: 2,
                updatedQuotesCount: 0,
                timestamp: Date(),
                success: true,
                error: nil
            )
        }
        
        func getQuotesByLanguage(_ languageCode: String) -> [Quote] {
            return quotesToReturn.filter { $0.language == languageCode }
        }
    }
    
    class MockBackgroundUpdateScheduler: BackgroundUpdateScheduler {
        var scheduleCallCount = 0
        var cancelCallCount = 0
        var immediateUpdateCallCount = 0
        var lastScheduledInterval: UpdateInterval?
        
        var isScheduled: Bool {
            lastScheduledInterval != nil
        }
        
        func scheduleUpdates(interval: UpdateInterval) {
            scheduleCallCount += 1
            lastScheduledInterval = interval
        }
        
        func cancelScheduledUpdates() {
            cancelCallCount += 1
            lastScheduledInterval = nil
        }
        
        func performImmediateUpdate() async {
            immediateUpdateCallCount += 1
        }
    }
    
    // MARK: - Test Cases
    
    func testInitializationWithExistingCache() async {
        // Given
        let mockRepo = MockQuoteRepository()
        mockRepo.quotesToReturn = [
            Quote(text: "Cached quote", author: "Cached Author")
        ]
        let mockScheduler = MockBackgroundUpdateScheduler()
        
        // When
        let manager = QuoteManager(repository: mockRepo, scheduler: mockScheduler)
        
        // Wait for initialization to complete
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then
        XCTAssertEqual(mockRepo.loadCallCount, 1, "Should load quotes on initialization")
        XCTAssertEqual(mockScheduler.scheduleCallCount, 1, "Should schedule background updates")
        XCTAssertEqual(mockScheduler.lastScheduledInterval, .daily, "Should schedule daily updates by default")
    }
    
    func testInitializationWithEmptyCache() async {
        // Given
        let mockRepo = MockQuoteRepository()
        mockRepo.quotesToReturn = [] // Empty cache
        let mockScheduler = MockBackgroundUpdateScheduler()
        
        // When
        let manager = QuoteManager(repository: mockRepo, scheduler: mockScheduler)
        
        // Wait for initialization and sync to complete
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Then
        XCTAssertEqual(mockRepo.loadCallCount, 2, "Should load quotes twice: initial load and after sync")
        XCTAssertEqual(mockRepo.syncCallCount, 1, "Should trigger sync when cache is empty")
        XCTAssertEqual(mockScheduler.scheduleCallCount, 1, "Should schedule background updates")
    }
    
    func testInitializationWithLoadFailure() async {
        // Given
        let mockRepo = MockQuoteRepository()
        mockRepo.shouldThrowOnLoad = true
        let mockScheduler = MockBackgroundUpdateScheduler()
        
        // When
        let manager = QuoteManager(repository: mockRepo, scheduler: mockScheduler)
        
        // Wait for initialization and sync to complete
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Then
        XCTAssertEqual(mockRepo.syncCallCount, 1, "Should trigger sync when load fails")
    }
    
    func testGetRandomQuoteWithAvailableQuotes() async {
        // Given
        let mockRepo = MockQuoteRepository()
        mockRepo.quotesToReturn = [
            Quote(text: "Quote 1", author: "Author 1"),
            Quote(text: "Quote 2", author: "Author 2"),
            Quote(text: "Quote 3", author: "Author 3")
        ]
        let mockScheduler = MockBackgroundUpdateScheduler()
        let manager = QuoteManager(repository: mockRepo, scheduler: mockScheduler)
        
        // Wait for initialization
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // When
        await MainActor.run {
            manager.getRandomQuote()
        }
        
        // Then
        await MainActor.run {
            XCTAssertTrue(
                mockRepo.quotesToReturn.contains(where: { $0.text == manager.currentQuote.text }),
                "Should return one of the available quotes"
            )
        }
    }
    
    func testGetRandomQuoteWithNoQuotes() async {
        // Given
        let mockRepo = MockQuoteRepository()
        mockRepo.quotesToReturn = []
        let mockScheduler = MockBackgroundUpdateScheduler()
        let manager = QuoteManager(repository: mockRepo, scheduler: mockScheduler)
        
        // Wait for initialization
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // When
        await MainActor.run {
            manager.getRandomQuote()
        }
        
        // Then
        await MainActor.run {
            XCTAssertEqual(manager.currentQuote.text, "Stay hungry, stay foolish.", "Should use fallback quote")
            XCTAssertEqual(manager.currentQuote.author, "Steve Jobs", "Should use fallback quote")
        }
    }
    
    func testManualSync() async {
        // Given
        let mockRepo = MockQuoteRepository()
        mockRepo.quotesToReturn = []
        let mockScheduler = MockBackgroundUpdateScheduler()
        let manager = QuoteManager(repository: mockRepo, scheduler: mockScheduler)
        
        // Wait for initialization
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        let initialSyncCount = mockRepo.syncCallCount
        
        // When
        await manager.manualSync()
        
        // Then
        XCTAssertGreaterThan(mockRepo.syncCallCount, initialSyncCount, "Should trigger sync on manual sync call")
    }
    
    func testExponentialBackoffOnSyncFailure() async {
        // Given
        let mockRepo = MockQuoteRepository()
        mockRepo.quotesToReturn = []
        mockRepo.shouldFailSync = true
        let mockScheduler = MockBackgroundUpdateScheduler()
        
        // When
        let manager = QuoteManager(repository: mockRepo, scheduler: mockScheduler)
        
        // Wait for initialization and retries (should attempt multiple times with backoff)
        // Base delay is 5 seconds, but we'll wait less for testing
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Then
        // Should have attempted sync multiple times due to exponential backoff
        XCTAssertGreaterThan(mockRepo.syncCallCount, 1, "Should retry sync on failure")
    }
    
    func testBackgroundSyncScheduling() async {
        // Given
        let mockRepo = MockQuoteRepository()
        mockRepo.quotesToReturn = [Quote(text: "Test", author: "Test")]
        let mockScheduler = MockBackgroundUpdateScheduler()
        
        // When
        let manager = QuoteManager(repository: mockRepo, scheduler: mockScheduler)
        
        // Wait for initialization
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // Then
        XCTAssertEqual(mockScheduler.scheduleCallCount, 1, "Should schedule background updates")
        XCTAssertEqual(mockScheduler.lastScheduledInterval, .daily, "Should use daily interval by default")
        XCTAssertTrue(mockScheduler.isScheduled, "Scheduler should be active")
    }
}
