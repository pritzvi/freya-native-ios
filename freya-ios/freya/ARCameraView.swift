//
//  ARCameraView.swift
//  freya
//
//  Created by Prithvi B on 1/4/25.
//

import SwiftUI
import ARKit
import SceneKit

struct ARCameraView: View {
    @Binding var capturedImage: UIImage?
    @Environment(\.presentationMode) var presentationMode
    @State private var arView: ARSCNView?
    
    var body: some View {
        ZStack {
            // AR Face tracking view
            ARFaceViewContainer(capturedImage: $capturedImage)
                .onAppear {
                    // Store reference to ARView for photo capture
                }
            
            VStack {
                Spacer()
                
                // Capture controls
                HStack(spacing: 40) {
                    // Cancel button
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Cancel")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(20)
                    }
                    
                    // Capture button
                    Button(action: capturePhoto) {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 70, height: 70)
                            .overlay(
                                Circle()
                                    .stroke(Color.black, lineWidth: 3)
                                    .frame(width: 60, height: 60)
                            )
                    }
                    
                    // Spacer for balance
                    Button(action: {}) {
                        Text("Cancel")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.clear)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                    }
                    .disabled(true)
                }
                .padding(.bottom, 50)
            }
        }
        .background(Color.black)
        .navigationBarHidden(true)
    }
    
    private func capturePhoto() {
        // Get the current ARSCNView and capture a snapshot
        if let arView = findARSCNView() {
            let image = arView.snapshot()
            capturedImage = image
            presentationMode.wrappedValue.dismiss()
        }
    }
    
    private func findARSCNView() -> ARSCNView? {
        // This is a simplified approach - in production you'd want a cleaner reference
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return nil }
        
        return findARSCNViewInView(window)
    }
    
    private func findARSCNViewInView(_ view: UIView) -> ARSCNView? {
        if let arView = view as? ARSCNView {
            return arView
        }
        
        for subview in view.subviews {
            if let found = findARSCNViewInView(subview) {
                return found
            }
        }
        
        return nil
    }
}
