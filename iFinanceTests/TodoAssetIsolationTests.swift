//
//  TodoAssetIsolationTests.swift
//  iFinanceTests
//
//  M1 集成回归：待办 / 备忘 / 资产数据的账号隔离（createdBy）与账号删除联动。
//

import XCTest
import CoreData
@testable import iFinance

@MainActor
final class TodoAssetIsolationTests: XCTestCase {

    private var persistence: PersistenceController!
    private var context: NSManagedObjectContext!

    override func setUpWithError() throws {
        try super.setUpWithError()
        persistence = PersistenceController(inMemory: true)
        context = persistence.container.viewContext
        UserDefaults.standard.set("user_a", forKey: "AuthUserIdentifier")
    }

    override func tearDownWithError() throws {
        UserDefaults.standard.removeObject(forKey: "AuthUserIdentifier")
        context = nil
        persistence = nil
        try super.tearDownWithError()
    }

    // MARK: - 造数据

    @discardableResult
    private func makeTodo(identifier: String) -> TodoItem {
        let item = TodoItem(context: context)
        item.id = UUID()
        item.title = "写周报"
        item.priority = TodoPriority.high
        item.isDone = false
        item.repeatRule = TodoRepeat.noneRule
        item.createdAt = Date()
        item.updatedAt = Date()
        item.createdBy = identifier
        item.updatedBy = identifier

        let subtask = TodoSubtask(context: context)
        subtask.id = UUID()
        subtask.title = "整理数据"
        subtask.isDone = false
        subtask.createdAt = Date()
        subtask.owner = item

        let tag = TodoTag(context: context)
        tag.id = UUID()
        tag.name = "工作"
        tag.colorIndex = 0
        tag.createdBy = identifier
        tag.items = [item]

        return item
    }

    private func makeMemo(identifier: String) {
        let memo = MemoNote(context: context)
        memo.id = UUID()
        memo.title = "备忘"
        memo.content = "内容"
        memo.isPinned = false
        memo.createdAt = Date()
        memo.updatedAt = Date()
        memo.createdBy = identifier
        memo.updatedBy = identifier
    }

    private func makeAsset(identifier: String) {
        let account = AssetAccount(context: context)
        account.id = UUID()
        account.name = "现金"
        account.type = AssetType.cash.rawValue
        account.balance = NSDecimalNumber(value: 1_000)
        account.includeInTotal = true
        account.sortOrder = 0
        account.createdAt = Date()
        account.updatedAt = Date()
        account.createdBy = identifier
        account.updatedBy = identifier

        let snapshot = AssetSnapshot(context: context)
        snapshot.id = UUID()
        snapshot.date = Date()
        snapshot.totalAssets = NSDecimalNumber(value: 1_000)
        snapshot.totalLiabilities = NSDecimalNumber(value: 0)
        snapshot.createdAt = Date()
        snapshot.createdBy = identifier
    }

    private func count(_ request: NSFetchRequest<NSFetchRequestResult>) throws -> Int {
        try context.count(for: request)
    }

    private func fetchRequest(entity: String, predicate: NSPredicate?) -> NSFetchRequest<NSFetchRequestResult> {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: entity)
        request.predicate = predicate
        return request
    }

    // MARK: - 账号隔离

    func testTodoAndAssetDataAreIsolatedByCreatedBy() throws {
        makeTodo(identifier: "user_a")
        makeMemo(identifier: "user_a")
        makeAsset(identifier: "user_a")
        try context.save()

        // user_a 能看到自己的数据
        XCTAssertEqual(try count(fetchRequest(entity: "TodoItem", predicate: PersistenceController.todoUserPredicate)), 1)
        XCTAssertEqual(try count(fetchRequest(entity: "MemoNote", predicate: PersistenceController.memoUserPredicate)), 1)
        XCTAssertEqual(try count(fetchRequest(entity: "AssetAccount", predicate: PersistenceController.assetAccountUserPredicate)), 1)

        // 切到 user_b：三类数据都查不到
        UserDefaults.standard.set("user_b", forKey: "AuthUserIdentifier")
        XCTAssertEqual(try count(fetchRequest(entity: "TodoItem", predicate: PersistenceController.todoUserPredicate)), 0)
        XCTAssertEqual(try count(fetchRequest(entity: "MemoNote", predicate: PersistenceController.memoUserPredicate)), 0)
        XCTAssertEqual(try count(fetchRequest(entity: "AssetAccount", predicate: PersistenceController.assetAccountUserPredicate)), 0)
        XCTAssertEqual(try count(fetchRequest(entity: "AssetSnapshot", predicate: PersistenceController.assetSnapshotUserPredicate)), 0)
        XCTAssertEqual(try count(fetchRequest(entity: "TodoTag", predicate: PersistenceController.todoTagUserPredicate)), 0)
    }

    // MARK: - 账号删除联动

    func testDeleteTodoAndAssetDataClearsAllSixEntities() throws {
        makeTodo(identifier: "user_a")
        makeMemo(identifier: "user_a")
        makeAsset(identifier: "user_a")
        // 另一个账号的数据不应被误删
        makeMemo(identifier: "user_b")
        try context.save()

        AuthManager.deleteTodoAndAssetData(identifier: "user_a", context: context)
        try context.save()

        XCTAssertEqual(try count(fetchRequest(entity: "TodoItem", predicate: nil)), 0)
        XCTAssertEqual(try count(fetchRequest(entity: "TodoSubtask", predicate: nil)), 0, "子任务应随待办级联删除")
        XCTAssertEqual(try count(fetchRequest(entity: "TodoTag", predicate: nil)), 0)
        XCTAssertEqual(try count(fetchRequest(entity: "AssetAccount", predicate: nil)), 0)
        XCTAssertEqual(try count(fetchRequest(entity: "AssetSnapshot", predicate: nil)), 0)
        XCTAssertEqual(try count(fetchRequest(entity: "MemoNote", predicate: nil)), 1, "其它账号的备忘必须保留")
    }
}
