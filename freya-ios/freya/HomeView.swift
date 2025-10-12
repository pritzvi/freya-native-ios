import SwiftUI
import FirebaseStorage

struct HomeView: View {
    @StateObject var vm = HomeViewModel()
    let uid: String
    let reportId: String
    let scoreId: String
    @State private var showingCheckIn = false

    var body: some View {
        ZStack {
            // Base background
            Color(.systemBackground)
            
            // Gradient overlay (same as survey)
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
            .ignoresSafeArea()
            
            // Content
            ScrollView {
                VStack(spacing: 16) {
                // Title
                Text("freya")
                    .font(.custom("Garamond", size: 32))
                    .fontWeight(.black)
                    .padding(.top, 8)

                // Score card
                ScoreHeaderView(score: vm.score)

                // Recent score chips
                if !vm.recentScores.isEmpty {
                    HStack(spacing: 12) {
                        ForEach(Array(vm.recentScores.prefix(3))) { item in
                            ScoreChip(item: item, isSelected: item.id == vm.selectedScoreId) {
                                vm.selectScore(id: item.id)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }

                // Check-in button
                VStack(spacing: 8) {
                    Button(action: { showingCheckIn = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "camera")
                                .font(.system(size: 16))
                            Text("Check-in")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 16)
                        .background(Color.black)
                        .cornerRadius(30)
                    }
                    
                    Text("Last check-in: Today")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)

                ForEach(vm.sections) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.title)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)

                        ForEach(section.steps) { step in
                            RoutineRow(
                                step: step,
                                checked: vm.completedStepIds.contains(step.id)
                            ) {
                                vm.toggle(stepId: step.id)
                            }
                            .padding(.horizontal)
                        }
                    }
                }

                progressFooter
                    .padding(.horizontal)
            }
            .padding(.vertical)
        }
        }
        .onAppear { vm.start(uid: uid, reportId: reportId, scoreId: scoreId) }
        .onDisappear { vm.stop() }
        .sheet(isPresented: $showingCheckIn) {
            CheckInCaptureSheet(uid: uid) {}
        }
    }

    private var progressFooter: some View {
        let total = vm.sections.flatMap { $0.steps }.count
        let done = vm.completedStepIds.count
        return Text("\(done)/\(total) done today")
            .font(.footnote)
            .foregroundColor(.secondary)
    }
}

private struct ScoreChip: View {
    let item: ScoreListItem
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Text(dateText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(item.overall)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.black : Color(.systemGray4), lineWidth: isSelected ? 2 : 1)
            )
        }
    }

    private var dateText: String {
        guard let d = item.createdAt else { return "—" }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: d).uppercased()
    }
}

private struct CheckInCaptureSheet: View {
    let uid: String
    var onSubmitted: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var photo: UIImage? = nil
    @State private var isUploading = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Spacer()
                if let img = photo {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemGray6))
                        .frame(height: 260)
                        .overlay(
                            Image(systemName: "camera").font(.title).foregroundColor(.secondary)
                        )
                }
                Button(photo == nil ? "Take photo" : "Retake") { showingPicker = true }
                    .buttonStyle(.borderedProminent)
                Spacer()
                Button(isUploading ? "Submitting..." : "Submit check-in") { submit() }
                    .disabled(photo == nil || isUploading)
                    .buttonStyle(.bordered)
                Spacer(minLength: 8)
            }
            .padding()
            .navigationTitle("Check-in")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
        .sheet(isPresented: $showingPicker) {
            ImagePicker(image: $photo)
        }
    }

    @State private var showingPicker = false

    private func submit() {
        guard let img = photo, let jpeg = img.jpegData(compressionQuality: 0.8) else { return }
        isUploading = true
        let timestamp = Int(Date().timeIntervalSince1970)
        let path = "userImages/\(uid)/items/checkin-\(timestamp).jpg"
        let storageRef = FirebaseStorage.Storage.storage().reference(withPath: path)
        let meta = FirebaseStorage.StorageMetadata(); meta.contentType = "image/jpeg"

        Task {
            do {
                _ = try await storageRef.putDataAsync(jpeg, metadata: meta)
                _ = try await ApiClient.shared.submitDeepScan(uid: uid, gcsPaths: [path], emphasis: "checkin")
                isUploading = false
                dismiss()
                onSubmitted()
            } catch {
                isUploading = false
            }
        }
    }
}

private struct RoutineRow: View {
    let step: RoutineStep
    let checked: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: step.imageUrl) { img in
                img.resizable().scaledToFill()
            } placeholder: {
                Color(.secondarySystemFill)
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text(step.stepName.uppercased())
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(step.productName ?? "Add a \(step.stepName)")
                    .font(.body)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onToggle) {
                Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
}


