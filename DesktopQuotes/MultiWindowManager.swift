//
//  MultiWindowManager.swift
//  DesktopQuotes
//
//  Multi-window manager for displaying different quotes on each screen and desktop
//

import SwiftUI
import AppKit

class MultiWindowManager: ObservableObject {
    private var windowControllers: [QuoteWindowController] = []
    private let quoteManager: QuoteManager
    private var isUpdating = false
    private var pendingUpdate = false
    private var screenChangeWorkItem: DispatchWorkItem?
    
    init(quoteManager: QuoteManager) {
        self.quoteManager = quoteManager
        
        // Delay setup to ensure app is fully initialized
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.setupWindows()
            self?.observeChanges()
        }
    }
    
    private func setupWindows() {
        let screens = NSScreen.screens
        let screenCount = screens.count
        NSLog("🖥️  Setting up windows for \(screenCount) screens")
        print("🖥️  Setting up windows for \(screenCount) screens")
        NSLog("🖥️  Available screens:")
        print("🖥️  Available screens:")
        
        // Log all screen details
        for (index, screen) in screens.enumerated() {
            let logMsg = "   Screen \(index): frame=\(screen.frame), visibleFrame=\(screen.visibleFrame)"
            NSLog(logMsg)
            print(logMsg)
        }
        
        // Create a window for each screen
        for (index, screen) in screens.enumerated() {
            let logMsg = "🪟 Creating window \(index) for screen at \(screen.frame)"
            NSLog(logMsg)
            print(logMsg)
            createWindow(for: screen, index: index)
        }
        
        let finalMsg = "✅ Created \(windowControllers.count) window controllers"
        NSLog(finalMsg)
        print(finalMsg)
    }
    
    private func createWindow(for screen: NSScreen, index: Int) {
        let controller = QuoteWindowController(
            screen: screen,
            quoteManager: quoteManager,
            windowIndex: index
        )
        windowControllers.append(controller)
        controller.showWindow()
    }
    
    private func observeChanges() {
        // Observe screen configuration changes
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("Screen configuration changed")
            self?.scheduleWindowUpdate()
        }
        
        // Observe desktop space changes
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("Desktop space changed - refreshing quotes")
            self?.refreshAllQuotes()
        }
    }
    
    /// Debounce screen change notifications to avoid rapid tear-down/setup cycles.
    /// macOS can fire multiple notifications in quick succession when displays
    /// connect or disconnect.
    private func scheduleWindowUpdate() {
        // Cancel any previously scheduled update
        screenChangeWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            self?.updateWindows()
        }
        screenChangeWorkItem = workItem
        
        // Wait 1 second for screen configuration to stabilize
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
    }
    
    private func updateWindows() {
        guard !isUpdating else {
            // If we're already updating, mark that another update is needed
            pendingUpdate = true
            return
        }
        
        isUpdating = true
        
        // Close all existing windows safely
        let controllers = windowControllers
        windowControllers.removeAll()
        controllers.forEach { $0.closeWindow() }
        
        // Recreate windows for current screens
        setupWindows()
        
        isUpdating = false
        
        // If another screen change happened while we were updating, process it
        if pendingUpdate {
            pendingUpdate = false
            scheduleWindowUpdate()
        }
    }
    
    func refreshAllQuotes() {
        // Refresh each window with a new quote
        windowControllers.forEach { $0.refreshQuote() }
    }
}

// Window controller for each quote window
class QuoteWindowController {
    private var window: NSWindow?
    private let quoteManager: QuoteManager
    private let windowIndex: Int
    private var currentQuote: Quote
    
    init(screen: NSScreen, quoteManager: QuoteManager, windowIndex: Int) {
        self.quoteManager = quoteManager
        self.windowIndex = windowIndex
        self.currentQuote = quoteManager.currentQuote
        
        // Get a unique quote for this window
        for _ in 0..<10 {
            quoteManager.getRandomQuote()
            if quoteManager.currentQuote.id != currentQuote.id {
                currentQuote = quoteManager.currentQuote
                break
            }
        }
        
        setupWindow(for: screen)
    }
    
    private func setupWindow(for screen: NSScreen) {
        // Use screen's frame directly for window positioning
        let screenFrame = screen.frame
        
        let window = NSWindow(
            contentRect: screenFrame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        // CRITICAL: Set the screen BEFORE configuring the window
        window.setFrameOrigin(screenFrame.origin)
        
        // Configure window to be behind all apps (desktop level)
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
        window.backgroundColor = .clear
        window.isOpaque = false
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.hasShadow = false
        
        // Create quote view with random position
        let quoteView = RandomPositionQuoteView(
            quote: currentQuote,
            screenFrame: screenFrame
        )
        
        let hostingView = NSHostingView(rootView: quoteView)
        hostingView.frame = CGRect(origin: .zero, size: screenFrame.size)
        hostingView.autoresizingMask = [.width, .height]
        
        window.contentView?.addSubview(hostingView)
        
        // Force the window to the correct screen
        window.setFrame(screenFrame, display: true)
        if let targetScreen = NSScreen.screens.first(where: { $0.frame == screenFrame }) {
            NSLog("   - Positioned window on screen: \(targetScreen.localizedName)")
            print("   - Positioned window on screen: \(targetScreen.localizedName)")
        }
        
        self.window = window
    }
    
    func showWindow() {
        guard let window = window else {
            let errorMsg = "❌ Window \(windowIndex) is nil, cannot show"
            NSLog(errorMsg)
            print(errorMsg)
            return
        }
        
        NSLog("🪟 Showing window \(windowIndex):")
        print("🪟 Showing window \(windowIndex):")
        NSLog("   - Frame: \(window.frame)")
        print("   - Frame: \(window.frame)")
        NSLog("   - Screen: \(window.screen?.localizedName ?? "unknown")")
        print("   - Screen: \(window.screen?.localizedName ?? "unknown")")
        NSLog("   - Level: \(window.level.rawValue)")
        print("   - Level: \(window.level.rawValue)")
        NSLog("   - Quote: \(currentQuote.text.prefix(50))...")
        print("   - Quote: \(currentQuote.text.prefix(50))...")
        
        // Make sure window is visible
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
        
        // Force window to back after making it visible
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self, weak window] in
            guard let window = window else { return }
            window.orderBack(nil)
            if let index = self?.windowIndex {
                let successMsg = "✅ Window \(index) ordered to back"
                NSLog(successMsg)
                print(successMsg)
            }
        }
    }
    
    func closeWindow() {
        window?.orderOut(nil)
        window?.close()
        window = nil
    }
    
    func refreshQuote() {
        guard let window = window else { return }
        
        // Get a new quote
        let oldQuote = currentQuote
        for _ in 0..<10 {
            quoteManager.getRandomQuote()
            if quoteManager.currentQuote.id != oldQuote.id {
                currentQuote = quoteManager.currentQuote
                break
            }
        }
        
        print("Window \(windowIndex) refreshed with new quote: \(currentQuote.text.prefix(30))...")
        
        // Update the view safely
        guard let contentView = window.contentView else { return }
        guard let screen = window.screen else { return }
        
        let quoteView = RandomPositionQuoteView(
            quote: currentQuote,
            screenFrame: screen.frame
        )
        
        let hostingView = NSHostingView(rootView: quoteView)
        hostingView.frame = contentView.bounds
        hostingView.autoresizingMask = [.width, .height]
        
        contentView.subviews.forEach { $0.removeFromSuperview() }
        contentView.addSubview(hostingView)
    }
}

// Quote view with random positioning
struct RandomPositionQuoteView: View {
    let quote: Quote
    let screenFrame: CGRect
    @State private var position: CGPoint
    
    init(quote: Quote, screenFrame: CGRect) {
        self.quote = quote
        self.screenFrame = screenFrame
        
        // Generate random position
        // Avoid edges (100px margin)
        let margin: CGFloat = 100
        let maxWidth = screenFrame.width - margin * 2
        let maxHeight = screenFrame.height - margin * 2
        
        let randomX = CGFloat.random(in: margin...(margin + maxWidth))
        let randomY = CGFloat.random(in: margin...(margin + maxHeight))
        
        _position = State(initialValue: CGPoint(x: randomX, y: randomY))
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 8) {
                Text("\"\(quote.text)\"")
                    .font(.system(size: 28, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.8), radius: 3, x: 1, y: 1)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text("— \(quote.author)")
                    .font(.system(size: 22, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.8), radius: 3, x: 1, y: 1)
            }
            .padding(30)
            .frame(maxWidth: 600)
            .position(
                x: min(position.x, geometry.size.width - 300),
                y: min(position.y, geometry.size.height - 100)
            )
        }
    }
}
