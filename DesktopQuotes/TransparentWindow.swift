//
//  TransparentWindow.swift
//  DesktopQuotes
//
//  Created by Darien Stiven Osorno Ramirez on 3/03/25.
//

import SwiftUI

struct TransparentWindow: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.backgroundColor = .clear
                window.isOpaque = false
                window.level = .floating
                window.styleMask.remove(.titled)
                window.styleMask.insert(.fullSizeContentView)
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}
