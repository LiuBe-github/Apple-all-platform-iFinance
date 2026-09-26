//
//  TodoRenderSmokeTests.swift
//  iFinanceTests
//
//  M2 渲染冒烟：待办 tab / 待办编辑 sheet / 备忘编辑 sheet 在真实托管环境下跑一帧，
//  确认 @FetchRequest + 分组 + 关系（标签 / 子任务）在运行时可正常求值。
//

import XCTest
import SwiftUI
import CoreData
@testable import iFinance

@MainActor
final class TodoRenderSmokeTests: XCTestCase {

    private let identifier = "todo_smoke_user"

    private var persistence: PersistenceController!
    private var context: NSManagedObjectContext!
    private var window: UIWindow?

    override func setUpWithError() throws {
        try super.setUpWithError()
        persistence = PersistenceController(inMemory: true)
        context = persistence.container.viewContext
        UserDefaults.standard.set(identifier, forKey: "AuthUserIdentifier")
        seed()
    }

    override func tearDownWithError() throws {
        UserDefaults.standard.removeObject(forKey: "AuthUserIdentifier")
        window?.isHidden = true
        window = nil
        context = nil
        persistence = nil
        try super.tearDownWithError()
    }

    // MARK: - 造数据

    private func seed() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let tag = TodoTag(context: context)
        tag.id = UUID()
        tag.name = "工作"
        tag.colorIndex = 0
        tag.createdBy = identifier

        let overdue = makeTodo(
            title: "逾期待办",
            due: calendar.date(byAdding: .day, value: -2, to: today),
            priority: TodoPriority.high,
            repeatRule: TodoRepeat.weekly
        )
        overdue.addToTags(tag)

        let subtask = TodoSubtask(context: context)
        subtask.id = UUID()
        subtask.title = "先整理数据"
        subtask.isDone = false
        subtask.createdAt = Date()
        subtask.owner = overdue

        makeTodo(
            title: "今天的待办",
            due: today,
            priority: TodoPriority.medium,
            repeatRule: TodoRepeat.noneRule
        )
        makeTodo(
            title: "无日期待办",
            due: nil,
            priority: TodoPriority.none,
            repeatRule: TodoRepeat.noneRule
        )
        makeTodo(
            title: "已完成待办",
            due: calendar.date(byAdding: .day, value: -1, to: today),
            priority: TodoPriority.low,
            repeatRule: TodoRepeat.noneRule,
            isDone: true
        )

        [("会议纪要", "下周一同步进度", true), ("购物清单", "牛奶 / 鸡蛋", false)].forEach { title, content, pinned in
            let memo = MemoNote(context: context)
            memo.id = UUID()
            memo.title = title
            memo.content = content
            memo.isPinned = pinned
            memo.createdAt = Date()
            memo.updatedAt = Date()
            memo.createdBy = identifier
            memo.updatedBy = identifier
        }

        try? context.save()
    }

    @discardableResult
    private func makeTodo(
        title: String,
        due: Date?,
        priority: Int16,
        repeatRule: String,
        isDone: Bool = false
    ) -> TodoItem {
        let item = TodoItem(context: context)
        item.id = UUID()
        item.title = title
        item.note = "备注"
        item.dueDate = due
        item.priority = priority
        item.isDone = isDone
        item.completedAt = isDone ? Date() : nil
        item.repeatRule = repeatRule
        item.createdAt = Date()
        item.updatedAt = Date()
        item.createdBy = identifier
        item.updatedBy = identifier
        return item
    }

    // MARK: - 渲染

    private func render(_ view: some View, size: CGSize = CGSize(width: 390, height: 760)) {
        let host = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = host
        window.makeKeyAndVisible()
        self.window = window
        host.view.frame = CGRect(origin: .zero, size: size)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        // 让 SwiftUI 完成一帧（@FetchRequest / List 的 body 在此求值）
        RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        XCTAssertGreaterThan(host.view.bounds.width, 0)
    }

    /// 待办 tab（含数据：逾期 / 今天 / 无日期 / 已完成 + 标签 + 子任务）
    func testTodoTabRendersWithData() {
        render(TodoTabView().environment(\.managedObjectContext, context))
    }

    /// 待办列表空态
    func testTodoListRendersEmptyState() {
        let request: NSFetchRequest<TodoItem> = TodoItem.fetchRequest()
        (try? context.fetch(request))?.forEach { context.delete($0) }
        try? context.save()

        render(TodoListView { _ in }.environment(\.managedObjectContext, context))
    }

    /// 待办编辑 sheet（编辑既有待办：回填标签 / 子任务）
    func testTodoEditSheetRendersExistingItem() throws {
        let request: NSFetchRequest<TodoItem> = TodoItem.fetchRequest()
        request.predicate = NSPredicate(format: "title == %@", "逾期待办")
        let item = try XCTUnwrap(try context.fetch(request).first)

        render(TodoEditSheet(item: item).environment(\.managedObjectContext, context))
    }

    /// 备忘编辑 sheet（编辑既有备忘）
    func testMemoEditSheetRendersExistingNote() throws {
        let request: NSFetchRequest<MemoNote> = MemoNote.fetchRequest()
        let note = try XCTUnwrap(try context.fetch(request).first)

        render(MemoEditSheet(note: note).environment(\.managedObjectContext, context))
    }
}
