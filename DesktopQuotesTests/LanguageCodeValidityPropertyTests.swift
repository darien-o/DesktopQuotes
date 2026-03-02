//
//  LanguageCodeValidityPropertyTests.swift
//  DesktopQuotesTests
//
//  Property-based tests for language code validity
//

import Foundation
import Testing
@testable import DesktopQuotes

/// **Validates: Requirements 4.5, 13.6**
/// Property 2: Language Code Validity - All enabled languages are valid ISO 639-1 codes
struct LanguageCodeValidityPropertyTests {
    
    // MARK: - Property Tests
    
    @Test("Property: All enabled languages are valid ISO 639-1 codes after random operations")
    func testAllEnabledLanguagesAreValidISO639Codes() async throws {
        let mockUserDefaults = UserDefaults(suiteName: "test.languageCodeValidity.\(UUID().uuidString)")!
        defer {
            mockUserDefaults.removePersistentDomain(forName: mockUserDefaults.persistentDomainNames().first ?? "")
        }
        let languageManager = DefaultLanguageManager(userDefaults: mockUserDefaults)
        
        // Test with multiple random operations
        for _ in 0..<100 {
            // Generate random operations: enable, disable, or set multiple languages
            let operation = Int.random(in: 0...2)
            
            switch operation {
            case 0:
                // Enable a random language (valid or invalid)
                let code = generateRandomLanguageCode()
                languageManager.enableLanguage(code)
                
            case 1:
                // Disable a random language
                let enabledLangs = languageManager.enabledLanguages
                if !enabledLangs.isEmpty {
                    let code = enabledLangs.randomElement()!
                    languageManager.disableLanguage(code)
                }
                
            case 2:
                // Set multiple languages at once
                let codes = (0..<Int.random(in: 1...5)).map { _ in generateRandomLanguageCode() }
                languageManager.enabledLanguages = codes
                
            default:
                break
            }
            
            // Property: All enabled languages must be valid ISO 639-1 codes
            let enabledLanguages = languageManager.enabledLanguages
            
            // Check all enabled languages are valid
            for code in enabledLanguages {
                #expect(code.count == 2, "Language code '\(code)' must be exactly 2 characters")
                #expect(code.allSatisfy { $0.isLetter && $0.isLowercase }, 
                       "Language code '\(code)' must contain only lowercase letters")
                
                // Verify it's in the available languages list
                let availableLanguages = languageManager.getAvailableLanguages()
                #expect(availableLanguages.contains { $0.code == code },
                       "Language code '\(code)' must be in available languages list")
            }
            
            // Additional invariant: At least one language must always be enabled
            #expect(!enabledLanguages.isEmpty, "At least one language must always be enabled")
        }
    }
    
    @Test("Property: Invalid language codes are rejected")
    func testInvalidLanguageCodesAreRejected() async throws {
        let mockUserDefaults = UserDefaults(suiteName: "test.languageCodeValidity.\(UUID().uuidString)")!
        defer {
            mockUserDefaults.removePersistentDomain(forName: mockUserDefaults.persistentDomainNames().first ?? "")
        }
        let languageManager = DefaultLanguageManager(userDefaults: mockUserDefaults)
        
        let invalidCodes = [
            "EN",           // Uppercase
            "e",            // Too short
            "eng",          // Too long
            "e1",           // Contains number
            "e-",           // Contains special char
            "",             // Empty
            "xx",           // Not in available list
            "zz"            // Not in available list
        ]
        
        for invalidCode in invalidCodes {
            let beforeCount = languageManager.enabledLanguages.count
            languageManager.enableLanguage(invalidCode)
            
            // Invalid codes should not be added
            #expect(!languageManager.enabledLanguages.contains(invalidCode),
                   "Invalid code '\(invalidCode)' should not be enabled")
            #expect(languageManager.enabledLanguages.count == beforeCount,
                   "Enabling invalid code '\(invalidCode)' should not change count")
        }
    }
    
    @Test("Property: At least one language is always enabled")
    func testAtLeastOneLanguageAlwaysEnabled() async throws {
        let mockUserDefaults = UserDefaults(suiteName: "test.languageCodeValidity.\(UUID().uuidString)")!
        defer {
            mockUserDefaults.removePersistentDomain(forName: mockUserDefaults.persistentDomainNames().first ?? "")
        }
        let languageManager = DefaultLanguageManager(userDefaults: mockUserDefaults)
        
        // Try various ways to disable all languages
        for _ in 0..<50 {
            // Attempt 1: Disable all languages one by one
            while languageManager.enabledLanguages.count > 1 {
                let code = languageManager.enabledLanguages.first!
                languageManager.disableLanguage(code)
            }
            
            // Should still have one language
            #expect(languageManager.enabledLanguages.count == 1,
                   "At least one language must remain enabled")
            
            // Attempt 2: Try to disable the last language
            let lastCode = languageManager.enabledLanguages.first!
            languageManager.disableLanguage(lastCode)
            
            // Should still have that language
            #expect(languageManager.enabledLanguages.count == 1,
                   "Cannot disable the last remaining language")
            #expect(languageManager.enabledLanguages.contains(lastCode),
                   "Last language should remain enabled")
            
            // Attempt 3: Set to empty array
            languageManager.enabledLanguages = []
            
            // Should default to English
            #expect(!languageManager.enabledLanguages.isEmpty,
                   "Setting empty array should default to at least one language")
            
            // Reset for next iteration
            languageManager.enableLanguage("es")
        }
    }
    
    @Test("Property: Valid language codes are properly enabled")
    func testValidLanguageCodesAreEnabled() async throws {
        let mockUserDefaults = UserDefaults(suiteName: "test.languageCodeValidity.\(UUID().uuidString)")!
        defer {
            mockUserDefaults.removePersistentDomain(forName: mockUserDefaults.persistentDomainNames().first ?? "")
        }
        let languageManager = DefaultLanguageManager(userDefaults: mockUserDefaults)
        
        let validCodes = ["en", "es", "fr", "de", "it", "pt", "ru", "ja", "zh"]
        
        for code in validCodes {
            languageManager.enableLanguage(code)
            
            // Valid codes should be enabled
            #expect(languageManager.isLanguageEnabled(code),
                   "Valid code '\(code)' should be enabled")
            #expect(languageManager.enabledLanguages.contains(code),
                   "Valid code '\(code)' should be in enabled languages")
        }
    }
    
    // MARK: - Helper Methods
    
    private func generateRandomLanguageCode() -> String {
        let validCodes = ["en", "es", "fr", "de", "it", "pt", "ru", "ja", "zh", "ar", "hi", "ko"]
        let invalidCodes = ["EN", "e", "eng", "e1", "xx", "zz", ""]
        
        // 70% chance of valid code, 30% chance of invalid
        if Int.random(in: 0...9) < 7 {
            return validCodes.randomElement()!
        } else {
            return invalidCodes.randomElement()!
        }
    }
}
