//
//  QuoteManager.swift
//  DesktopQuotes
//
//  Created by Darien Stiven Osorno Ramirez on 3/03/25.
//

import Foundation

class QuoteManager: ObservableObject {
    @Published var currentQuote: Quote
    private var quotes: [Quote]
    private let repository: QuoteRepository
    private let scheduler: BackgroundUpdateScheduler
    private let logger = QuoteManagerLogger()
    
    // Exponential backoff configuration
    private var retryAttempts: Int = 0
    private let maxRetryAttempts: Int = 5
    private let baseRetryDelay: TimeInterval = 5.0 // 5 seconds
    
    // Fallback quote for when no quotes are available
    private let fallbackQuote = Quote(
        text: "Stay hungry, stay foolish.",
        author: "Steve Jobs"
    )
    
    init(repository: QuoteRepository, scheduler: BackgroundUpdateScheduler) {
        self.repository = repository
        self.scheduler = scheduler
        self.quotes = []
        self.currentQuote = fallbackQuote
        
        // Initialize quotes on app launch
        Task {
            await initializeQuotes()
        }
    }
    
    /// Convenience initializer for production use
    convenience init() {
        let store = JSONLocalQuoteStore()
        let remoteSync = URLSessionRemoteQuoteSync()
        let repository = LocalQuoteRepository(store: store, remoteSync: remoteSync)
        
        let scheduler = SystemBackgroundUpdateScheduler { [weak repository] in
            guard let repository = repository else { return }
            do {
                let result = try await repository.syncWithRemote()
                if result.success {
                    print("Background sync completed: \(result.newQuotesCount) new quotes")
                } else {
                    print("Background sync failed: \(result.error?.localizedDescription ?? "Unknown error")")
                }
            } catch {
                print("Background sync error: \(error.localizedDescription)")
            }
        }
        
        self.init(repository: repository, scheduler: scheduler)
    }
    
    func getRandomQuote() {
        guard !quotes.isEmpty else {
            logger.log("No quotes available, using fallback")
            currentQuote = fallbackQuote
            return
        }
        currentQuote = quotes.randomElement()!
    }
    
    // MARK: - Private Methods
    
    /// Initialize quotes on app launch
    private func initializeQuotes() async {
        logger.log("Initializing quotes on app launch")
        
        do {
            // Try to load quotes from local cache
            quotes = try await repository.loadQuotes()
            
            if quotes.isEmpty {
                logger.log("Local cache is empty, triggering initial sync")
                await performSyncWithRetry()
            } else {
                logger.log("Loaded \(quotes.count) quotes from local cache")
                // Update current quote with a random one from loaded quotes
                await MainActor.run {
                    getRandomQuote()
                }
            }
            
            // Schedule background updates (daily by default)
            scheduleBackgroundSync()
            
        } catch {
            logger.log("Failed to load quotes: \(error.localizedDescription)")
            // If loading fails, try to sync from remote
            await performSyncWithRetry()
        }
    }
    
    /// Schedule background sync updates
    private func scheduleBackgroundSync() {
        logger.log("Scheduling background sync updates")
        scheduler.scheduleUpdates(interval: .daily)
    }
    
    /// Perform sync with exponential backoff retry logic
    private func performSyncWithRetry() async {
        logger.log("🔄 Performing sync with retry (attempt \(retryAttempts + 1)/\(maxRetryAttempts))")
        print("🔄 [QuoteManager] Performing sync with retry (attempt \(retryAttempts + 1)/\(maxRetryAttempts))")
        
        do {
            let result = try await repository.syncWithRemote()
            
            if result.success {
                logger.log("✅ Sync successful: \(result.newQuotesCount) new quotes")
                print("✅ [QuoteManager] Sync successful: \(result.newQuotesCount) new quotes")
                
                // Reset retry attempts on success
                retryAttempts = 0
                
                // Reload quotes from repository
                quotes = try await repository.loadQuotes()
                
                // Update current quote
                await MainActor.run {
                    getRandomQuote()
                }
            } else {
                logger.log("❌ Sync failed: \(result.error?.localizedDescription ?? "Unknown error")")
                print("❌ [QuoteManager] Sync failed: \(result.error?.localizedDescription ?? "Unknown error")")
                await handleSyncFailure(error: result.error)
            }
            
        } catch {
            logger.log("❌ Sync error: \(error.localizedDescription)")
            print("❌ [QuoteManager] Sync error: \(error.localizedDescription)")
            await handleSyncFailure(error: error)
        }
    }
    
    /// Handle sync failure with exponential backoff
    private func handleSyncFailure(error: Error?) async {
        retryAttempts += 1
        
        guard retryAttempts < maxRetryAttempts else {
            logger.log("Max retry attempts reached, giving up")
            retryAttempts = 0
            
            // Use fallback quote if no quotes available
            if quotes.isEmpty {
                await MainActor.run {
                    currentQuote = fallbackQuote
                }
            }
            return
        }
        
        // Calculate exponential backoff delay: baseDelay * 2^(attempts-1)
        let delay = baseRetryDelay * pow(2.0, Double(retryAttempts - 1))
        logger.log("Scheduling retry in \(delay) seconds")
        
        // Wait for the backoff period
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        
        // Retry the sync
        await performSyncWithRetry()
    }
    
    /// Manually trigger a sync operation
    func manualSync() async {
        logger.log("📡 Manual sync triggered")
        print("📡 [QuoteManager] Manual sync triggered")
        retryAttempts = 0
        await performSyncWithRetry()
    }
}

/// Simple logger for QuoteManager operations
private struct QuoteManagerLogger {
    func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[\(timestamp)] QuoteManager: \(message)")
    }
}
