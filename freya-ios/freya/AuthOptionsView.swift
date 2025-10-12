//
//  AuthOptionsView.swift
//  freya
//
//  Created by Prithvi B on 1/4/25.
//

import SwiftUI

struct AuthOptionsView: View {
    @State private var isSkipActive = false
    
    var body: some View {
        ZStack {
            // Background Image (full screen)
            Image("freyascreen1girl")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
            
            // Dark overlay for text readability
            Color.black.opacity(0.2)
                .ignoresSafeArea()
            
            // freya logo - top center
            VStack {
                Text("freya")
                    .font(.custom("Garamond", size: 24))
                    .fontWeight(.black)
                    .foregroundColor(.white)
                    .padding(.top, 50)
                Spacer()
            }
            
            // Top-left text
            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: -5) {
                        Text("I FEEL &")
                        Text("LOOK LIKE")
                    }
                    .font(.system(size: 48, weight: .semibold, design: .default))
                    .tracking(-1.0)
                    .foregroundColor(.white)
                    .padding(.leading, 100)
                    .padding(.top, 120)
                    
                    Spacer()
                }
                Spacer()
            }
            
            // Bottom-right text
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: -5) {
                        Text("MY")
                        Text("ABSOLUTE")
                        Text("BEST")
                    }
                    .font(.system(size: 48, weight: .semibold, design: .default))
                    .tracking(-1.0)
                    .foregroundColor(.white)
                    .padding(.trailing, 100)
                    .padding(.bottom, 230)
                }
            }
            
            // Buttons and terms - bottom
            VStack {
                Spacer()
                
                VStack(spacing: 16) {
                    // Get started button
                    NavigationLink(destination: CreateAccountView()) {
                        Text("Get started")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(width: UIScreen.main.bounds.width * 0.80)
                            .padding(.vertical, 16)
                            .background(Color.black)
                            .cornerRadius(30)
                    }
                    
                    // Log in button  
                    NavigationLink(destination: SignInView()) {
                        Text("Log in")
                            .font(.headline)
                            .foregroundColor(.black)
                            .frame(width: UIScreen.main.bounds.width * 0.80)
                            .padding(.vertical, 16)
                            .background(Color.white.opacity(0.7))
                            .cornerRadius(30)
                    }
                    
#if DEBUG
                    Button(action: { isSkipActive = true }) {
                        Text("Skip (test)")
                            .font(.footnote)
                            .foregroundColor(.black)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.7))
                            .cornerRadius(20)
                    }
#endif
                }
                
                // Terms text
                Text("By continuing, you agree to our Terms of Use and Privacy Policy")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
            }
        }
        .navigationBarHidden(true)
        .background(
            Group {
#if DEBUG
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
        AuthOptionsView()
    }
}
