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
    @StateObject private var faceController = ARFaceController()

    var body: some View {
        ZStack {
            // AR Face tracking view
            ARFaceViewContainer(capturedImage: $capturedImage, controller: faceController)

            VStack {
                Spacer()
                HStack(spacing: 40) {
                    // Cancel button
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
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
        // Hide mesh for UX, capture pure camera pixel buffer, then show mesh again.
        faceController.captureCleanFrame(hideOverlayDuringCapture: true, hideDelay: 0.05) { image in
            if let image {
                capturedImage = image
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}
