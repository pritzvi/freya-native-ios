//
//  OnboardingCoordinator.swift
//  freya
//
//  Created by Prithvi B on 1/4/25.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Combine

class OnboardingCoordinator: ObservableObject {
    @Published var currentQuestion = 1
    @Published var onboardingData = OnboardingData()
    @Published var isLoading = false
    @Published var errorMessage = ""
    
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
    
    private func saveOnboardingData() {
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "User not authenticated"
            return
        }
        
        isLoading = true
        errorMessage = ""
        
        let db = Firestore.firestore()
        
        db.collection("skinProfiles").document(uid).setData(onboardingData.toDictionary()) { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Failed to save data: \(error.localizedDescription)"
                } else {
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
            }
        }
    }
}

extension Notification.Name {
    static let onboardingCompleted = Notification.Name("onboardingCompleted")
}
