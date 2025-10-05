//
//  CreateAccountView.swift
//  freya
//
//  Created by Prithvi B on 1/4/25.
//

import SwiftUI
import FirebaseAuth

struct CreateAccountView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var successMessage = ""
    
    var isValidForm: Bool {
        !email.isEmpty && email.contains("@") && password.count >= 6
    }
    
    var body: some View {
        ZStack {
            // Same gradient background as onboarding
            Color(.systemBackground)
            
            RadialGradient(
                colors: [
                    Color(red: 0.435, green: 0.835, blue: 0.788).opacity(0.3),
                    Color(red: 0.435, green: 0.835, blue: 0.788).opacity(0.1),
                    Color.clear
                ],
                center: UnitPoint(x: 0.7, y: 0.3),
                startRadius: 50,
                endRadius: 300
            )
            
            VStack(spacing: 30) {
                Spacer()
                
                // Title and subtitle
                VStack(spacing: 16) {
                    Text("Create an account")
                        .font(.custom("Garamond", size: 32))
                        .fontWeight(.black)
                        .foregroundColor(.black)
                    
                    Text("This will allow us to save your analysis and track your progress.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                }
                
                // Form fields
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(.headline)
                            .foregroundColor(.black)
                        
                        TextField("Enter your email", text: $email)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.headline)
                            .foregroundColor(.black)
                        
                        SecureField("Enter password", text: $password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Text("Minimum of 6 characters")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 30)
                
                // Success message
                if !successMessage.isEmpty {
                    Text(successMessage)
                        .foregroundColor(.green)
                        .font(.body)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }
                
                // Error message
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }
                
                Spacer()
                
                // Sign up button
                Button(action: signUp) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Sign up")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                }
                .frame(width: UIScreen.main.bounds.width * 0.80)
                .padding(.vertical, 16)
                .background(isValidForm && !isLoading ? Color.black : Color.gray)
                .cornerRadius(30)
                .disabled(!isValidForm || isLoading)
                .padding(.bottom, 40)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func signUp() {
        isLoading = true
        errorMessage = ""
        successMessage = ""
        
        Task {
            do {
                try await Auth.auth().createUser(withEmail: email, password: password)
                await MainActor.run {
                    isLoading = false
                    successMessage = "Welcome to Freya! Setting up your account..."
                }
                
                // Brief delay to show success message, then navigate to onboarding
                try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
                
                await MainActor.run {
                    // Navigate to onboarding
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first {
                        window.rootViewController = UIHostingController(rootView: 
                            NavigationView {
                                OnboardingView()
                            }
                            .environmentObject(UserSession())
                        )
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    
                    // Handle specific Firebase errors with user-friendly messages
                    if let authError = error as NSError? {
                        switch authError.code {
                        case AuthErrorCode.emailAlreadyInUse.rawValue:
                            errorMessage = "This email is already registered. Try signing in instead."
                        case AuthErrorCode.weakPassword.rawValue:
                            errorMessage = "Please choose a stronger password with at least 6 characters."
                        case AuthErrorCode.invalidEmail.rawValue:
                            errorMessage = "Please enter a valid email address."
                        case AuthErrorCode.networkError.rawValue:
                            errorMessage = "Network error. Please check your connection and try again."
                        default:
                            errorMessage = "Unable to create account. Please try again."
                        }
                    } else {
                        errorMessage = "Unable to create account. Please try again."
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        CreateAccountView()
    }
}
