//
//  OnboardingView.swift
//  freya
//
//  Created by Prithvi B on 1/4/25.
//

import SwiftUI

struct OnboardingView: View {
    @StateObject private var coordinator = OnboardingCoordinator()
    
    var body: some View {
        Group {
            switch coordinator.currentQuestion {
            case 1:
                OnboardingQuestionView(
                    questionNumber: 1,
                    totalQuestions: coordinator.totalQuestions,
                    title: "What is your name?",
                    subtitle: nil,
                    questionType: .textInput,
                    options: [],
                    textValue: $coordinator.onboardingData.name,
                    selectedOption: .constant(""),
                    selectedOptions: .constant([]),
                    onNext: coordinator.nextQuestion,
                    onBack: coordinator.previousQuestion
                )
                
            case 2:
                OnboardingQuestionView(
                    questionNumber: 2,
                    totalQuestions: coordinator.totalQuestions,
                    title: "Age?",
                    subtitle: nil,
                    questionType: .textInput,
                    options: [],
                    textValue: $coordinator.onboardingData.age,
                    selectedOption: .constant(""),
                    selectedOptions: .constant([]),
                    onNext: coordinator.nextQuestion,
                    onBack: coordinator.previousQuestion
                )
                
            case 3:
                OnboardingQuestionView(
                    questionNumber: 3,
                    totalQuestions: coordinator.totalQuestions,
                    title: "Gender?",
                    subtitle: nil,
                    questionType: .singleSelect,
                    options: ["Female", "Male", "Non-binary", "Prefer not to say"],
                    textValue: .constant(""),
                    selectedOption: $coordinator.onboardingData.gender,
                    selectedOptions: .constant([]),
                    onNext: coordinator.nextQuestion,
                    onBack: coordinator.previousQuestion
                )
                
            case 4:
                OnboardingQuestionView(
                    questionNumber: 4,
                    totalQuestions: coordinator.totalQuestions,
                    title: "How do you want to use Freya?",
                    subtitle: "This will help Freya shape your experience. Select all that apply.",
                    questionType: .multiSelect,
                    options: [
                        "I want to improve my skin & confidence",
                        "I don't have a routine and would like you to help me create one.",
                        "I want to improve my current routine",
                        "I want to save money on products",
                        "Scan products to find reviews and information",
                        "I just want to have fun!"
                    ],
                    textValue: .constant(""),
                    selectedOption: .constant(""),
                    selectedOptions: $coordinator.onboardingData.freyaUsage,
                    onNext: coordinator.nextQuestion,
                    onBack: coordinator.previousQuestion
                )
                
            case 5:
                OnboardingQuestionView(
                    questionNumber: 5,
                    totalQuestions: coordinator.totalQuestions,
                    title: "What is your main skincare concern?",
                    subtitle: nil,
                    questionType: .singleSelect,
                    options: [
                        "Acne", "Aging", "Scarring", "Oiliness", "Dryness",
                        "Dark circles", "Eye bags", "Fine lines & wrinkles",
                        "Enlarged pores / Blackheads", "Redness / Rosacea",
                        "Hyperpigmentation / Dark Spots", "None"
                    ],
                    textValue: .constant(""),
                    selectedOption: $coordinator.onboardingData.mainConcern,
                    selectedOptions: .constant([]),
                    onNext: coordinator.nextQuestion,
                    onBack: coordinator.previousQuestion
                )
                
            case 6:
                OnboardingQuestionView(
                    questionNumber: 6,
                    totalQuestions: coordinator.totalQuestions,
                    title: "Do you have more skincare concerns?",
                    subtitle: "Select as many as you want : )",
                    questionType: .multiSelect,
                    options: [
                        "Acne", "Scarring", "Oiliness", "Dryness", "Dark circles",
                        "Eye bags", "Fine lines & wrinkles", "Enlarged pores",
                        "Redness", "Hyperpigmentation", "None"
                    ],
                    textValue: .constant(""),
                    selectedOption: .constant(""),
                    selectedOptions: $coordinator.onboardingData.additionalConcerns,
                    onNext: coordinator.nextQuestion,
                    onBack: coordinator.previousQuestion
                )
                
            case 7:
                OnboardingQuestionView(
                    questionNumber: 7,
                    totalQuestions: coordinator.totalQuestions,
                    title: "How does your skin feel on a typical day?",
                    subtitle: nil,
                    questionType: .singleSelect,
                    options: [
                        "Very Dry — Flaky, rough patches, can't moisturize enough.",
                        "Dry — Tight or rough or white dry areas in some spots.",
                        "Combination — Some areas dry, others shiny.",
                        "Oily — Shiny or greasy most of the time.",
                        "Neutral — None of the above."
                    ],
                    textValue: .constant(""),
                    selectedOption: $coordinator.onboardingData.skinFeel,
                    selectedOptions: .constant([]),
                    onNext: coordinator.nextQuestion,
                    onBack: coordinator.previousQuestion
                )
                
            case 8:
                OnboardingQuestionView(
                    questionNumber: 8,
                    totalQuestions: coordinator.totalQuestions,
                    title: "Select all that apply to you.",
                    subtitle: nil,
                    questionType: .multiSelect,
                    options: [
                        "My skin feels swollen or painful to the touch",
                        "My skin feels inflamed or I have hard bumps",
                        "My skin varies with my cycle",
                        "I am experiencing a worse than usual breakout",
                        "None of the above"
                    ],
                    textValue: .constant(""),
                    selectedOption: .constant(""),
                    selectedOptions: $coordinator.onboardingData.skinConditions,
                    onNext: coordinator.nextQuestion,
                    onBack: coordinator.previousQuestion
                )
                
            case 9:
                OnboardingQuestionView(
                    questionNumber: 9,
                    totalQuestions: coordinator.totalQuestions,
                    title: "Select all that apply to you.",
                    subtitle: nil,
                    questionType: .multiSelect,
                    options: [
                        "I notice raised scars after skin damage heals",
                        "My scars get darker with sun exposure",
                        "Others in my family (e.g., parents, siblings) experience scars similar to mine",
                        "I get scars even after minor breakouts",
                        "I have new active acne along with my existing scarring",
                        "None of the above"
                    ],
                    textValue: .constant(""),
                    selectedOption: .constant(""),
                    selectedOptions: $coordinator.onboardingData.scarringConditions,
                    onNext: coordinator.nextQuestion,
                    onBack: coordinator.previousQuestion
                )
                
            case 10:
                OnboardingQuestionView(
                    questionNumber: 10,
                    totalQuestions: coordinator.totalQuestions,
                    title: "How does your skin react to new products?",
                    subtitle: nil,
                    questionType: .singleSelect,
                    options: [
                        "Breakout Prone — My skin usually breaks out with new products.",
                        "Sensitive — My skin reacts with irritation or itchiness.",
                        "Balanced — Sometimes my skin reacts with new products, but it's very manageable.",
                        "Resistant — My skin rarely reacts to new products."
                    ],
                    textValue: .constant(""),
                    selectedOption: $coordinator.onboardingData.skinReaction,
                    selectedOptions: .constant([]),
                    onNext: coordinator.nextQuestion,
                    onBack: coordinator.previousQuestion
                )
                
            case 11:
                DeepScanView(
                    onNext: coordinator.nextQuestion,
                    onBack: coordinator.previousQuestion
                )
                
            case 12:
                OnboardingQuestionView(
                    questionNumber: 12,
                    totalQuestions: coordinator.totalQuestions,
                    title: "What is your ethnicity and background?",
                    subtitle: "This helps Freya understand how your skin might react to certain products, treatments, and ingredients like strong acids.",
                    questionType: .singleSelect,
                    options: [
                        "White / Caucasian", "East Asian", "South Asian",
                        "Hispanic / Latino", "Middle Eastern / North African",
                        "Black / African American", "Indigenous / Native"
                    ],
                    textValue: .constant(""),
                    selectedOption: $coordinator.onboardingData.ethnicity,
                    selectedOptions: .constant([]),
                    onNext: coordinator.nextQuestion,
                    onBack: coordinator.previousQuestion
                )
                
            case 13:
                OnboardingQuestionView(
                    questionNumber: 13,
                    totalQuestions: coordinator.totalQuestions,
                    title: "Are you pregnant or breastfeeding?",
                    subtitle: "Certain ingredients have not been tested on those who are pregnant or breastfeeding, so we will exclude those from your recommendations.",
                    questionType: .singleSelect,
                    options: ["Yes", "No"],
                    textValue: .constant(""),
                    selectedOption: $coordinator.onboardingData.isPregnantOrBreastfeeding,
                    selectedOptions: .constant([]),
                    onNext: coordinator.nextQuestion,
                    onBack: coordinator.previousQuestion
                )
                
            case 14:
                OnboardingQuestionView(
                    questionNumber: 14,
                    totalQuestions: coordinator.totalQuestions,
                    title: "Please share any details about your concerns or specific questions you want answered.",
                    subtitle: "The more detail, the better",
                    questionType: .textArea,
                    options: [],
                    textValue: $coordinator.onboardingData.additionalDetails,
                    selectedOption: .constant(""),
                    selectedOptions: .constant([]),
                    onNext: coordinator.nextQuestion,
                    onBack: coordinator.previousQuestion
                )
                
            case 15:
                OnboardingQuestionView(
                    questionNumber: 15,
                    totalQuestions: coordinator.totalQuestions,
                    title: "Ok, we're almost done.",
                    subtitle: "We need to know about your current routine and products before we show you your Skin Report",
                    questionType: .singleSelect,
                    options: [
                        "Take a photo of my bathroom shelf 📸",
                        "I'll type them in 😊",
                        "I use no products at all"
                    ],
                    textValue: .constant(""),
                    selectedOption: $coordinator.onboardingData.currentRoutineOption,
                    selectedOptions: .constant([]),
                    onNext: coordinator.nextQuestion,
                    onBack: coordinator.previousQuestion
                )
                
            case 16:
                OnboardingQuestionView(
                    questionNumber: 16,
                    totalQuestions: coordinator.totalQuestions,
                    title: "Do you breakout or have sensitivities to any particular skincare ingredients?",
                    subtitle: nil,
                    questionType: .singleSelect,
                    options: ["Yes", "No"],
                    textValue: .constant(""),
                    selectedOption: $coordinator.onboardingData.hasIngredientSensitivities,
                    selectedOptions: .constant([]),
                    onNext: coordinator.nextQuestion,
                    onBack: coordinator.previousQuestion
                )
                
            case 17:
                OnboardingQuestionView(
                    questionNumber: 17,
                    totalQuestions: coordinator.totalQuestions,
                    title: "Which ingredients cause you problems?",
                    subtitle: "Please list them separated by commas",
                    questionType: .textArea,
                    options: [],
                    textValue: $coordinator.onboardingData.specificIngredients,
                    selectedOption: .constant(""),
                    selectedOptions: .constant([]),
                    onNext: coordinator.nextQuestion,
                    onBack: coordinator.previousQuestion
                )
                
            case 18:
                OnboardingQuestionView(
                    questionNumber: 18,
                    totalQuestions: coordinator.totalQuestions,
                    title: "Select all that apply to you.",
                    subtitle: "Lifestyle factors can be a key contributor to some skincare concerns.",
                    questionType: .multiSelect,
                    options: [
                        "I wear sunscreen every day",
                        "I drink at least 8 glasses of water every day",
                        "I get 7-8 hours of sleep on most nights",
                        "My stress levels are under control",
                        "I consume processed sugar several times per week",
                        "I consume dairy several times per week",
                        "I exercise / sweat everyday",
                        "None of the above"
                    ],
                    textValue: .constant(""),
                    selectedOption: .constant(""),
                    selectedOptions: $coordinator.onboardingData.lifestyleFactors,
                    onNext: coordinator.nextQuestion,
                    onBack: coordinator.previousQuestion
                )
                
            case 19:
                OnboardingQuestionView(
                    questionNumber: 19,
                    totalQuestions: coordinator.totalQuestions,
                    title: "How much do you prefer to invest in skincare?",
                    subtitle: nil,
                    questionType: .singleSelect,
                    options: [
                        "I prefer the simplest products that work",
                        "I am willing to splurge on effective products",
                        "I prefer to always get premium products"
                    ],
                    textValue: .constant(""),
                    selectedOption: $coordinator.onboardingData.investmentLevel,
                    selectedOptions: .constant([]),
                    onNext: coordinator.nextQuestion,
                    onBack: coordinator.previousQuestion
                )
                
            case 20:
                OnboardingQuestionView(
                    questionNumber: 20,
                    totalQuestions: coordinator.totalQuestions,
                    title: "How much time do you want to invest daily?",
                    subtitle: nil,
                    questionType: .singleSelect,
                    options: ["< 5mins", "5 - 15 mins", "15 - 30 mins", "> 30 mins"],
                    textValue: .constant(""),
                    selectedOption: $coordinator.onboardingData.timeInvestment,
                    selectedOptions: .constant([]),
                    onNext: coordinator.nextQuestion,
                    onBack: coordinator.previousQuestion
                )
                
            case 21:
                OnboardingQuestionView(
                    questionNumber: 21,
                    totalQuestions: coordinator.totalQuestions,
                    title: "Do you wear makeup or heavy SPF sunscreen daily?",
                    subtitle: nil,
                    questionType: .singleSelect,
                    options: ["Yes", "No"],
                    textValue: .constant(""),
                    selectedOption: $coordinator.onboardingData.wearsMakeup,
                    selectedOptions: .constant([]),
                    onNext: coordinator.nextQuestion,
                    onBack: coordinator.previousQuestion
                )
                
            default:
                Text("Loading...")
            }
        }
        .overlay(
            // Loading overlay
            Group {
                if coordinator.isLoading {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 20) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                            
                            Text("Saving your profile...")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .padding(40)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(20)
                    }
                }
            }
        )
        .alert("Error", isPresented: .constant(!coordinator.errorMessage.isEmpty)) {
            Button("OK") {
                coordinator.errorMessage = ""
            }
        } message: {
            Text(coordinator.errorMessage)
        }
    }
}

#Preview {
    OnboardingView()
}
