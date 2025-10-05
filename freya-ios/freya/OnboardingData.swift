//
//  OnboardingData.swift
//  freya
//
//  Created by Prithvi B on 1/4/25.
//

import Foundation

struct OnboardingData {
    var name: String = ""
    var age: String = ""
    var gender: String = ""
    var freyaUsage: [String] = []
    var mainConcern: String = ""
    var additionalConcerns: [String] = []
    var skinFeel: String = ""
    var skinConditions: [String] = []
    var scarringConditions: [String] = []
    var skinReaction: String = ""
    var ethnicity: String = ""
    var isPregnantOrBreastfeeding: String = ""
    var additionalDetails: String = ""
    var currentRoutineOption: String = ""
    var hasIngredientSensitivities: String = ""
    var specificIngredients: String = ""
    var lifestyleFactors: [String] = []
    var investmentLevel: String = ""
    var timeInvestment: String = ""
    var wearsMakeup: String = ""
    var skincarePreferences: [String] = []
    
    // Convert to dictionary for Firebase
    func toDictionary() -> [String: Any] {
        return [
            "name": name,
            "age": age,
            "gender": gender,
            "freyaUsage": freyaUsage,
            "mainConcern": mainConcern,
            "additionalConcerns": additionalConcerns,
            "skinFeel": skinFeel,
            "skinConditions": skinConditions,
            "scarringConditions": scarringConditions,
            "skinReaction": skinReaction,
            "ethnicity": ethnicity,
            "isPregnantOrBreastfeeding": isPregnantOrBreastfeeding,
            "additionalDetails": additionalDetails,
            "currentRoutineOption": currentRoutineOption,
            "hasIngredientSensitivities": hasIngredientSensitivities,
            "specificIngredients": specificIngredients,
            "lifestyleFactors": lifestyleFactors,
            "investmentLevel": investmentLevel,
            "timeInvestment": timeInvestment,
            "wearsMakeup": wearsMakeup,
            "skincarePreferences": skincarePreferences,
            "completedAt": Date().timeIntervalSince1970
        ]
    }
}
