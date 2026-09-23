//
//  Persistence.swift
//  iFinanceSwiftData
//
//  SwiftData 版数据栈。
//  为让从 iOS Core Data 版复制过来的视图改动最小，这里保留了 PersistenceController 这一类型名，
//  并通过 ModelContainer.viewContext 扩展提供 `container.viewContext` 写法（内部即 mainContext）。
//

import Foundation
import SwiftData

struct PersistenceController {

    static let shared = PersistenceController()

    /// 预览 / 测试用内存容器（含示例账单）
    @MainActor
    static let preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.mainContext
        let identifier = currentUserIdentifier

        let sample1 = Bill(
            amount: 35.5,
            type: "expenditure",
            category: "餐饮",
            note: "午餐",
            date: Date(),
            createdBy: identifier,
            updatedBy: identifier
        )
        let sample2 = Bill(
            amount: 12000,
            type: "income",
            category: "工资",
            note: "月薪",
            date: Calendar.current.date(byAdding: .day, value: -1, to: Date()),
            createdBy: identifier,
            updatedBy: identifier
        )
        context.insert(sample1)
        context.insert(sample2)
        try? context.save()
        return controller
    }()

    let container: ModelContainer

    init(inMemory: Bool = false) {
        let schema = Schema([Bill.self, UserProfile.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("SwiftData 容器初始化失败：\(error)")
        }
    }

    // MARK: - 用户数据隔离

    /// 当前登录用户标识符（与 Core Data 版使用同一 UserDefaults key，Bundle ID 不同互不影响）
    static var currentUserIdentifier: String {
        UserDefaults.standard.string(forKey: "AuthUserIdentifier") ?? "anonymous"
    }

    /// 账单的用户过滤条件（SwiftData 版：#Predicate）
    static var billUserPredicate: Predicate<Bill> {
        let identifier = currentUserIdentifier
        return #Predicate<Bill> { $0.createdBy == identifier }
    }

    /// 指定用户的账单过滤条件（用于账号删除等场景）
    static func billPredicate(for identifier: String) -> Predicate<Bill> {
        #Predicate<Bill> { $0.createdBy == identifier }
    }
}

// MARK: - 兼容 Core Data 版的 `container.viewContext` 写法

extension ModelContainer {
    /// SwiftData 的主上下文；保留 Core Data 版的属性名以复用视图代码
    @MainActor
    var viewContext: ModelContext { mainContext }
}
