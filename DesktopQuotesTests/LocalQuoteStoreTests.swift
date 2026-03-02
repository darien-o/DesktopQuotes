//
//  LocalQuoteStoreTests.swift
//  DesktopQuotesTests
//
//  Created by Kiro on Enhanced Quote System Implementation
//

import XCTest
@testable import DesktopQuotes

final class LocalQuoteStoreTests: XCTestCase {
    var store: JSONLocalQuoteStore!
    var testFileURL: URL!
    
    override func setUp() async throws {
        try await super.setUp()
        store = JSONLocalQuoteStore()
        
        // Clean up any existing test files
        if store.exists() {
            try? await cleanupTestFile()
        }
    }
    
    override func tearDown() async throws {
        // Clean up test files after each test
        try? await cleanupTestFile()
        store = nil
        try await super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    private func cleanupTestFile() async throws {
        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }
        let appDirectory = appSupport.appendingPathComponent("DesktopQuotes", isDirectory: true)
        let fileURL = appDirectory.appendingPathComponent("quotes.json")
        
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
    }
    
    private func createTestQuoteCollection() -> QuoteCollection {
        let quotes = [
            Quote(text: "Test quote 1", author: "Author 1", language: "en"),
            Quote(text: "Test quote 2", author: "Author 2", language: "es")
        ]
        let sources = [
            QuoteSource(id: "source1", url: "https://example.com", name: "Test Source", enabled: true)
        ]
        return QuoteCollection(
            quotes: quotes,
            version: "1.0.0",
            lastUpdated: Date(),
            sources: sources
        )
    }
    
    // MARK: - Test Successful Read/Write Operations
    
    func testSuccessfulWriteAndRead() async throws {
        // Given
        let collection = createTestQuoteCollection()
        
        // When - Write
        try await store.write(collection)
        
        // Then - File should exist
        XCTAssertTrue(store.exists(), "File should exist after write")
        
        // When - Read
        let readCollection = try await store.read()
        
        // Then - Data should match
        XCTAssertEqual(readCollection.quotes.count, collection.quotes.count)
        XCTAssertEqual(readCollection.version, collection.version)
        XCTAssertEqual(readCollection.sources.count, collection.sources.count)
        XCTAssertEqual(readCollection.quotes[0].text, "Test quote 1")
        XCTAssertEqual(readCollection.quotes[1].author, "Author 2")
    }
    
    func testMultipleWritesOverwrite() async throws {
        // Given
        let collection1 = createTestQuoteCollection()
        let collection2 = QuoteCollection(
            quotes: [Quote(text: "New quote", author: "New Author", language: "fr")],
            version: "2.0.0",
            lastUpdated: Date(),
            sources: []
        )
        
        // When
        try await store.write(collection1)
        try await store.write(collection2)
        
        // Then - Should have the second collection
        let readCollection = try await store.read()
        XCTAssertEqual(readCollection.quotes.count, 1)
        XCTAssertEqual(readCollection.quotes[0].text, "New quote")
        XCTAssertEqual(readCollection.version, "2.0.0")
    }
    
    // MARK: - Test Handling of Missing Files
    
    func testReadThrowsErrorWhenFileDoesNotExist() async throws {
        // Given - No file exists
        XCTAssertFalse(store.exists())
        
        // When/Then - Should throw fileNotFound error
        do {
            _ = try await store.read()
            XCTFail("Should have thrown fileNotFound error")
        } catch let error as LocalStoreError {
            if case .fileNotFound = error {
                // Success
            } else {
                XCTFail("Expected fileNotFound error, got \(error)")
            }
        }
    }
    
    func testExistsReturnsFalseWhenFileDoesNotExist() {
        // Given - No file exists
        // When
        let exists = store.exists()
        
        // Then
        XCTAssertFalse(exists)
    }
    
    func testGetLastModifiedReturnsNilWhenFileDoesNotExist() {
        // Given - No file exists
        // When
        let lastModified = store.getLastModified()
        
        // Then
        XCTAssertNil(lastModified)
    }
    
    // MARK: - Test Handling of Corrupted JSON
    
    func testReadThrowsErrorForCorruptedJSON() async throws {
        // Given - Write corrupted JSON directly to file
        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            XCTFail("Could not get app support directory")
            return
        }
        let appDirectory = appSupport.appendingPathComponent("DesktopQuotes", isDirectory: true)
        try fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
        let fileURL = appDirectory.appendingPathComponent("quotes.json")
        
        let corruptedData = "{ invalid json content }".data(using: .utf8)!
        try corruptedData.write(to: fileURL)
        
        // When/Then - Should throw decodingFailed error
        do {
            _ = try await store.read()
            XCTFail("Should have thrown decodingFailed error")
        } catch let error as LocalStoreError {
            if case .decodingFailed = error {
                // Success
            } else {
                XCTFail("Expected decodingFailed error, got \(error)")
            }
        }
    }
    
    // MARK: - Test Atomic Write Operations
    
    func testAtomicWritePreventsConcurrentCorruption() async throws {
        // Given
        let collection1 = createTestQuoteCollection()
        let collection2 = QuoteCollection(
            quotes: [Quote(text: "Concurrent quote", author: "Concurrent Author", language: "de")],
            version: "1.5.0",
            lastUpdated: Date(),
            sources: []
        )
        
        // When - Perform concurrent writes
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                try? await self.store.write(collection1)
            }
            group.addTask {
                try? await self.store.write(collection2)
            }
        }
        
        // Then - File should be readable (not corrupted)
        let readCollection = try await store.read()
        XCTAssertTrue(readCollection.quotes.count > 0, "Should have valid quotes after concurrent writes")
        // Either collection1 or collection2 should be present, but not corrupted
        XCTAssertTrue(
            readCollection.quotes[0].text == "Test quote 1" || readCollection.quotes[0].text == "Concurrent quote",
            "Should have one of the written collections"
        )
    }
    
    // MARK: - Test File Permission Settings
    
    func testFilePermissionsAreRestrictive() async throws {
        // Given
        let collection = createTestQuoteCollection()
        
        // When
        try await store.write(collection)
        
        // Then - Check file permissions
        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            XCTFail("Could not get app support directory")
            return
        }
        let appDirectory = appSupport.appendingPathComponent("DesktopQuotes", isDirectory: true)
        let fileURL = appDirectory.appendingPathComponent("quotes.json")
        
        let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
        let permissions = attributes[.posixPermissions] as? NSNumber
        
        // Should be 0o600 (user read/write only)
        XCTAssertEqual(permissions?.intValue, 0o600, "File permissions should be user read/write only (0o600)")
    }
    
    // MARK: - Test getLastModified
    
    func testGetLastModifiedReturnsCorrectDate() async throws {
        // Given
        let beforeWrite = Date()
        let collection = createTestQuoteCollection()
        
        // When
        try await store.write(collection)
        let afterWrite = Date()
        
        // Then
        let lastModified = store.getLastModified()
        XCTAssertNotNil(lastModified)
        
        if let lastModified = lastModified {
            XCTAssertTrue(lastModified >= beforeWrite, "Last modified should be after or equal to before write time")
            XCTAssertTrue(lastModified <= afterWrite, "Last modified should be before or equal to after write time")
        }
    }
    
    // MARK: - Test Edge Cases
    
    func testWriteEmptyQuoteCollection() async throws {
        // Given
        let emptyCollection = QuoteCollection(
            quotes: [],
            version: "1.0.0",
            lastUpdated: Date(),
            sources: []
        )
        
        // When
        try await store.write(emptyCollection)
        
        // Then
        let readCollection = try await store.read()
        XCTAssertEqual(readCollection.quotes.count, 0)
        XCTAssertEqual(readCollection.version, "1.0.0")
    }
    
    func testWriteLargeQuoteCollection() async throws {
        // Given - Create a large collection
        let quotes = (0..<1000).map { i in
            Quote(text: "Quote \(i)", author: "Author \(i)", language: "en")
        }
        let collection = QuoteCollection(
            quotes: quotes,
            version: "1.0.0",
            lastUpdated: Date(),
            sources: []
        )
        
        // When
        try await store.write(collection)
        
        // Then
        let readCollection = try await store.read()
        XCTAssertEqual(readCollection.quotes.count, 1000)
    }
}
