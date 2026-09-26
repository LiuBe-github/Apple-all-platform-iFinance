//
//  TodoRenderSmokeTests.swift
//  iFinanceSwiftDataTests
//
//  M2 渲染冒烟（SwiftData 版）：待办 tab / 待办编辑 sheet 在真实 ModelContainer 下跑一帧，
//  确认 @Query + 关系数组（标签 / 子任务）在运行时可正常求值。
//

import Testing
import Foundation
import SwiftData
import SwiftUI
@testable import iFinanceSwiftData

@MainActor
struct TodoRenderSmokeTests {

    private let identifier = "todo_smoke_user"

    // MARK: - 造数据

    private func seed(context: ModelContext) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let tag = TodoTag(name: "工作", colorIndex: 0, createdBy: identifier)
        context.insert(tag)

        let overdue = TodoItem(
            title: "逾期待办",
            note: "备注",
            dueDate: calendar.date(byAdding: .day, value: -2, to: today),
            priority: TodoPriority.high,
            repeatRule: TodoRepeat.weekly,
            createdBy: identifier,
            updatedBy: identifier
        )
        context.insert(overdue)
        overdue.tags = [tag]

        let subtask = TodoSubtask(title: "先整理数据")
        context.insert(subtask)
        subtask.owner = overdue

        context.insert(TodoItem(title: "无日期待办", priority: TodoPriority.none, createdBy: identifier, updatedBy: identifier))
        context.insert(MemoNote(title: "会议纪要", content: "下周一同步进度", isPinned: true, createdBy: identifier, updatedBy: identifier))
    }

    // MARK: - 渲染

    private func render(_ view: some View, size: CGSize = CGSize(width: 390, height: 760)) {
        let host = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = CGRect(origin: .zero, size: size)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        // 让 SwiftUI 完成一帧（@Query / List 的 body 在此求值）
        RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        #expect(host.view.bounds.width > 0)
        window.isHidden = true
    }

    @Test
    func todoTabRendersWithData() {
        UserDefaults.standard.set(identifier, forKey: "AuthUserIdentifier")
        defer { UserDefaults.standard.removeObject(forKey: "AuthUserIdentifier") }

        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        seed(context: context)
        try? context.save()

        render(TodoTabView().modelContainer(controller.container))
    }

    @Test
    func todoEditSheetRendersExistingItem() throws {
        UserDefaults.standard.set(identifier, forKey: "AuthUserIdentifier")
        defer { UserDefaults.standard.removeObject(forKey: "AuthUserIdentifier") }

        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        seed(context: context)
        try? context.save()

        let item = try #require(
            try context.fetch(FetchDescriptor<TodoItem>(predicate: PersistenceController.todoUserPredicate)).first
        )

        render(TodoEditSheet(item: item).modelContainer(controller.container))
    }
}
