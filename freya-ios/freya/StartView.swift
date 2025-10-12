//
//  StartView.swift
//  freya
//
//  Created by Prithvi B on 9/27/25.
//

import SwiftUI

struct StartView: View {
    @State private var navigateToNext = false
    @State private var isSkipActive = false
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

#if DEBUG
            // Debug-only quick skip to Home for testing
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: { isSkipActive = true }) {
                        Text("Skip (test)")
                            .font(.footnote)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color(.secondarySystemBackground)))
                    }
                    .padding(16)
                }
            }
#endif
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

#if DEBUG
                // Direct link to Home for testing
                NavigationLink(isActive: $isSkipActive, destination: {
                    MainTabView(
                        uid: "KUUE1r0AdDSehwbOLSM9E3Mhfeg2",
                        reportId: "mgmf0xwqm7nan6atvw",
                        scoreId: "mgmf00j3d0wbpaor0s7"
                    )
                }) {
                    EmptyView()
                }
#endif
            }
        )
    }
}

#Preview {
    NavigationView {
        StartView()
    }
}
