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
        newBill.createdBy = "user"
        newBill.updatedAt = Date()
        newBill.updatedBy = "user"
        
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
        newBill2.createdBy = "user"
        newBill2.updatedAt = Date()
        newBill2.updatedBy = "user"
        
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

    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "iFinance")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}

