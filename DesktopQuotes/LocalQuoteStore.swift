//
//  LocalQuoteStore.swift
//  DesktopQuotes
//
//  Created by Kiro on Enhanced Quote System Implementation
//

import Foundation

/// Protocol defining local quote storage operations
protocol LocalQuoteStore {
    func read() async throws -> QuoteCollection
    func write(_ collection: QuoteCollection) async throws
    func exists() -> Bool
    func getLastModified() -> Date?
}

/// Errors that can occur during local storage operations
enum LocalStoreError: Error, LocalizedError {
    case fileNotFound
    case readFailed(Error)
    case writeFailed(Error)
    case encodingFailed(Error)
    case decodingFailed(Error)
    case permissionDenied
    case invalidPath
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Quote cache file not found"
        case .readFailed(let error):
            return "Failed to read quote cache: \(error.localizedDescription)"
        case .writeFailed(let error):
            return "Failed to write quote cache: \(error.localizedDescription)"
        case .encodingFailed(let error):
            return "Failed to encode quotes: \(error.localizedDescription)"
        case .decodingFailed(let error):
            return "Failed to decode quotes: \(error.localizedDescription)"
        case .permissionDenied:
            return "Permission denied accessing quote cache"
        case .invalidPath:
            return "Invalid file path for quote cache"
        }
    }
}

/// Implementation of LocalQuoteStore using JSON file persistence
final class JSONLocalQuoteStore: LocalQuoteStore {
    private let fileManager = FileManager.default
    private let fileName = "quotes.json"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    /// The file URL for the quote cache in Application Support directory
    private var fileURL: URL? {
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let appDirectory = appSupport.appendingPathComponent("DesktopQuotes", isDirectory: true)
        
        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: appDirectory.path) {
            try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
        }
        
        return appDirectory.appendingPathComponent(fileName)
    }
    
    init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }
    
    /// Read quote collection from JSON file
    func read() async throws -> QuoteCollection {
        guard let url = fileURL else {
            throw LocalStoreError.invalidPath
        }
        
        guard fileManager.fileExists(atPath: url.path) else {
            throw LocalStoreError.fileNotFound
        }
        
        do {
            let data = try Data(contentsOf: url)
            let collection = try decoder.decode(QuoteCollection.self, from: data)
            return collection
        } catch let error as DecodingError {
            throw LocalStoreError.decodingFailed(error)
        } catch {
            throw LocalStoreError.readFailed(error)
        }
    }
    
    /// Write quote collection to JSON file with atomic operations
    func write(_ collection: QuoteCollection) async throws {
        guard let url = fileURL else {
            throw LocalStoreError.invalidPath
        }
        
        do {
            let data = try encoder.encode(collection)
            
            // Use atomic write to prevent corruption
            try data.write(to: url, options: .atomic)
            
            // Set restrictive file permissions (user read/write only)
            try setRestrictivePermissions(for: url)
        } catch let error as EncodingError {
            throw LocalStoreError.encodingFailed(error)
        } catch {
            throw LocalStoreError.writeFailed(error)
        }
    }
    
    /// Check if the quote cache file exists
    func exists() -> Bool {
        guard let url = fileURL else {
            return false
        }
        return fileManager.fileExists(atPath: url.path)
    }
    
    /// Get the last modification date of the quote cache file
    func getLastModified() -> Date? {
        guard let url = fileURL else {
            return nil
        }
        
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }
        
        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            return attributes[.modificationDate] as? Date
        } catch {
            return nil
        }
    }
    
    /// Set restrictive file permissions (user read/write only)
    private func setRestrictivePermissions(for url: URL) throws {
        let attributes: [FileAttributeKey: Any] = [
            .posixPermissions: 0o600  // User read/write only (rw-------)
        ]
        
        do {
            try fileManager.setAttributes(attributes, ofItemAtPath: url.path)
        } catch {
            // Log but don't fail the write operation if permission setting fails
            print("Warning: Failed to set restrictive permissions: \(error.localizedDescription)")
        }
    }
}
