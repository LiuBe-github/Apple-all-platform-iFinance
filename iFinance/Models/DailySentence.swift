//
//  DailySentence.swift
//  iFinance
//
//  Created by 刘不易 on 2026/2/6.
//

import Foundation

struct DailySentence: Codable, Identifiable {
    let id: String
    let content: String
    let note: String

    enum CodingKeys: String, CodingKey {
        case id, content, note
    }

    /// 兼容旧 JSON（无 id 字段）的解码；图片字段已随图片功能一并移除
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        content = try container.decode(String.self, forKey: .content)
        note = try container.decode(String.self, forKey: .note)
        // 如果 JSON 中没有 id，使用 content 作为后备
        id = (try? container.decode(String.self, forKey: .id)) ?? content
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(content, forKey: .content)
        try container.encode(note, forKey: .note)
    }

    /// 便利初始化器（用于 Preview 和手动创建）
    init(id: String? = nil, content: String, note: String) {
        self.id = id ?? content
        self.content = content
        self.note = note
    }
}

