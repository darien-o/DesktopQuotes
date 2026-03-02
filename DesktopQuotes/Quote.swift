//
//  Quote.swift
//  DesktopQuotes
//
//  Created by Darien Stiven Osorno Ramirez on 3/03/25.
//
import Foundation

struct Quote: Identifiable, Codable, Equatable {
    let id: UUID
    let text: String
    let author: String
    let language: String
    let tags: [String]
    let source: String
    let dateAdded: Date
    
    var isValid: Bool {
        !text.isEmpty && !author.isEmpty && language.count == 2 && language.allSatisfy { $0.isLetter }
    }
    
    init(id: UUID = UUID(), text: String, author: String, language: String = "en", tags: [String] = [], source: String = "", dateAdded: Date = Date()) {
        self.id = id
        self.text = text
        self.author = author
        self.language = language
        self.tags = tags
        self.source = source
        self.dateAdded = dateAdded
    }
}

struct QuoteCollection: Codable {
    let quotes: [Quote]
    let version: String
    let lastUpdated: Date
    let sources: [QuoteSource]
}

struct QuoteSource: Codable, Identifiable, Equatable {
    let id: String
    let url: String
    let name: String
    let enabled: Bool
}

struct CacheMetadata: Codable {
    let lastSyncDate: Date
    let quoteCount: Int
    let languageDistribution: [String: Int]
    let cacheVersion: String
    let sourceStatuses: [String: SourceStatus]
}

struct SourceStatus: Codable {
    let sourceId: String
    let lastSuccessfulSync: Date?
    let lastError: String?
    let consecutiveFailures: Int
}
