//
//  DeepScanView.swift
//  freya
//
//  Created by Prithvi B on 1/4/25.
//

import SwiftUI
import ARKit

struct DeepScanView: View {
    @State private var capturedPhotos: [UIImage?] = [nil, nil, nil, nil]
    @State private var currentPhotoIndex = 0
    @State private var showingARCamera = false

    let onNext: () -> Void
    let onBack: () -> Void

    private let photoInstructions = [
        "Take a front-facing photo of your face",
        "Turn your head to the left and take a side profile",
        "Turn your head to the right and take the other side profile",
        "Tilt your head slightly up and take a photo from below"
    ]

    private var allPhotosComplete: Bool {
        capturedPhotos.allSatisfy { $0 != nil }
    }

    var body: some View {
        ZStack {
            Color(.systemBackground)

            RadialGradient(
                colors: [
                    Color(red: 0.435, green: 0.835, blue: 0.788).opacity(0.3),
                    Color(red: 0.435, green: 0.835, blue: 0.788).opacity(0.1),
                    .clear
                ],
                center: UnitPoint(x: 0.7, y: 0.3),
                startRadius: 50,
                endRadius: 300
            )

            VStack(spacing: 0) {
                // Top
                VStack(spacing: 20) {
                    HStack {
                        Button(action: onBack) {
                            Image(systemName: "chevron.left")
                                .font(.title2)
                                .fontWeight(.medium)
                                .foregroundColor(.black)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)

                    VStack(spacing: 8) {
                        Text("Photo \(currentPhotoIndex + 1) of 4")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack(spacing: 8) {
                            ForEach(0..<4, id: \.self) { index in
                                Circle()
                                    .fill(index <= currentPhotoIndex ? Color(red: 0.435, green: 0.835, blue: 0.788) : Color(.systemGray4))
                                    .frame(width: 8, height: 8)
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    VStack(spacing: 12) {
                        Text("Let's analyze your skin!")
                            .font(.system(size: 28, weight: .bold, design: .default))
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)

                        Text(photoInstructions[currentPhotoIndex])
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 20)
                }

                // Main
                VStack(spacing: 30) {
                    Spacer()

                    VStack(spacing: 16) {
                        HStack(spacing: 16) {
                            PhotoSlot(image: capturedPhotos[0], label: "Front", isActive: currentPhotoIndex == 0, onTap: { currentPhotoIndex = 0 })
                            PhotoSlot(image: capturedPhotos[1], label: "Left",  isActive: currentPhotoIndex == 1, onTap: { currentPhotoIndex = 1 })
                        }
                        HStack(spacing: 16) {
                            PhotoSlot(image: capturedPhotos[2], label: "Right", isActive: currentPhotoIndex == 2, onTap: { currentPhotoIndex = 2 })
                            PhotoSlot(image: capturedPhotos[3], label: "Below", isActive: currentPhotoIndex == 3, onTap: { currentPhotoIndex = 3 })
                        }
                    }

                    Button(action: { showingARCamera = true }) {
                        Text(capturedPhotos[currentPhotoIndex] == nil ? "Take Photo \(currentPhotoIndex + 1)/4" : "Retake Photo \(currentPhotoIndex + 1)/4")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 250)
                            .padding(.vertical, 16)
                            .background(Color.black)
                            .cornerRadius(25)
                    }

                    Spacer()
                }
                .padding(.horizontal, 20)
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [Color(.systemBackground).opacity(0), Color(.systemBackground)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 12)

                Button(action: onNext) {
                    Text("Continue")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(allPhotosComplete ? Color.black : Color(.systemGray4))
                        .cornerRadius(25)
                }
                .disabled(!allPhotosComplete)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .background(Color(.systemBackground))
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingARCamera) {
            ARCameraView(capturedImage: Binding(
                get: { capturedPhotos[currentPhotoIndex] },
                set: { newImage in
                    capturedPhotos[currentPhotoIndex] = newImage
                    if newImage != nil && currentPhotoIndex < 3 {
                        currentPhotoIndex += 1
                    }
                }
            ))
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.presentationMode) var presentationMode

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.cameraDevice = .front
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            parent.presentationMode.wrappedValue.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

struct PhotoSlot: View {
    let image: UIImage?
    let label: String
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isActive ? Color(red: 0.435, green: 0.835, blue: 0.788) : Color.clear, lineWidth: 3)
                        )
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                        .frame(width: 80, height: 80)
                        .overlay(
                            VStack(spacing: 4) {
                                Image(systemName: "camera")
                                    .font(.system(size: 20))
                                    .foregroundColor(.secondary)
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isActive ? Color(red: 0.435, green: 0.835, blue: 0.788) : Color(.systemGray4), lineWidth: isActive ? 3 : 1)
                        )
                }

                Text(label)
                    .font(.caption)
                    .foregroundColor(isActive ? Color(red: 0.435, green: 0.835, blue: 0.788) : .secondary)
                    .fontWeight(isActive ? .semibold : .regular)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
