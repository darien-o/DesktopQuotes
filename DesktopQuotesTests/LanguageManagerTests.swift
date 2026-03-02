//
//  LanguageManagerTests.swift
//  DesktopQuotesTests
//
//  Unit tests for LanguageManager
//

import Foundation
import Testing
@testable import DesktopQuotes

/// Unit tests for LanguageManager functionality
/// **Validates: Requirements 4.1, 4.2, 4.3, 4.5, 4.6, 4.8**
struct LanguageManagerTests {
    
    // MARK: - Enable/Disable Operations
    
    @Test("Enable a valid language code")
    func testEnableLanguage() async throws {
        let mockUserDefaults = UserDefaults(suiteName: "test.languageManager.\(UUID().uuidString)")!
        defer {
            mockUserDefaults.removePersistentDomain(forName: mockUserDefaults.persistentDomainNames().first ?? "")
        }
        let languageManager = DefaultLanguageManager(userDefaults: mockUserDefaults)
        
        // Enable Spanish
        languageManager.enableLanguage("es")
        
        #expect(languageManager.isLanguageEnabled("es"), "Spanish should be enabled")
        #expect(languageManager.enabledLanguages.contains("es"), "Spanish should be in enabled languages")
    }
    
    @Test("Disable a language when multiple are enabled")
    func testDisableLanguage() async throws {
        let mockUserDefaults = UserDefaults(suiteName: "test.languageManager.\(UUID().uuidString)")!
        defer {
            mockUserDefaults.removePersistentDomain(forName: mockUserDefaults.persistentDomainNames().first ?? "")
        }
        let languageManager = DefaultLanguageManager(userDefaults: mockUserDefaults)
        
        // Enable multiple languages
        languageManager.enableLanguage("es")
        languageManager.enableLanguage("fr")
        
        // Disable English
        languageManager.disableLanguage("en")
        
        #expect(!languageManager.isLanguageEnabled("en"), "English should be disabled")
        #expect(!languageManager.enabledLanguages.contains("en"), "English should not be in enabled languages")
        #expect(languageManager.isLanguageEnabled("es"), "Spanish should still be enabled")
        #expect(languageManager.isLanguageEnabled("fr"), "French should still be enabled")
    }
    
    @Test("Cannot disable the last remaining language")
    func testCannotDisableLastLanguage() async throws {
        let mockUserDefaults = UserDefaults(suiteName: "test.languageManager.\(UUID().uuidString)")!
        defer {
            mockUserDefaults.removePersistentDomain(forName: mockUserDefaults.persistentDomainNames().first ?? "")
        }
        let languageManager = DefaultLanguageManager(userDefaults: mockUserDefaults)
        
        // Should start with only English
        let initialLanguages = languageManager.enabledLanguages
        #expect(initialLanguages.count == 1, "Should start with one language")
        
        let lastLanguage = initialLanguages.first!
        languageManager.disableLanguage(lastLanguage)
        
        // Should still have that language
        #expect(languageManager.enabledLanguages.count == 1, "Should still have one language")
        #expect(languageManager.isLanguageEnabled(lastLanguage), "Last language should remain enabled")
    }
    
    // MARK: - UserDefaults Persistence
    
    @Test("Language preferences persist to UserDefaults")
    func testUserDefaultsPersistence() async throws {
        let suiteName = "test.languageManager.\(UUID().uuidString)"
        let mockUserDefaults = UserDefaults(suiteName: suiteName)!
        defer {
            mockUserDefaults.removePersistentDomain(forName: mockUserDefaults.persistentDomainNames().first ?? "")
        }
        
        // Create first instance and enable languages
        let languageManager1 = DefaultLanguageManager(userDefaults: mockUserDefaults)
        languageManager1.enableLanguage("es")
        languageManager1.enableLanguage("fr")
        
        // Create second instance with same UserDefaults
        let languageManager2 = DefaultLanguageManager(userDefaults: mockUserDefaults)
        
        // Should have the same enabled languages
        #expect(languageManager2.isLanguageEnabled("en"), "English should be persisted")
        #expect(languageManager2.isLanguageEnabled("es"), "Spanish should be persisted")
        #expect(languageManager2.isLanguageEnabled("fr"), "French should be persisted")
    }
    
    // MARK: - ISO 639-1 Validation
    
    @Test("Reject invalid language codes - uppercase")
    func testRejectUppercaseCode() async throws {
        let mockUserDefaults = UserDefaults(suiteName: "test.languageManager.\(UUID().uuidString)")!
        defer {
            mockUserDefaults.removePersistentDomain(forName: mockUserDefaults.persistentDomainNames().first ?? "")
        }
        let languageManager = DefaultLanguageManager(userDefaults: mockUserDefaults)
        
        let beforeCount = languageManager.enabledLanguages.count
        languageManager.enableLanguage("EN")
        
        #expect(!languageManager.isLanguageEnabled("EN"), "Uppercase code should be rejected")
        #expect(languageManager.enabledLanguages.count == beforeCount, "Count should not change")
    }
    
    @Test("Reject invalid language codes - wrong length")
    func testRejectWrongLengthCodes() async throws {
        let mockUserDefaults = UserDefaults(suiteName: "test.languageManager.\(UUID().uuidString)")!
        defer {
            mockUserDefaults.removePersistentDomain(forName: mockUserDefaults.persistentDomainNames().first ?? "")
        }
        let languageManager = DefaultLanguageManager(userDefaults: mockUserDefaults)
        
        let invalidCodes = ["e", "eng", "english", ""]
        
        for code in invalidCodes {
            let beforeCount = languageManager.enabledLanguages.count
            languageManager.enableLanguage(code)
            
            #expect(!languageManager.isLanguageEnabled(code), "Code '\(code)' should be rejected")
            #expect(languageManager.enabledLanguages.count == beforeCount, "Count should not change for '\(code)'")
        }
    }
    
    @Test("Reject invalid language codes - not in available list")
    func testRejectUnavailableCodes() async throws {
        let mockUserDefaults = UserDefaults(suiteName: "test.languageManager.\(UUID().uuidString)")!
        defer {
            mockUserDefaults.removePersistentDomain(forName: mockUserDefaults.persistentDomainNames().first ?? "")
        }
        let languageManager = DefaultLanguageManager(userDefaults: mockUserDefaults)
        
        let unavailableCodes = ["xx", "zz", "qq"]
        
        for code in unavailableCodes {
            let beforeCount = languageManager.enabledLanguages.count
            languageManager.enableLanguage(code)
            
            #expect(!languageManager.isLanguageEnabled(code), "Code '\(code)' should be rejected")
            #expect(languageManager.enabledLanguages.count == beforeCount, "Count should not change for '\(code)'")
        }
    }
    
    // MARK: - Available Languages Enumeration
    
    @Test("Get available languages returns language metadata")
    func testGetAvailableLanguages() async throws {
        let mockUserDefaults = UserDefaults(suiteName: "test.languageManager.\(UUID().uuidString)")!
        defer {
            mockUserDefaults.removePersistentDomain(forName: mockUserDefaults.persistentDomainNames().first ?? "")
        }
        let languageManager = DefaultLanguageManager(userDefaults: mockUserDefaults)
        
        let availableLanguages = languageManager.getAvailableLanguages()
        
        // Should have multiple languages
        #expect(availableLanguages.count > 0, "Should have available languages")
        
        // Check English is available
        let english = availableLanguages.first { $0.code == "en" }
        #expect(english != nil, "English should be available")
        #expect(english?.name == "English", "English name should be correct")
        #expect(english?.nativeName == "English", "English native name should be correct")
        
        // Check Spanish is available
        let spanish = availableLanguages.first { $0.code == "es" }
        #expect(spanish != nil, "Spanish should be available")
        #expect(spanish?.name == "Spanish", "Spanish name should be correct")
        #expect(spanish?.nativeName == "Español", "Spanish native name should be correct")
        
        // All languages should have valid ISO 639-1 codes
        for language in availableLanguages {
            #expect(language.code.count == 2, "Language code should be 2 characters")
            #expect(language.code.allSatisfy { $0.isLetter && $0.isLowercase }, 
                   "Language code should be lowercase letters")
            #expect(!language.name.isEmpty, "Language name should not be empty")
            #expect(!language.nativeName.isEmpty, "Native name should not be empty")
        }
    }
    
    // MARK: - Minimum One Language Enforcement
    
    @Test("Setting empty array defaults to English")
    func testEmptyArrayDefaultsToEnglish() async throws {
        let mockUserDefaults = UserDefaults(suiteName: "test.languageManager.\(UUID().uuidString)")!
        defer {
            mockUserDefaults.removePersistentDomain(forName: mockUserDefaults.persistentDomainNames().first ?? "")
        }
        let languageManager = DefaultLanguageManager(userDefaults: mockUserDefaults)
        
        // Try to set empty array
        languageManager.enabledLanguages = []
        
        // Should default to at least one language
        #expect(!languageManager.enabledLanguages.isEmpty, "Should not be empty")
        #expect(languageManager.enabledLanguages.count >= 1, "Should have at least one language")
    }
    
    @Test("Setting invalid codes filters them out")
    func testInvalidCodesFilteredOut() async throws {
        let mockUserDefaults = UserDefaults(suiteName: "test.languageManager.\(UUID().uuidString)")!
        defer {
            mockUserDefaults.removePersistentDomain(forName: mockUserDefaults.persistentDomainNames().first ?? "")
        }
        let languageManager = DefaultLanguageManager(userDefaults: mockUserDefaults)
        
        // Set mix of valid and invalid codes
        languageManager.enabledLanguages = ["en", "ES", "fr", "xxx", "de"]
        
        let enabled = languageManager.enabledLanguages
        
        // Should only have valid codes
        #expect(enabled.contains("en"), "Valid code 'en' should be included")
        #expect(enabled.contains("fr"), "Valid code 'fr' should be included")
        #expect(enabled.contains("de"), "Valid code 'de' should be included")
        #expect(!enabled.contains("ES"), "Invalid code 'ES' should be filtered out")
        #expect(!enabled.contains("xxx"), "Invalid code 'xxx' should be filtered out")
    }
    
    // MARK: - isLanguageEnabled Tests
    
    @Test("isLanguageEnabled returns correct status")
    func testIsLanguageEnabled() async throws {
        let mockUserDefaults = UserDefaults(suiteName: "test.languageManager.\(UUID().uuidString)")!
        defer {
            mockUserDefaults.removePersistentDomain(forName: mockUserDefaults.persistentDomainNames().first ?? "")
        }
        let languageManager = DefaultLanguageManager(userDefaults: mockUserDefaults)
        
        // English should be enabled by default
        #expect(languageManager.isLanguageEnabled("en"), "English should be enabled by default")
        
        // Spanish should not be enabled
        #expect(!languageManager.isLanguageEnabled("es"), "Spanish should not be enabled initially")
        
        // Enable Spanish
        languageManager.enableLanguage("es")
        #expect(languageManager.isLanguageEnabled("es"), "Spanish should be enabled after enabling")
    }
    
    @Test("Enabling same language twice doesn't duplicate")
    func testNoDuplicateLanguages() async throws {
        let mockUserDefaults = UserDefaults(suiteName: "test.languageManager.\(UUID().uuidString)")!
        defer {
            mockUserDefaults.removePersistentDomain(forName: mockUserDefaults.persistentDomainNames().first ?? "")
        }
        let languageManager = DefaultLanguageManager(userDefaults: mockUserDefaults)
        
        // Enable Spanish multiple times
        languageManager.enableLanguage("es")
        languageManager.enableLanguage("es")
        languageManager.enableLanguage("es")
        
        let enabled = languageManager.enabledLanguages
        let spanishCount = enabled.filter { $0 == "es" }.count
        
        #expect(spanishCount == 1, "Spanish should only appear once")
    }
}
