//
//  ContentView.swift
//  DesktopQuotes
//
//  Created by Darien Stiven Osorno Ramirez on 3/03/25.
//

import SwiftUI

struct QuoteView: View {
    @StateObject private var quoteManager = QuoteManager()
    @State private var opacity: Double = 0.7
    
    
    var body: some View {
        Text("\"\(quoteManager.currentQuote.text)\"\n\(quoteManager.currentQuote.author)")
            .font(.largeTitle)
            .foregroundColor(.white)
            .shadow(color: .black,radius: 2, x:1,y:1)
            .padding()
            .onAppear{
                NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil,queue: nil){
                    _ in quoteManager.getRandomQuote()
                }
            }

    }
}

