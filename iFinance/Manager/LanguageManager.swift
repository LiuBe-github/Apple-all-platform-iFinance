//
//  LanguageManager.swift
//  iFinance
//
//  Created by 刘不易 on 2026/2/25.
//

import Foundation
import SwiftUI
import Combine

class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    @Published var currentLanguage: AppLanguage = .system
    
    private init() {
        if let stored = UserDefaults.standard.string(forKey: "app_language"),
           let language = AppLanguage(rawValue: stored) {
            currentLanguage = language
        }
        applyLanguage()
    }
    
    func applyLanguage() {
        let languageCode: String
        
        switch currentLanguage {
        case .system:
            languageCode = Locale.preferredLanguages.first ?? "zh-Hans"
        case .zhHans:
            languageCode = "zh-Hans"
        case .zhHant:
            languageCode = "zh-Hant"
        case .en:
            languageCode = "en"
        case .ja:
            languageCode = "ja"
        }
        
        UserDefaults.standard.set([languageCode], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
    }
    
    func setLanguage(_ language: AppLanguage) {
        currentLanguage = language
        UserDefaults.standard.set(language.rawValue, forKey: "app_language")
        applyLanguage()
    }
}
