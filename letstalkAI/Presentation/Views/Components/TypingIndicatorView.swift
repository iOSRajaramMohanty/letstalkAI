//
//  TypingIndicatorView.swift
//  letstalkAI
//
//  Typing indicator with streaming text
//

import SwiftUI
import MarkdownUI

struct TypingIndicatorView: View {
    let currentText: String
    
    @State private var animationPhase = 0
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            aiAvatar
            
            VStack(alignment: .leading, spacing: 8) {
                if currentText.isEmpty {
                    dotsAnimation
                } else {
                    Markdown(currentText)
                        .markdownTheme(.basic)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemGray6))
            )
            
            Spacer(minLength: 60)
        }
    }
    
    private var aiAvatar: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 32, height: 32)
            .overlay {
                Image(systemName: "brain.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
            }
    }
    
    private var dotsAnimation: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.gray)
                    .frame(width: 8, height: 8)
                    .scaleEffect(animationPhase == index ? 1.2 : 1.0)
                    .animation(
                        .easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: animationPhase
                    )
            }
        }
        .onAppear {
            animationPhase = 1
        }
    }
}
