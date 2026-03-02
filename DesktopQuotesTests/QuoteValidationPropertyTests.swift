//
//  QuoteValidationPropertyTests.swift
//  DesktopQuotesTests
//
//  Property-based tests for Quote validation
//

import Foundation
import Testing
@testable import DesktopQuotes

/// **Validates: Requirements 5.1, 5.2, 5.3, 5.4, 5.5, 5.6**
/// Property 1: Quote Validity - All loaded quotes must pass isValid check
struct QuoteValidationPropertyTests {
    
    // MARK: - Property Test: Quote Validity
    
    @Test("Property: Valid quotes have non-empty text, non-empty author, and 2-char language code")
    func testQuoteValidityProperty() async throws {
        // Generate random valid quotes and verify isValid returns true
        let validQuotes = generateValidQuotes(count: 100)
        
        for quote in validQuotes {
            #expect(quote.isValid == true, "Valid quote should pass isValid check: \(quote)")
        }
    }
    
    @Test("Property: Quotes with empty text are invalid")
    func testEmptyTextInvalid() async throws {
        let invalidQuotes = generateQuotesWithEmptyText(count: 50)
        
        for quote in invalidQuotes {
            #expect(quote.isValid == false, "Quote with empty text should be invalid")
        }
    }
    
    @Test("Property: Quotes with empty author are invalid")
    func testEmptyAuthorInvalid() async throws {
        let invalidQuotes = generateQuotesWithEmptyAuthor(count: 50)
        
        for quote in invalidQuotes {
            #expect(quote.isValid == false, "Quote with empty author should be invalid")
        }
    }
    
    @Test("Property: Quotes with invalid language codes are invalid")
    func testInvalidLanguageCodeInvalid() async throws {
        let invalidQuotes = generateQuotesWithInvalidLanguageCodes(count: 50)
        
        for quote in invalidQuotes {
            #expect(quote.isValid == false, "Quote with invalid language code should be invalid: \(quote.language)")
        }
    }
    
    @Test("Property: Valid quotes maintain validity after creation")
    func testValidityIdempotence() async throws {
        let quotes = generateValidQuotes(count: 100)
        
        for quote in quotes {
            let firstCheck = quote.isValid
            let secondCheck = quote.isValid
            #expect(firstCheck == secondCheck, "isValid should be idempotent")
            #expect(firstCheck == true, "Valid quote should remain valid")
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
        
        let validLanguageCodes = ["en", "es", "fr", "de", "it", "pt", "ru", "ja", "zh", "ar"]
        
        return (0..<count).map { index in
            Quote(
                text: sampleTexts[index % sampleTexts.count],
                author: sampleAuthors[index % sampleAuthors.count],
                language: validLanguageCodes[index % validLanguageCodes.count],
                tags: ["inspiration", "wisdom"],
                source: "test-source",
                dateAdded: Date()
            )
        }
    }
    
    private func generateQuotesWithEmptyText(count: Int) -> [Quote] {
        return (0..<count).map { _ in
            Quote(
                text: "",
                author: "Valid Author",
                language: "en",
                tags: [],
                source: "test",
                dateAdded: Date()
            )
        }
    }
    
    private func generateQuotesWithEmptyAuthor(count: Int) -> [Quote] {
        return (0..<count).map { _ in
            Quote(
                text: "Valid quote text",
                author: "",
                language: "en",
                tags: [],
                source: "test",
                dateAdded: Date()
            )
        }
    }
    
    private func generateQuotesWithInvalidLanguageCodes(count: Int) -> [Quote] {
        let invalidCodes = ["", "e", "eng", "english", "123", "e1", " en", "en ", "E N"]
        
        return (0..<count).map { index in
            Quote(
                text: "Valid quote text",
                author: "Valid Author",
                language: invalidCodes[index % invalidCodes.count],
                tags: [],
                source: "test",
                dateAdded: Date()
            )
        }
    }
}
