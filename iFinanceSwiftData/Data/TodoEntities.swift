//
//  TodoEntities.swift
//  iFinanceSwiftData
//
//  待办与备忘的 SwiftData 模型（与 Core Data 版 TodoItem / TodoSubtask / TodoTag / MemoNote
//  字段一一对应，三份模型契约保持一致）。
//

import Foundation
import SwiftData

/// 待办条目（支持截止日、优先级、重复规则、子任务与标签）
@Model
final class TodoItem {

    var id: UUID?
    var title: String
    var note: String?
    var dueDate: Date?
    /// 0 = 无、1 = 低、2 = 中、3 = 高（与 Core Data `Integer 16` 生成类型一致）
    var priority: Int16
    var isDone: Bool
    var completedAt: Date?
    /// none / daily / weekly / monthly / yearly
    var repeatRule: String
    var createdAt: Date
    var updatedAt: Date
    var createdBy: String
    var updatedBy: String

    /// 子任务（仅一层，随待办级联删除）
    @Relationship(deleteRule: .cascade, inverse: \TodoSubtask.owner)
    var subtasks: [TodoSubtask] = []

    /// 标签（多对多）
    @Relationship(inverse: \TodoTag.items)
    var tags: [TodoTag] = []

    init(
        id: UUID = UUID(),
        title: String,
        note: String? = nil,
        dueDate: Date? = nil,
        priority: Int16 = 0,
        isDone: Bool = false,
        completedAt: Date? = nil,
        repeatRule: String = "none",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        createdBy: String,
        updatedBy: String
    ) {
        self.id = id
        self.title = title
        self.note = note
        self.dueDate = dueDate
        self.priority = priority
        self.isDone = isDone
        self.completedAt = completedAt
        self.repeatRule = repeatRule
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.createdBy = createdBy
        self.updatedBy = updatedBy
        self.subtasks = []
        self.tags = []
    }
}

/// 待办子任务（仅一层）
@Model
final class TodoSubtask {

    var id: UUID?
    var title: String
    var isDone: Bool
    var createdAt: Date

    var owner: TodoItem?

    init(
        id: UUID = UUID(),
        title: String,
        isDone: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.isDone = isDone
        self.createdAt = createdAt
    }
}

/// 待办标签（每账号上限 12 个、名称 1–8 字符、不可重名）
@Model
final class TodoTag {

    var id: UUID?
    var name: String
    /// 复用 CategoryPalette 的 8 色板下标（与 Core Data `Integer 16` 生成类型一致）
    var colorIndex: Int16
    var createdBy: String?

    var items: [TodoItem] = []

    init(
        id: UUID = UUID(),
        name: String,
        colorIndex: Int16 = 0,
        createdBy: String?
    ) {
        self.id = id
        self.name = name
        self.colorIndex = colorIndex
        self.createdBy = createdBy
        self.items = []
    }
}

/// 备忘（字段全部 Optional，与项目现有 SwiftData 模型风格一致；标题缺省取正文首行）
@Model
final class MemoNote {

    var id: UUID?
    var title: String?
    var content: String?
    var isPinned: Bool?
    var createdAt: Date?
    var updatedAt: Date?
    var createdBy: String?
    var updatedBy: String?

    init(
        id: UUID? = UUID(),
        title: String? = nil,
        content: String? = nil,
        isPinned: Bool? = false,
        createdAt: Date? = Date(),
        updatedAt: Date? = Date(),
        createdBy: String? = nil,
        updatedBy: String? = nil
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.isPinned = isPinned
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.createdBy = createdBy
        self.updatedBy = updatedBy
    }
}
