//
//  UserSession.swift
//  freya
//
//  Created by Prithvi B on 1/4/25.
//

import SwiftUI
import FirebaseAuth
import Combine

class UserSession: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var currentUID: String?
    @Published var hasCompletedOnboarding = false
    
    private var authStateListener: AuthStateDidChangeListenerHandle?
    
    init() {
        // Listen for auth state changes and store the handle
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.currentUser = user
                self?.currentUID = user?.uid
                self?.isAuthenticated = user != nil
                
                // Check onboarding status when user changes
                if let uid = user?.uid {
                    self?.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "onboardingCompleted_\(uid)")
                } else {
                    self?.hasCompletedOnboarding = false
                }
            }
        }
        
        // Listen for onboarding completion
        NotificationCenter.default.addObserver(
            forName: .onboardingCompleted,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.hasCompletedOnboarding = true
        }
    }
    
    deinit {
        // Clean up the listener to prevent memory leaks
        if let authStateListener = authStateListener {
            Auth.auth().removeStateDidChangeListener(authStateListener)
        }
    }
    
    func signOut() throws {
        try Auth.auth().signOut()
    }
}
