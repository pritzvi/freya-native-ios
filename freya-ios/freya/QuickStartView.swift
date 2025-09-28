//
//  QuickStartView.swift
//  freya
//
//  Created by Prithvi B on 9/27/25.
//

import SwiftUI
import FirebaseFirestore

struct QuickStartView: View {
    @State private var name: String = ""
    @State private var age: String = ""
    @State private var output: String = "Enter your details and test Firebase"
    @State private var isRunning = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Quick Start")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.top)
            
            VStack(spacing: 16) {
                TextField("Your name", text: $name)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                TextField("Your age", text: $age)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
            }
            .padding(.horizontal)
            
            Text(output)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Button(isRunning ? "Running Test..." : "Run Firebase Test") {
                guard !isRunning, !name.isEmpty, !age.isEmpty else { return }
                runFirebaseTest()
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background((!name.isEmpty && !age.isEmpty && !isRunning) ? Color.blue : Color.gray)
            .cornerRadius(12)
            .disabled(name.isEmpty || age.isEmpty || isRunning)
            .padding(.horizontal)
            
            Spacer()
        }
        .navigationTitle("Firebase Test")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func runFirebaseTest() {
        isRunning = true
        output = "Signing in anonymously..."
        
        Task {
            do {
                let summary = try await FirebaseTestService.runTest(name: name, age: age)
                await MainActor.run {
                    output = summary
                    isRunning = false
                }
            } catch {
                await MainActor.run {
                    output = "Error: \(error.localizedDescription)"
                    isRunning = false
                }
            }
        }
    }
}

struct FirebaseTestService {
    static func runTest(name: String, age: String) async throws -> String {
        let db = Firestore.firestore()
        let id = UUID().uuidString
        let ref = db.collection("smokeTests").document(id)
        try await ref.setData([
            "name": name,
            "age": Int(age) ?? 0,
            "device": UIDevice.current.name,
            "ts": FieldValue.serverTimestamp()
        ])
        let snap = try await ref.getDocument()
        let saved = snap.get("name") as? String ?? "unknown"
        return "✅ Firestore OK\nDoc: \(id.prefix(8))…\nname='\(saved)'"
    }
}

#Preview {
    NavigationView {
        QuickStartView()
    }
}
