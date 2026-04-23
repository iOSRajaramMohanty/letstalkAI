//
//  DynamicLogoView.swift
//  letstalkAI
//
//  Dynamic logo that adapts to color scheme
//

import SwiftUI

struct DynamicLogoView: View {
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Image(systemName: "brain.fill")
                .font(.system(size: 36))
                .foregroundStyle(.white)
        }
    }
    
    private var gradientColors: [Color] {
        if colorScheme == .dark {
            return [.purple, .blue]
        } else {
            return [.blue, .cyan]
        }
    }
}
