//
//  DailySentence.swift
//  iFinance
//
//  Created by 刘不易 on 2026/2/6.
//

import Foundation

struct DailySentence: Codable, Identifiable {
    var id = UUID()
    let content: String
    let note: String
    let picture2: String
}
