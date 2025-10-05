//
//  SignInView.swift
//  freya
//
//  Created by Prithvi B on 1/4/25.
//

import SwiftUI
import FirebaseAuth

struct SignInView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var successMessage = ""
    
    var isValidForm: Bool {
        !email.isEmpty && email.contains("@") && !password.isEmpty
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
                    Text("Welcome back")
                        .font(.custom("Garamond", size: 32))
                        .fontWeight(.black)
                        .foregroundColor(.black)
                    
                    Text("Sign in to continue your skincare journey")
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
                
                // Sign in button
                Button(action: signIn) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Log in")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                }
                .frame(width: UIScreen.main.bounds.width * 0.80)
                .padding(.vertical, 16)
                .background(isValidForm && !isLoading ? Color.black : Color.gray)
                .cornerRadius(30)
                .disabled(!isValidForm || isLoading)
                
                // Forgot password link
                NavigationLink(destination: ForgotPasswordView()) {
                    Text("Forgot password?")
                        .font(.body)
                        .foregroundColor(.black)
                        .underline()
                }
                .padding(.bottom, 40)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func signIn() {
        isLoading = true
        errorMessage = ""
        successMessage = ""
        
        Task {
            do {
                try await Auth.auth().signIn(withEmail: email, password: password)
                await MainActor.run {
                    successMessage = "Welcome back! Signing you in..."
                    isLoading = false
                }
                // Brief delay to show success message before auto-navigation
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            } catch {
                await MainActor.run {
                    isLoading = false
                    
                    // Handle specific Firebase errors with user-friendly messages
                    if let authError = error as NSError? {
                        switch authError.code {
                        case AuthErrorCode.wrongPassword.rawValue, AuthErrorCode.invalidCredential.rawValue:
                            errorMessage = "Invalid email or password. Please try again."
                        case AuthErrorCode.userNotFound.rawValue:
                            errorMessage = "No account found with this email. Try creating an account."
                        case AuthErrorCode.invalidEmail.rawValue:
                            errorMessage = "Please enter a valid email address."
                        case AuthErrorCode.tooManyRequests.rawValue:
                            errorMessage = "Too many failed attempts. Please try again later."
                        case AuthErrorCode.networkError.rawValue:
                            errorMessage = "Network error. Please check your connection and try again."
                        case AuthErrorCode.userDisabled.rawValue:
                            errorMessage = "This account has been disabled. Please contact support."
                        default:
                            errorMessage = "Unable to sign in. Please try again."
                        }
                    } else {
                        errorMessage = "Unable to sign in. Please try again."
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        SignInView()
    }
}
