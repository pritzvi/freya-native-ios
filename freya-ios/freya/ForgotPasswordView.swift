//
//  ForgotPasswordView.swift
//  freya
//
//  Created by Prithvi B on 1/4/25.
//

import SwiftUI
import FirebaseAuth

struct ForgotPasswordView: View {
    @State private var email = ""
    @State private var isLoading = false
    @State private var message = ""
    @State private var errorMessage = ""
    @State private var attemptCount = 0
    @State private var cooldownSeconds = 0
    @State private var timer: Timer?
    
    var isValidEmail: Bool {
        !email.isEmpty && email.contains("@")
    }
    
    var canSendEmail: Bool {
        isValidEmail && !isLoading && cooldownSeconds == 0 && attemptCount < 3
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
                    Text("Reset your password")
                        .font(.custom("Garamond", size: 32))
                        .fontWeight(.black)
                        .foregroundColor(.black)
                    
                    Text("Enter your email address and we'll send you a link to reset your password.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                }
                
                // Email field
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
                .padding(.horizontal, 30)
                
                // Success message
                if !message.isEmpty {
                    Text(message)
                        .foregroundColor(.green)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }
                
                // Error message
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }
                
                Spacer()
                
                // Send/Resend button
                Button(action: resetPassword) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else if attemptCount == 0 {
                        Text("Send reset link")
                            .font(.headline)
                            .foregroundColor(.white)
                    } else if cooldownSeconds > 0 {
                        Text("Resend in \(cooldownSeconds)s")
                            .font(.headline)
                            .foregroundColor(.white)
                    } else if attemptCount < 3 {
                        Text("Resend")
                            .font(.headline)
                            .foregroundColor(.white)
                    } else {
                        Text("Maximum attempts reached")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                }
                .frame(width: UIScreen.main.bounds.width * 0.80)
                .padding(.vertical, 16)
                .background(canSendEmail ? Color.black : Color.gray)
                .cornerRadius(30)
                .disabled(!canSendEmail)
                .padding(.bottom, 40)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func resetPassword() {
        isLoading = true
        errorMessage = ""
        message = ""
        
        Task {
            do {
                try await Auth.auth().sendPasswordReset(withEmail: email)
                await MainActor.run {
                    isLoading = false
                    attemptCount += 1
                    message = "If this email is registered, you'll receive a reset link. Check your email and spam folder."
                    
                    if attemptCount < 3 {
                        startCooldown()
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    
                    if let authError = error as NSError? {
                        switch authError.code {
                        case AuthErrorCode.invalidEmail.rawValue:
                            errorMessage = "Please enter a valid email address."
                        case AuthErrorCode.tooManyRequests.rawValue:
                            errorMessage = "Too many requests. Please try again later."
                        case AuthErrorCode.networkError.rawValue:
                            errorMessage = "Network error. Please check your connection and try again."
                        default:
                            errorMessage = "Unable to send reset email. Please try again."
                        }
                    } else {
                        errorMessage = "Unable to send reset email. Please try again."
                    }
                }
            }
        }
    }
    
    private func startCooldown() {
        cooldownSeconds = 60
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if cooldownSeconds > 0 {
                cooldownSeconds -= 1
            } else {
                timer?.invalidate()
                timer = nil
            }
        }
    }
}

#Preview {
    NavigationView {
        ForgotPasswordView()
    }
}
