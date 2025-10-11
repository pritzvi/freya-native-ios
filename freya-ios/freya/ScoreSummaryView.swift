//
//  ScoreSummaryView.swift
//  freya
//
//  Score summary screen shown after survey completion
//

import SwiftUI

struct ScoreSummaryView: View {
    @EnvironmentObject var coordinator: OnboardingCoordinator
    @State private var isWaiting = false
    
    let onContinue: () -> Void
    
    private let placeholderImageURL = "https://plus.unsplash.com/premium_photo-1683140815244-7441fd002195?q=80&w=774&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D"
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Close button
                HStack {
                    Spacer()
                    Button(action: {
                        // Skip waiting and go directly
                        onContinue()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .padding()
                    }
                }
                
                Spacer()
                
                // Image
                AsyncImage(url: URL(string: placeholderImageURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 200, height: 200)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 2))
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 200, height: 200)
                }
                .padding(.bottom, 30)
                
                // Total score
                Text("YOUR SKIN SCORE: \(coordinator.skinScoreResult?.overall ?? 0)/100")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.bottom, 30)
                
                // Subscores
                VStack(spacing: 16) {
                    ScoreRow(icon: "💧", label: "Barrier and Hydration", score: coordinator.skinScoreResult?.subscores["barrier_hydration_0_100"] ?? 0)
                    ScoreRow(icon: "✨", label: "Complexion", score: coordinator.skinScoreResult?.subscores["complexion_pigment_0_100"] ?? 0)
                    ScoreRow(icon: "🎯", label: "Acne and Texture", score: coordinator.skinScoreResult?.subscores["acne_texture_0_100"] ?? 0)
                    ScoreRow(icon: "⏰", label: "Fine Lines and Wrinkles", score: coordinator.skinScoreResult?.subscores["fine_lines_wrinkles_0_100"] ?? 0)
                    ScoreRow(icon: "👁", label: "Eye Bags and Dark Circles", score: coordinator.skinScoreResult?.subscores["eyebags_dark_circles_0_100"] ?? 0)
                }
                .padding(.horizontal, 40)
                
                Spacer()
                
                // Continue button
                Button(action: {
                    Task {
                        isWaiting = true
                        let ready = await coordinator.waitForReportReady()
                        isWaiting = false
                        if ready {
                            print("Report is ready, proceeding...")
                        } else {
                            print("Report not ready, proceeding anyway...")
                        }
                        onContinue()
                    }
                }) {
                    HStack {
                        if isWaiting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                            Text("Generating your routine...")
                        } else {
                            Text("Continue")
                        }
                    }
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(30)
                }
                .disabled(isWaiting)
                .padding(.horizontal, 40)
                .padding(.bottom, 20)
                
                // Disclaimer
                Text("This does not diagnose or treat medical conditions. Our services are intended for cosmetic skincare support only.")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 30)
            }
        }
    }
}

struct ScoreRow: View {
    let icon: String
    let label: String
    let score: Int
    
    var body: some View {
        HStack {
            Text(icon)
                .font(.system(size: 20))
            
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
            
            Text("\(score)/100")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}

#Preview {
    ScoreSummaryView(onContinue: {})
        .environmentObject(OnboardingCoordinator())
}

