import SwiftUI
import os.log

@main
struct DesktopQuotesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var windowManager: MultiWindowManager?
    var quoteManager: QuoteManager?
    var statusItem: NSStatusItem?
    
    private let logger = Logger(subsystem: "com.desktopquotes.app", category: "AppDelegate")
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("🚀 App launched - initializing quote system")
        print("🚀 App launched - initializing quote system")
        
        // Create menu bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "quote.bubble", accessibilityDescription: "Desktop Quotes")
        }
        
        setupMenu()
        
        // Initialize quote manager
        quoteManager = QuoteManager()
        
        // Trigger immediate sync to fetch quotes
        Task {
            logger.info("📡 Triggering immediate sync...")
            print("📡 Triggering immediate sync...")
            await quoteManager?.manualSync()
            logger.info("✅ Initial sync completed")
            print("✅ Initial sync completed")
        }
        
        // Initialize window manager after a delay to allow quotes to load
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            if let quoteManager = self?.quoteManager {
                self?.logger.info("🪟 Creating window manager")
                print("🪟 Creating window manager")
                NSLog("🪟 Creating window manager")
                let screenCount = NSScreen.screens.count
                print("🖥️  NSScreen.screens.count = \(screenCount)")
                NSLog("🖥️  NSScreen.screens.count = \(screenCount)")
                self?.windowManager = MultiWindowManager(quoteManager: quoteManager)
            } else {
                let errorMsg = "❌ QuoteManager is nil, cannot create window manager"
                print(errorMsg)
                NSLog(errorMsg)
            }
        }
        
        logger.info("✅ Quote system initialized")
        print("✅ Quote system initialized")
    }
    
    private func setupMenu() {
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "Refresh Quotes", action: #selector(refreshQuotes), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: "Sync from API", action: #selector(syncQuotes), keyEquivalent: "s"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Show Quotes Folder", action: #selector(showQuotesFolder), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    @objc func refreshQuotes() {
        logger.info("🔄 Manual refresh triggered")
        print("🔄 Manual refresh triggered")
        windowManager?.refreshAllQuotes()
    }
    
    @objc func syncQuotes() {
        logger.info("📡 Manual sync triggered from menu")
        print("📡 Manual sync triggered from menu")
        Task {
            await quoteManager?.manualSync()
            logger.info("✅ Manual sync completed")
            print("✅ Manual sync completed")
        }
    }
    
    @objc func showQuotesFolder() {
        let fileManager = FileManager.default
        if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let quotesFolder = appSupport.appendingPathComponent("DesktopQuotes")
            NSWorkspace.shared.open(quotesFolder)
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
