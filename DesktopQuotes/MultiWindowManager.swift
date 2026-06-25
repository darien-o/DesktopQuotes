//
//  MultiWindowManager.swift
//  DesktopQuotes
//
//  Multi-window manager for displaying different quotes on each screen and desktop
//

import SwiftUI
import AppKit

class MultiWindowManager: ObservableObject {
    private var windowControllers: [String: QuoteWindowController] = [:]
    private let quoteManager: QuoteManager
    private var screenChangeWorkItem: DispatchWorkItem?
    private var screenObserver: NSObjectProtocol?
    private var spaceObserver: NSObjectProtocol?
    private var previousScreenCount: Int = 0
    
    init(quoteManager: QuoteManager) {
        self.quoteManager = quoteManager
        
        // Delay setup to ensure app is fully initialized
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.setupWindows()
            self?.observeChanges()
        }
    }
    
    deinit {
        screenChangeWorkItem?.cancel()
        if let observer = screenObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = spaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        removeAllWindows()
    }
    
    // MARK: - Screen Identifier
    
    /// Create a stable identifier for a screen based on its display ID.
    /// This avoids relying on NSScreen object identity which changes across
    /// connect/disconnect cycles.
    private func screenIdentifier(for screen: NSScreen) -> String {
        let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
        return "display-\(displayID)"
    }
    
    // MARK: - Window Setup
    
    private func setupWindows() {
        let screens = NSScreen.screens
        previousScreenCount = screens.count
        
        NSLog("🖥️  Setting up windows for \(screens.count) screens")
        
        for (index, screen) in screens.enumerated() {
            let id = screenIdentifier(for: screen)
            NSLog("   Screen \(index): id=\(id), frame=\(screen.frame)")
            
            if windowControllers[id] == nil {
                let controller = QuoteWindowController(
                    screen: screen,
                    quoteManager: quoteManager,
                    windowIndex: index
                )
                windowControllers[id] = controller
                controller.showWindow()
            }
        }
        
        NSLog("✅ Active window controllers: \(windowControllers.count)")
    }
    
    // MARK: - Observers
    
    private func observeChanges() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            NSLog("📺 Screen configuration changed")
            self?.scheduleWindowUpdate()
        }
        
        spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshAllQuotes()
        }
    }
    
    // MARK: - Screen Change Handling
    
    private func scheduleWindowUpdate() {
        screenChangeWorkItem?.cancel()
        
        let currentScreenCount = NSScreen.screens.count
        
        // Use a longer delay when screens are added (connection is riskier
        // because WindowServer needs time to fully initialize the display).
        // Shorter delay for disconnections since those screens are just gone.
        let delay: TimeInterval = currentScreenCount > previousScreenCount ? 2.5 : 1.5
        
        let workItem = DispatchWorkItem { [weak self] in
            self?.handleScreenChange()
        }
        screenChangeWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }
    
    private func handleScreenChange() {
        let currentScreens = NSScreen.screens
        let currentIDs = Set(currentScreens.map { screenIdentifier(for: $0) })
        let existingIDs = Set(windowControllers.keys)
        
        // Remove windows for screens that no longer exist
        let removedIDs = existingIDs.subtracting(currentIDs)
        for id in removedIDs {
            NSLog("🗑️  Removing window for disconnected screen: \(id)")
            windowControllers[id]?.hideAndRelease()
            windowControllers.removeValue(forKey: id)
        }
        
        // Add windows for new screens
        let addedIDs = currentIDs.subtracting(existingIDs)
        for (index, screen) in currentScreens.enumerated() {
            let id = screenIdentifier(for: screen)
            if addedIDs.contains(id) {
                NSLog("➕ Adding window for new screen: \(id)")
                let controller = QuoteWindowController(
                    screen: screen,
                    quoteManager: quoteManager,
                    windowIndex: index
                )
                windowControllers[id] = controller
                controller.showWindow()
            }
        }
        
        previousScreenCount = currentScreens.count
        NSLog("✅ Screen change handled. Active windows: \(windowControllers.count)")
    }
    
    private func removeAllWindows() {
        for (_, controller) in windowControllers {
            controller.hideAndRelease()
        }
        windowControllers.removeAll()
    }
    
    func refreshAllQuotes() {
        windowControllers.values.forEach { $0.refreshQuote() }
    }
}

// MARK: - QuoteWindowController

/// Controls a single quote overlay window for one screen.
/// Uses NSPanel instead of NSWindow to avoid participation in the
/// window cycling and minimize AppKit's internal bookkeeping.
class QuoteWindowController {
    private var panel: NSPanel?
    private var hostingView: NSHostingView<RandomPositionQuoteView>?
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
        
        setupPanel(for: screen)
    }
    
    private func setupPanel(for screen: NSScreen) {
        let screenFrame = screen.frame
        
        // Use NSPanel — it's lighter weight than NSWindow and designed for
        // auxiliary/utility purposes. It won't become key window or participate
        // in the normal window lifecycle as aggressively.
        let panel = NSPanel(
            contentRect: screenFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true,
            screen: screen
        )
        
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        
        // Prevent the panel from being released when closed
        panel.isReleasedWhenClosed = false
        
        let quoteView = RandomPositionQuoteView(
            quote: currentQuote,
            screenFrame: screenFrame
        )
        
        let hosting = NSHostingView(rootView: quoteView)
        hosting.frame = CGRect(origin: .zero, size: screenFrame.size)
        hosting.autoresizingMask = [.width, .height]
        
        panel.contentView = hosting
        panel.setFrame(screenFrame, display: false)
        
        self.panel = panel
        self.hostingView = hosting
    }
    
    func showWindow() {
        guard let panel = panel else {
            NSLog("❌ Window \(windowIndex) is nil, cannot show")
            return
        }
        
        NSLog("🪟 Showing window \(windowIndex) - Quote: \(currentQuote.text.prefix(40))...")
        
        // orderBack places it behind all other windows (desktop level)
        panel.orderBack(nil)
    }
    
    /// Safely hide and release all resources.
    /// This method ensures the hosting view is detached cleanly.
    func hideAndRelease() {
        guard let panel = panel else { return }
        
        // 1. Order out (hide) the panel first
        panel.orderOut(nil)
        
        // 2. Detach the hosting view from the panel to break the SwiftUI
        //    rendering pipeline's connection to this window/screen.
        //    Setting contentView to a plain NSView avoids leaving SwiftUI
        //    objects in the autorelease pool tied to a dead screen context.
        hostingView = nil
        panel.contentView = NSView()
        
        // 3. Release our reference. The panel won't dealloc immediately
        //    because isReleasedWhenClosed = false and we ordered it out
        //    rather than closing it. This gives the autorelease pool time
        //    to drain without hitting freed memory.
        self.panel = nil
    }
    
    func refreshQuote() {
        guard let panel = panel else { return }
        guard let screen = panel.screen ?? NSScreen.screens.first else { return }
        
        let oldQuote = currentQuote
        for _ in 0..<10 {
            quoteManager.getRandomQuote()
            if quoteManager.currentQuote.id != oldQuote.id {
                currentQuote = quoteManager.currentQuote
                break
            }
        }
        
        let quoteView = RandomPositionQuoteView(
            quote: currentQuote,
            screenFrame: screen.frame
        )
        
        let hosting = NSHostingView(rootView: quoteView)
        hosting.frame = CGRect(origin: .zero, size: panel.frame.size)
        hosting.autoresizingMask = [.width, .height]
        
        // Replace old hosting view
        self.hostingView = hosting
        panel.contentView = hosting
    }
}

// MARK: - RandomPositionQuoteView

struct RandomPositionQuoteView: View {
    let quote: Quote
    let screenFrame: CGRect
    @State private var position: CGPoint
    
    init(quote: Quote, screenFrame: CGRect) {
        self.quote = quote
        self.screenFrame = screenFrame
        
        let margin: CGFloat = 100
        let maxWidth = max(screenFrame.width - margin * 2, margin)
        let maxHeight = max(screenFrame.height - margin * 2, margin)
        
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
