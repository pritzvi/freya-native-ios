//
//  QuickStartView.swift
//  freya
//
//  Created by Prithvi B on 1/4/25.
//

import SwiftUI
import FirebaseAuth

struct QuickStartView: View {
    @EnvironmentObject var userSession: UserSession
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Text("Welcome to Freya!")
                .font(.custom("Garamond", size: 32))
                .fontWeight(.black)
                .foregroundColor(.black)
            
            Text("You're successfully signed in")
                .font(.body)
                .foregroundColor(.secondary)
            
            if let email = userSession.currentUser?.email {
                Text("Signed in as: \(email)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Sign out button for testing
            Button(action: signOut) {
                Text("Sign Out")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(width: UIScreen.main.bounds.width * 0.80)
                    .padding(.vertical, 16)
                    .background(Color.red)
                    .cornerRadius(30)
            }
            .padding(.bottom, 40)
        }
        .navigationBarHidden(true)
    }
    
    private func signOut() {
        do {
            try userSession.signOut()
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }
}

#Preview {
    QuickStartView()
        .environmentObject(UserSession())
}