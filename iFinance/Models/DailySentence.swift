//
//  DailySentence.swift
//  iFinance
//
//  Created by 刘不易 on 2026/2/6.
//

import Foundation

struct DailySentence: Codable, Identifiable {
    var id: String {
        content
    }
    let content: String
    let note: String
    let picture2: String
    
    enum CodingKeys: String, CodingKey {
        case content, note, picture2
        // 注意：这里故意不包含 `id`
    }
}
