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
        bill1.createdBy = "user"
        bill1.updatedAt = Date()
        bill1.updatedBy = "user"

        let bill2 = Bill(context: viewContext)
        bill2.id = UUID()
        bill2.amount = 12000
        bill2.date = Calendar.current.date(byAdding: .day, value: -1, to: Date())
        bill2.type = "income"
        bill2.category = "工资"
        bill2.note = "月薪"
        bill2.createdAt = Date()
        bill2.createdBy = "user"
        bill2.updatedAt = Date()
        bill2.updatedBy = "user"

        try? viewContext.save()
        return result
    }()

    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "MaciFinance")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Core Data error: \(error), \(error.userInfo)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
