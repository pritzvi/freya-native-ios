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
                let surveyData = onboardingData.toDictionary()
                let response = try await ApiClient.shared.saveSurvey(uid: uid, surveyData: surveyData)
                
                DispatchQueue.main.async {
                    self.isLoading = false
                    print("Survey saved: \(response.message)")
                    
                    // Mark onboarding as complete
                    UserDefaults.standard.set(true, forKey: "onboardingCompleted_\(uid)")
                    
                    // Direct navigation to welcome screen
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first {
                        window.rootViewController = UIHostingController(rootView: 
                            NavigationView {
                                QuickStartView()
                            }
                            .environmentObject(UserSession())
                        )
                    }
                    
                    // Still post notification for state consistency
                    NotificationCenter.default.post(name: .onboardingCompleted, object: nil)
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "Failed to save survey: \(error.localizedDescription)"
                }
            }
        }
    }
}

extension Notification.Name {
    static let onboardingCompleted = Notification.Name("onboardingCompleted")
}
