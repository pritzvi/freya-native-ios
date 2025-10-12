//
//  OnboardingQuestionView.swift
//  freya
//
//  Created by Prithvi B on 1/4/25.
//

import SwiftUI

enum QuestionType {
    case textInput
    case singleSelect
    case multiSelect
    case textArea
}

struct OnboardingQuestionView: View {
    let questionNumber: Int
    let totalQuestions: Int
    let title: String
    let subtitle: String?
    let questionType: QuestionType
    let options: [String]
    
    @Binding var textValue: String
    @Binding var selectedOption: String
    @Binding var selectedOptions: [String]
    
    let onNext: () -> Void
    let onBack: () -> Void
    @State private var isSkipActive = false
    
    var canProceed: Bool {
        switch questionType {
        case .textInput, .textArea:
            return !textValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .singleSelect:
            return !selectedOption.isEmpty
        case .multiSelect:
            return !selectedOptions.isEmpty
        }
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
                header
                
                ScrollView {
                    content
                        .padding(.top, 20)
                }
            }

#if DEBUG
            // Debug-only Skip floating button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: { isSkipActive = true }) {
                        Text("Skip (test)")
                            .font(.footnote)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color(.secondarySystemBackground)))
                    }
                    .padding(16)
                }
            }
#endif
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
                    Text(questionNumber == totalQuestions ? "Finish" : "Next")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(canProceed ? Color.black : Color(.systemGray4))
                        .cornerRadius(25)
                }
                .disabled(!canProceed)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .background(Color(.systemBackground))
            }
        }
        .navigationBarHidden(true)
        .scrollDismissesKeyboard(.interactively)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .background(
            Group {
#if DEBUG
                NavigationLink(isActive: $isSkipActive, destination: {
                    MainTabView(
                        uid: "KUUE1r0AdDSehwbOLSM9E3Mhfeg2",
                        reportId: "mgmf0xwqm7nan6atvw",
                        scoreId: "mgmf00j3d0wbpaor0s7"
                    )
                }) {
                    EmptyView()
                }
#endif
            }
        )
    }
    
    private var header: some View {
        VStack(spacing: 20) {
            HStack {
                if questionNumber > 1 {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(.black)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            
            VStack(spacing: 8) {
                HStack {
                    Text("\(questionNumber)/\(totalQuestions)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(height: 4)
                            .cornerRadius(2)
                        
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.435, green: 0.835, blue: 0.788),
                                        Color(red: 0.435, green: 0.835, blue: 0.788).opacity(0.7)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * (Double(questionNumber) / Double(totalQuestions)), height: 4)
                            .cornerRadius(2)
                    }
                }
                .frame(height: 4)
            }
            .padding(.horizontal, 20)
            
            VStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 28, weight: .bold, design: .default))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    private var content: some View {
        VStack(spacing: 16) {
            switch questionType {
            case .textInput:
                TextField("Enter your answer", text: $textValue)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal, 20)
                
            case .textArea:
                VStack(alignment: .leading, spacing: 8) {
                    TextEditor(text: $textValue)
                        .frame(minHeight: 120)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                }
                .padding(.horizontal, 20)
                
            case .singleSelect:
                LazyVStack(spacing: 12) {
                    ForEach(options, id: \.self) { option in
                        Button(action: {
                            selectedOption = option
                        }) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(getOptionTitle(option))
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundColor(.black)
                                            .multilineTextAlignment(.leading)
                                        
                                        if let description = getOptionDescription(option) {
                                            Text(description)
                                                .font(.system(size: 14, weight: .regular))
                                                .foregroundColor(.secondary)
                                                .multilineTextAlignment(.leading)
                                        }
                                    }
                                    Spacer()
                                }
                            }
                            .padding(20)
                            .background(Color(.systemBackground))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        selectedOption == option ?
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.435, green: 0.835, blue: 0.788),
                                                Color(red: 0.435, green: 0.835, blue: 0.788).opacity(0.6)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ) :
                                        LinearGradient(
                                            colors: [Color(.systemGray5), Color(.systemGray5)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: selectedOption == option ? 2 : 1
                                    )
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
                
            case .multiSelect:
                LazyVStack(spacing: 12) {
                    ForEach(options, id: \.self) { option in
                        Button(action: {
                            if selectedOptions.contains(option) {
                                selectedOptions.removeAll { $0 == option }
                            } else {
                                selectedOptions.append(option)
                            }
                        }) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(getOptionTitle(option))
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundColor(.black)
                                            .multilineTextAlignment(.leading)
                                        
                                        if let description = getOptionDescription(option) {
                                            Text(description)
                                                .font(.system(size: 14, weight: .regular))
                                                .foregroundColor(.secondary)
                                                .multilineTextAlignment(.leading)
                                        }
                                    }
                                    Spacer()
                                }
                            }
                            .padding(20)
                            .background(Color(.systemBackground))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        selectedOptions.contains(option) ?
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.435, green: 0.835, blue: 0.788),
                                                Color(red: 0.435, green: 0.835, blue: 0.788).opacity(0.6)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ) :
                                        LinearGradient(
                                            colors: [Color(.systemGray5), Color(.systemGray5)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: selectedOptions.contains(option) ? 2 : 1
                                    )
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // Helper functions to parse option titles and descriptions
    private func getOptionTitle(_ option: String) -> String {
        if option.contains(" — ") {
            return String(option.split(separator: " — ")[0])
        }
        return option
    }
    
    private func getOptionDescription(_ option: String) -> String? {
        if option.contains(" — ") {
            let parts = option.split(separator: " — ")
            if parts.count > 1 {
                return String(parts[1])
            }
        }
        return nil
    }
}

#Preview {
    OnboardingQuestionView(
        questionNumber: 1,
        totalQuestions: 21,
        title: "What is your name?",
        subtitle: nil,
        questionType: .textInput,
        options: [],
        textValue: .constant(""),
        selectedOption: .constant(""),
        selectedOptions: .constant([]),
        onNext: {},
        onBack: {}
    )
}