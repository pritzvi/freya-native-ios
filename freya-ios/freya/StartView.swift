//
//  StartView.swift
//  freya
//
//  Created by Prithvi B on 9/27/25.
//

import SwiftUI

struct StartView: View {
    @State private var navigateToNext = false
    @EnvironmentObject var userSession: UserSession
    
    var body: some View {
        ZStack {
            // Base background
            Color(.systemBackground)
            
            // Gradient overlay
            RadialGradient(
                colors: [
                    Color(red: 0.435, green: 0.835, blue: 0.788).opacity(0.5), // #6FD5C9 with 50% opacity
                    Color(red: 0.435, green: 0.835, blue: 0.788).opacity(0.3), // #6FD5C9 with 30% opacity
                    Color.clear
                ],
                center: UnitPoint(x: 0.7, y: 0.5),
                startRadius: 70,
                endRadius: 350
            )
            
            // Main content
            VStack {
                Spacer()
                
                Text("freya")
                    .font(.custom("Satoshi-ExtraBold", size: 120))
                    .fontWeight(.black)
                    .foregroundColor(.black)
                
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                navigateToNext = true
            }
        }
        .background(
            Group {
                // Navigate based on auth state
                if !userSession.isAuthenticated {
                    NavigationLink(isActive: $navigateToNext, destination: {
                        AuthOptionsView()
                    }) {
                        EmptyView()
                    }
                } else if !userSession.hasCompletedOnboarding {
                    NavigationLink(isActive: $navigateToNext, destination: {
                        OnboardingView()
                    }) {
                        EmptyView()
                    }
                } else {
                    NavigationLink(isActive: $navigateToNext, destination: {
                        QuickStartView()
                    }) {
                        EmptyView()
                    }
                }
            }
        )
    }
}

#Preview {
    NavigationView {
        StartView()
    }
}
