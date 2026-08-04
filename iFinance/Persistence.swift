//
//  Persistence.swift
//  iFinance
//
//  Created by 刘不易 on 2026/1/7.
//

internal import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // 创建对象
        let newBill = Bill(context: viewContext)
        
        // 所有非可选字段必须赋非 nil 值
        newBill.id = UUID() // 👈 直接赋 UUID()，不是字符串！
        newBill.amount = 10
        newBill.date = Date()
        newBill.type = "expenditure"
        newBill.category = "餐饮"       // 可为 nil
        newBill.note = "吃了一顿肯德基"// 可为 nil
        newBill.createdAt = Date()
        newBill.createdBy = "preview@example.com"
        newBill.updatedAt = Date()
        newBill.updatedBy = "preview@example.com"
        
        // 创建对象
        let newBill2 = Bill(context: viewContext)
        
        // 所有非可选字段必须赋非 nil 值
        newBill2.id = UUID() // 👈 直接赋 UUID()，不是字符串！
        newBill2.amount = 500
        newBill2.date = Date()
        newBill2.type = "income"
        newBill2.category = "意外收入"       // 可为 nil
        newBill2.note = "中彩票了！！"// 可为 nil
        newBill2.createdAt = Date()
        newBill2.createdBy = "preview@example.com"
        newBill2.updatedAt = Date()
        newBill2.updatedBy = "preview@example.com"
        
        do {
            try viewContext.save()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    // iCloud 同步已暂时禁用（需付费开发者账号才能使用）
    // 使用普通 NSPersistentContainer 替代 NSPersistentCloudKitContainer
    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "iFinance")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        // 开启自动轻量迁移：当模型新增字段/实体时，Core Data自动推断映射，无需手写Mapping Model
        if let description = container.persistentStoreDescriptions.first {
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
        }

        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                /*
                 自动轻量迁移失败时才会到这里。常见原因：
                 - 修改了已有字段的类型（非轻量迁移支持范围）
                 - 删除了实体或字段（需手动迁移）
                 此时建议在开发阶段直接卸载 App 重装，生产环境需要 Mapping Model。
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true

        // 调试钩子：启动时检查是否需要清空所有数据
        if !inMemory {
            runStartupHooksIfNeeded()
        }
    }

    // MARK: - 启动钩子

    private static let _resetAllFlag = "_DevResetAllData"

    /// 调试用：下次启动时删除所有账号和账单（一次性操作）
    static func scheduleResetAllData() {
        UserDefaults.standard.set(true, forKey: _resetAllFlag)
    }

    private func runStartupHooksIfNeeded() {
        guard UserDefaults.standard.bool(forKey: Self._resetAllFlag) else { return }
        UserDefaults.standard.removeObject(forKey: Self._resetAllFlag)

        let context = container.viewContext

        // 删除所有账单
        let billReq: NSFetchRequest<NSFetchRequestResult> = Bill.fetchRequest()
        try? context.execute(NSBatchDeleteRequest(fetchRequest: billReq))

        // 删除所有用户
        let userReq: NSFetchRequest<NSFetchRequestResult> = UserProfile.fetchRequest()
        try? context.execute(NSBatchDeleteRequest(fetchRequest: userReq))

        try? context.save()
        print("✅ [Persistence] 已清空所有账号和账单数据")
    }
}

// MARK: - 用户数据隔离辅助
extension PersistenceController {
    /// 获取当前用户标识符（用于数据隔离）
    static var currentUserIdentifier: String {
        UserDefaults.standard.string(forKey: "AuthUserIdentifier") ?? "anonymous"
    }

    /// 获取账单的用户过滤 predicate
    static var billUserPredicate: NSPredicate {
        NSPredicate(format: "createdBy == %@", currentUserIdentifier)
    }

    /// 在主线程上获取当前 UserProfile 记录（如果不存在则创建）
    @MainActor
    func getOrCreateCurrentUser(identifier: String, context: NSManagedObjectContext) -> UserProfile {
        let request: NSFetchRequest<UserProfile> = UserProfile.fetchRequest()
        request.predicate = NSPredicate(format: "userIdentifier == %@", identifier)
        request.fetchLimit = 1

        if let existingUser = try? context.fetch(request).first {
            return existingUser
        }

        // 创建新用户
        let newUser = UserProfile(context: context)
        newUser.id = UUID()
        newUser.userIdentifier = identifier
        newUser.nickname = "用户\(Int.random(in: 100...999))"
        newUser.monthlyBudget = 3000
        newUser.createdAt = Date()
        newUser.updatedAt = Date()

        try? context.save()
        return newUser
    }

    /// 获取当前 UserProfile 记录（异步）
    @MainActor
    func fetchCurrentUser(identifier: String, context: NSManagedObjectContext) async -> UserProfile? {
        let request: NSFetchRequest<UserProfile> = UserProfile.fetchRequest()
        request.predicate = NSPredicate(format: "userIdentifier == %@", identifier)
        request.fetchLimit = 1

        return try? context.fetch(request).first
    }
}

