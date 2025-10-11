//
//  OnboardingCoordinator.swift
//  freya
//
//  Created by Prithvi B on 1/4/25.
//

import SwiftUI
import FirebaseAuth
import Combine

class OnboardingCoordinator: ObservableObject {
    @Published var currentQuestion = 1
    @Published var onboardingData = OnboardingData()
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var deepScanSubmitted = false
    @Published var skinScoreResult: DeepScanResponse? = nil
    @Published var currentReportId: String? = nil
    
    let totalQuestions = 21
    
    func nextQuestion() {
        if currentQuestion == 16 && onboardingData.hasIngredientSensitivities == "No" {
            // Skip question 17 (ingredient details)
            currentQuestion = 18
        } else if currentQuestion < totalQuestions {
            currentQuestion += 1
        } else {
            // Finish onboarding
            saveOnboardingData()
        }
    }
    
    func previousQuestion() {
        if currentQuestion > 1 {
            currentQuestion -= 1
        }
    }
    
    // Submit DeepScan (non-blocking, fire-and-forget)
    func submitDeepScan() {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("DeepScan: User not authenticated")
            return
        }
        
        // Placeholder image URL (4 times)
        let placeholderURL = "https://plus.unsplash.com/premium_photo-1683140815244-7441fd002195?q=80&w=774&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D"
        let images = [placeholderURL, placeholderURL, placeholderURL, placeholderURL]
        
        Task {
            do {
                let response = try await ApiClient.shared.submitDeepScan(uid: uid, images: images, emphasis: "onboarding")
                print("DeepScan submitted successfully. ScoreId: \(response.scoreId)")
                DispatchQueue.main.async {
                    self.deepScanSubmitted = true
                    self.skinScoreResult = response
                }
            } catch {
                print("DeepScan submission failed (non-blocking): \(error.localizedDescription)")
                // Don't show error to user - this is fire-and-forget
            }
        }
    }
    
    private func saveOnboardingData() {
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "User not authenticated"
            return
        }
        
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                // 1. Save survey
                let surveyData = onboardingData.toDictionary()
                let response = try await ApiClient.shared.saveSurvey(uid: uid, surveyData: surveyData)
                print("Survey saved: \(response.message)")
                
                // 2. Wait for skin score, then show score summary (report generates in background)
                Task {
                    // Wait for skin score to be ready
                    let scoreReady = await self.waitForSkinScore()
                    
                    // Show score summary as soon as score is ready
                    DispatchQueue.main.async {
                        self.isLoading = false
                        
                        // Mark onboarding as complete
                        UserDefaults.standard.set(true, forKey: "onboardingCompleted_\(uid)")
                        
                        // Navigate to score summary screen
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let window = windowScene.windows.first {
                            window.rootViewController = UIHostingController(rootView: 
                                ScoreSummaryView(
                                    onContinue: {
                                        // Navigate to main app
                                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                           let window = windowScene.windows.first {
                                            window.rootViewController = UIHostingController(rootView: 
                                                NavigationView {
                                                    QuickStartView()
                                                }
                                                .environmentObject(UserSession())
                                            )
                                        }
                                    }
                                )
                                .environmentObject(self)
                            )
                        }
                        
                        // Still post notification for state consistency
                        NotificationCenter.default.post(name: .onboardingCompleted, object: nil)
                    }
                    
                    // Generate report in background (non-blocking)
                    if scoreReady {
                        do {
                            let reportResponse = try await ApiClient.shared.generateReport(uid: uid)
                            print("Report generated: \(reportResponse.reportId)")
                            DispatchQueue.main.async {
                                self.currentReportId = reportResponse.reportId
                            }
                        } catch {
                            print("Report generation failed: \(error.localizedDescription)")
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "Failed to save: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func waitForSkinScore() async -> Bool {
        for attempt in 1...5 {
            if skinScoreResult != nil {
                print("Skin score ready!")
                return true
            }
            if attempt < 5 {
                print("Waiting for skin score... attempt \(attempt)/5")
                try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
            }
        }
        print("Skin score not ready after max attempts")
        return false
    }
    
    func waitForReportReady() async -> Bool {
        for attempt in 1...5 {
            if currentReportId != nil {
                // Report ID exists, assume ready
                print("Report ready: \(currentReportId!)")
                return true
            }
            if attempt < 5 {
                print("Waiting for report... attempt \(attempt)/5")
                try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
            }
        }
        print("Report not ready after max attempts")
        return false
    }
}

extension Notification.Name {
    static let onboardingCompleted = Notification.Name("onboardingCompleted")
}

