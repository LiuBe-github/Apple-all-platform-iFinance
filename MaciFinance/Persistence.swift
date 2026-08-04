//
//  Persistence.swift
//  MaciFinance
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext

        // 预览数据
        let bill1 = Bill(context: viewContext)
        bill1.id = UUID()
        bill1.amount = 35.5
        bill1.date = Date()
        bill1.type = "expenditure"
        bill1.category = "餐饮"
        bill1.note = "午餐"
        bill1.createdAt = Date()
        bill1.createdBy = PersistenceController.currentUserIdentifier
        bill1.updatedAt = Date()
        bill1.updatedBy = PersistenceController.currentUserIdentifier

        let bill2 = Bill(context: viewContext)
        bill2.id = UUID()
        bill2.amount = 12000
        bill2.date = Calendar.current.date(byAdding: .day, value: -1, to: Date())
        bill2.type = "income"
        bill2.category = "工资"
        bill2.note = "月薪"
        bill2.createdAt = Date()
        bill2.createdBy = PersistenceController.currentUserIdentifier
        bill2.updatedAt = Date()
        bill2.updatedBy = PersistenceController.currentUserIdentifier

        try? viewContext.save()
        return result
    }()

    /// 当前登录用户标识符（与 iOS 共享）
    static var currentUserIdentifier: String {
        UserDefaults.standard.string(forKey: "AuthUserIdentifier") ?? "anonymous"
    }

    // iCloud 同步已暂时禁用（需付费开发者账号才能使用）
    // 使用普通 NSPersistentContainer 替代 NSPersistentCloudKitContainer
    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "MaciFinance")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        // 开启自动轻量迁移：当模型新增字段/实体时，Core Data 自动推断映射
        if let description = container.persistentStoreDescriptions.first {
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
        }

        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Core Data error: \(error), \(error.userInfo)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
