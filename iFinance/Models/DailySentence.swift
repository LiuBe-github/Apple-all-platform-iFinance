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
    let picture2: String

    enum CodingKeys: String, CodingKey {
        case id, content, note, picture2
    }

    /// 兼容旧 JSON（无 id 字段）的解码
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        content = try container.decode(String.self, forKey: .content)
        note = try container.decode(String.self, forKey: .note)
        picture2 = try container.decode(String.self, forKey: .picture2)
        // 如果 JSON 中没有 id，使用 content 的 hash 作为后备
        id = (try? container.decode(String.self, forKey: .id)) ?? content
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(content, forKey: .content)
        try container.encode(note, forKey: .note)
        try container.encode(picture2, forKey: .picture2)
    }

    /// 便利初始化器（用于 Preview 和手动创建）
    init(id: String? = nil, content: String, note: String, picture2: String) {
        self.id = id ?? content
        self.content = content
        self.note = note
        self.picture2 = picture2
    }
}
