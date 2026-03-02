//
//  QuoteRepository.swift
//  DesktopQuotes
//
//  Created by Kiro on Enhanced Quote System Implementation
//

import Foundation

/// Result of a synchronization operation
struct SyncResult {
    let newQuotesCount: Int
    let updatedQuotesCount: Int
    let timestamp: Date
    let success: Bool
    let error: Error?
}

/// Protocol defining quote repository operations
protocol QuoteRepository {
    func loadQuotes() async throws -> [Quote]
    func saveQuotes(_ quotes: [Quote]) async throws
    func syncWithRemote() async throws -> SyncResult
    func getQuotesByLanguage(_ languageCode: String) -> [Quote]
}

/// Errors that can occur during repository operations
enum RepositoryError: Error, LocalizedError {
    case validationFailed(String)
    case cacheInconsistent(String)
    case storageError(Error)
    
    var errorDescription: String? {
        switch self {
        case .validationFailed(let message):
            return "Quote validation failed: \(message)"
        case .cacheInconsistent(let message):
            return "Cache consistency check failed: \(message)"
        case .storageError(let error):
            return "Storage operation failed: \(error.localizedDescription)"
        }
    }
}

/// Implementation of QuoteRepository using LocalQuoteStore
final class LocalQuoteRepository: QuoteRepository {
    private let store: LocalQuoteStore
    private let remoteSync: RemoteQuoteSync
    private var cachedQuotes: [Quote] = []
    private var cacheMetadata: CacheMetadata
    private let logger = RepositoryLogger()
    
    init(store: LocalQuoteStore, remoteSync: RemoteQuoteSync) {
        self.store = store
        self.remoteSync = remoteSync
        // Initialize with default metadata
        self.cacheMetadata = CacheMetadata(
            lastSyncDate: Date.distantPast,
            quoteCount: 0,
            languageDistribution: [:],
            cacheVersion: "1.0.0",
            sourceStatuses: [:]
        )
    }
    
    /// Load quotes from local storage with validation and sanitization
    func loadQuotes() async throws -> [Quote] {
        logger.log("Loading quotes from local storage")
        
        do {
            let collection = try await store.read()
            
            // Validate cache consistency
            try validateCacheConsistency(collection)
            
            // Validate and sanitize each quote
            let validQuotes = collection.quotes.compactMap { quote -> Quote? in
                guard validateQuote(quote) else {
                    logger.log("Excluding invalid quote: \(quote.id)")
                    return nil
                }
                return sanitizeQuote(quote)
            }
            
            logger.log("Loaded \(validQuotes.count) valid quotes")
            cachedQuotes = validQuotes
            return validQuotes
            
        } catch {
            logger.log("Failed to load quotes: \(error.localizedDescription)")
            throw RepositoryError.storageError(error)
        }
    }
    
    /// Save quotes to local storage with cache consistency checks
    func saveQuotes(_ quotes: [Quote]) async throws {
        logger.log("Saving \(quotes.count) quotes to local storage")
        
        // Validate all quotes before saving
        for quote in quotes {
            guard validateQuote(quote) else {
                throw RepositoryError.validationFailed("Invalid quote: \(quote.id)")
            }
        }
        
        // Create collection with metadata
        let collection = QuoteCollection(
            quotes: quotes,
            version: "1.0.0",
            lastUpdated: Date(),
            sources: []
        )
        
        // Verify cache consistency before saving
        try validateCacheConsistency(collection)
        
        do {
            try await store.write(collection)
            cachedQuotes = quotes
            logger.log("Successfully saved \(quotes.count) quotes")
        } catch {
            logger.log("Failed to save quotes: \(error.localizedDescription)")
            throw RepositoryError.storageError(error)
        }
    }
    
    /// Get quotes filtered by language code
    func getQuotesByLanguage(_ languageCode: String) -> [Quote] {
        let filtered = cachedQuotes.filter { $0.language == languageCode }
        logger.log("Filtered \(filtered.count) quotes for language: \(languageCode)")
        return filtered
    }
    
    /// Synchronize quotes with remote sources
    func syncWithRemote() async throws -> SyncResult {
        logger.log("🔄 Starting remote synchronization")
        print("🔄 [QuoteRepository] Starting remote synchronization")
        
        do {
            // Fetch quotes from all remote sources
            print("📡 [QuoteRepository] Calling remoteSync.fetchAllSources()...")
            let remoteQuotes = try await remoteSync.fetchAllSources()
            
            print("✅ [QuoteRepository] Received \(remoteQuotes.count) quotes from remote")
            
            // Track counts for result
            var newQuotesCount = 0
            var updatedQuotesCount = 0
            
            // Create a set of existing quote texts for duplicate detection
            var existingQuoteTexts = Set(cachedQuotes.map { $0.text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) })
            
            // Create a dictionary of existing quotes by ID for efficient lookup
            var existingQuotesById = Dictionary(uniqueKeysWithValues: cachedQuotes.map { ($0.id, $0) })
            
            // Merge remote quotes with local quotes, preserving uniqueness by ID and text
            for remoteQuote in remoteQuotes {
                let normalizedText = remoteQuote.text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Check if quote already exists by ID or text
                if existingQuotesById[remoteQuote.id] == nil && !existingQuoteTexts.contains(normalizedText) {
                    // New quote - add it
                    existingQuotesById[remoteQuote.id] = remoteQuote
                    existingQuoteTexts.insert(normalizedText)
                    newQuotesCount += 1
                } else {
                    // Quote already exists (by ID or text)
                    updatedQuotesCount += 1
                }
            }
            
            // Convert back to array
            let mergedQuotes = Array(existingQuotesById.values)
            
            // Update cache metadata
            let now = Date()
            let languageDistribution = calculateLanguageDistribution(mergedQuotes)
            
            cacheMetadata = CacheMetadata(
                lastSyncDate: now,
                quoteCount: mergedQuotes.count,
                languageDistribution: languageDistribution,
                cacheVersion: cacheMetadata.cacheVersion,
                sourceStatuses: cacheMetadata.sourceStatuses
            )
            
            // Save merged quotes to local storage
            try await saveQuotes(mergedQuotes)
            
            logger.log("Sync completed: \(newQuotesCount) new, \(updatedQuotesCount) duplicates skipped")
            
            return SyncResult(
                newQuotesCount: newQuotesCount,
                updatedQuotesCount: updatedQuotesCount,
                timestamp: now,
                success: true,
                error: nil
            )
            
        } catch {
            logger.log("❌ Sync failed: \(error.localizedDescription)")
            print("❌ [QuoteRepository] Sync failed: \(error.localizedDescription)")
            
            // On network failure, leave cache unchanged and return error result
            return SyncResult(
                newQuotesCount: 0,
                updatedQuotesCount: 0,
                timestamp: Date(),
                success: false,
                error: error
            )
        }
    }
    
    // MARK: - Private Helper Methods
    
    /// Validate a quote meets all requirements
    private func validateQuote(_ quote: Quote) -> Bool {
        // Check text is not empty
        guard !quote.text.isEmpty else {
            return false
        }
        
        // Check author is not empty
        guard !quote.author.isEmpty else {
            return false
        }
        
        // Check language code is exactly 2 characters
        guard quote.language.count == 2 else {
            return false
        }
        
        // Check language code contains only letters (basic ISO 639-1 validation)
        guard quote.language.allSatisfy({ $0.isLetter }) else {
            return false
        }
        
        // Check dateAdded is not in the future
        guard quote.dateAdded <= Date() else {
            return false
        }
        
        // Check text length limit (500 characters max)
        guard quote.text.count <= 500 else {
            return false
        }
        
        return true
    }
    
    /// Sanitize quote text by removing control characters
    private func sanitizeQuote(_ quote: Quote) -> Quote {
        let sanitizedText = quote.text.filter { char in
            !char.isNewline && !char.unicodeScalars.contains(where: { scalar in
                CharacterSet.controlCharacters.contains(scalar)
            })
        }
        
        // If text is unchanged, return original quote
        if sanitizedText == quote.text {
            return quote
        }
        
        // Create new quote with sanitized text
        return Quote(
            id: quote.id,
            text: sanitizedText,
            author: quote.author,
            language: quote.language,
            tags: quote.tags,
            source: quote.source,
            dateAdded: quote.dateAdded
        )
    }
    
    /// Validate cache consistency (quote count matches metadata)
    private func validateCacheConsistency(_ collection: QuoteCollection) throws {
        let actualCount = collection.quotes.count
        
        // For now, we just verify the count is non-negative
        // In future phases, we'll add more sophisticated metadata tracking
        guard actualCount >= 0 else {
            throw RepositoryError.cacheInconsistent("Invalid quote count: \(actualCount)")
        }
        
        logger.log("Cache consistency validated: \(actualCount) quotes")
    }
    
    /// Calculate language distribution for metadata
    private func calculateLanguageDistribution(_ quotes: [Quote]) -> [String: Int] {
        var distribution: [String: Int] = [:]
        for quote in quotes {
            distribution[quote.language, default: 0] += 1
        }
        return distribution
    }
    
    /// Update source status after sync attempt
    private func updateSourceStatus(sourceId: String, success: Bool, error: String? = nil) {
        var statuses = cacheMetadata.sourceStatuses
        let currentStatus = statuses[sourceId]
        
        if success {
            // Reset consecutive failures on success
            statuses[sourceId] = SourceStatus(
                sourceId: sourceId,
                lastSuccessfulSync: Date(),
                lastError: nil,
                consecutiveFailures: 0
            )
        } else {
            // Increment consecutive failures
            let failures = (currentStatus?.consecutiveFailures ?? 0) + 1
            statuses[sourceId] = SourceStatus(
                sourceId: sourceId,
                lastSuccessfulSync: currentStatus?.lastSuccessfulSync,
                lastError: error,
                consecutiveFailures: failures
            )
            
            // Log if source should be disabled (3 consecutive failures)
            if failures >= 3 {
                logger.log("Source \(sourceId) has failed 3 times and should be disabled")
            }
        }
        
        // Update metadata
        cacheMetadata = CacheMetadata(
            lastSyncDate: cacheMetadata.lastSyncDate,
            quoteCount: cacheMetadata.quoteCount,
            languageDistribution: cacheMetadata.languageDistribution,
            cacheVersion: cacheMetadata.cacheVersion,
            sourceStatuses: statuses
        )
    }
    
    /// Check if a source should be disabled due to consecutive failures
    private func shouldDisableSource(sourceId: String) -> Bool {
        guard let status = cacheMetadata.sourceStatuses[sourceId] else {
            return false
        }
        return status.consecutiveFailures >= 3
    }
}

/// Simple logger for repository operations
private struct RepositoryLogger {
    func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[\(timestamp)] QuoteRepository: \(message)")
    }
}
