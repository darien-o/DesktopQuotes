//
//  LanguageManager.swift
//  DesktopQuotes
//
//  Multi-language support with user preferences
//

import Foundation

protocol LanguageManager {
    var enabledLanguages: [String] { get set }
    var preferredLanguages: [String] { get }
    
    func isLanguageEnabled(_ code: String) -> Bool
    func enableLanguage(_ code: String)
    func disableLanguage(_ code: String)
    func getAvailableLanguages() -> [Language]
}

struct Language: Identifiable, Codable {
    let id: String
    let code: String
    let name: String
    let nativeName: String
    
    init(code: String, name: String, nativeName: String) {
        self.id = code
        self.code = code
        self.name = name
        self.nativeName = nativeName
    }
}

class DefaultLanguageManager: LanguageManager {
    private let userDefaults: UserDefaults
    private let enabledLanguagesKey = "enabledLanguages"
    
    // ISO 639-1 language codes with metadata
    private let availableLanguages: [Language] = [
        Language(code: "en", name: "English", nativeName: "English"),
        Language(code: "es", name: "Spanish", nativeName: "Español"),
        Language(code: "fr", name: "French", nativeName: "Français"),
        Language(code: "de", name: "German", nativeName: "Deutsch"),
        Language(code: "it", name: "Italian", nativeName: "Italiano"),
        Language(code: "pt", name: "Portuguese", nativeName: "Português"),
        Language(code: "ru", name: "Russian", nativeName: "Русский"),
        Language(code: "ja", name: "Japanese", nativeName: "日本語"),
        Language(code: "zh", name: "Chinese", nativeName: "中文"),
        Language(code: "ar", name: "Arabic", nativeName: "العربية"),
        Language(code: "hi", name: "Hindi", nativeName: "हिन्दी"),
        Language(code: "ko", name: "Korean", nativeName: "한국어"),
        Language(code: "nl", name: "Dutch", nativeName: "Nederlands"),
        Language(code: "pl", name: "Polish", nativeName: "Polski"),
        Language(code: "tr", name: "Turkish", nativeName: "Türkçe"),
        Language(code: "sv", name: "Swedish", nativeName: "Svenska"),
        Language(code: "da", name: "Danish", nativeName: "Dansk"),
        Language(code: "fi", name: "Finnish", nativeName: "Suomi"),
        Language(code: "no", name: "Norwegian", nativeName: "Norsk"),
        Language(code: "cs", name: "Czech", nativeName: "Čeština"),
        Language(code: "el", name: "Greek", nativeName: "Ελληνικά"),
        Language(code: "he", name: "Hebrew", nativeName: "עברית"),
        Language(code: "th", name: "Thai", nativeName: "ไทย"),
        Language(code: "vi", name: "Vietnamese", nativeName: "Tiếng Việt"),
        Language(code: "id", name: "Indonesian", nativeName: "Bahasa Indonesia")
    ]
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        
        // Initialize with default if no preferences exist
        if userDefaults.array(forKey: enabledLanguagesKey) == nil {
            userDefaults.set(["en"], forKey: enabledLanguagesKey)
        }
    }
    
    var enabledLanguages: [String] {
        get {
            let languages = userDefaults.stringArray(forKey: enabledLanguagesKey) ?? ["en"]
            // Validate all codes are ISO 639-1
            let validLanguages = languages.filter { isValidISO639Code($0) }
            // Ensure at least one language is enabled
            return validLanguages.isEmpty ? ["en"] : validLanguages
        }
        set {
            // Validate all codes
            let validLanguages = newValue.filter { isValidISO639Code($0) }
            // Ensure at least one language remains enabled
            let languagesToSave = validLanguages.isEmpty ? ["en"] : validLanguages
            userDefaults.set(languagesToSave, forKey: enabledLanguagesKey)
        }
    }
    
    var preferredLanguages: [String] {
        return enabledLanguages
    }
    
    func isLanguageEnabled(_ code: String) -> Bool {
        return enabledLanguages.contains(code)
    }
    
    func enableLanguage(_ code: String) {
        guard isValidISO639Code(code) else { return }
        
        var languages = enabledLanguages
        if !languages.contains(code) {
            languages.append(code)
            enabledLanguages = languages
        }
    }
    
    func disableLanguage(_ code: String) {
        var languages = enabledLanguages
        
        // Ensure at least one language remains enabled
        if languages.count <= 1 {
            return
        }
        
        languages.removeAll { $0 == code }
        enabledLanguages = languages
    }
    
    func getAvailableLanguages() -> [Language] {
        return availableLanguages
    }
    
    // MARK: - Private Helpers
    
    private func isValidISO639Code(_ code: String) -> Bool {
        // ISO 639-1 codes are exactly 2 lowercase letters
        guard code.count == 2 else { return false }
        guard code.allSatisfy({ $0.isLetter && $0.isLowercase }) else { return false }
        
        // Check if it's in our available languages list
        return availableLanguages.contains { $0.code == code }
    }
}
