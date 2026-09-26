//
//  TodoTabView.swift
//  iFinance
//
//  待办 tab 根视图：待办 / 备忘分段 + 右上角新建 + 编辑 sheet 路由。
//  入口：TabView 的「待办」标签（第 3 个）。
//  说明：本文件是 iOS 主版与 SwiftData 版的同名副本，改动请同步另一处。
//

import SwiftUI
internal import CoreData

struct TodoTabView: View {

    // MARK: - 分段

    enum Segment: String, CaseIterable, Identifiable {
        case todo
        case memo

        var id: String { rawValue }

        var titleKey: String {
            switch self {
            case .todo: return "todo.segment.todo"
            case .memo: return "todo.segment.memo"
            }
        }
    }

    // MARK: - Sheet 目标（`item` / `note` 为 nil 表示新建）

    struct TodoEditorTarget: Identifiable {
        let id = UUID()
        let item: TodoItem?
    }

    struct MemoEditorTarget: Identifiable {
        let id = UUID()
        let note: MemoNote?
    }

    private enum EditorTarget: Identifiable {
        case todo(TodoEditorTarget)
        case memo(MemoEditorTarget)

        var id: UUID {
            switch self {
            case .todo(let target): return target.id
            case .memo(let target): return target.id
            }
        }
    }

    @State private var segment: Segment = .todo
    @State private var editorTarget: EditorTarget?

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()

                VStack(spacing: 0) {
                    Picker("", selection: $segment) {
                        ForEach(Segment.allCases) { segment in
                            Text(LocalizedStringKey(segment.titleKey))
                                .tag(segment)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .padding(.horizontal, AppSpacing.screen)
                    .padding(.bottom, AppSpacing.sm)
                    .accessibilityLabel(Text("todo.title"))
                    .appAnimation(AppMotion.quick, value: segment)

                    switch segment {
                    case .todo:
                        TodoListView { item in
                            editorTarget = .todo(TodoEditorTarget(item: item))
                        }
                    case .memo:
                        MemoListView { note in
                            editorTarget = .memo(MemoEditorTarget(note: note))
                        }
                    }
                }
                .appContentWidth()
            }
            .navigationTitle("todo.title")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: presentNewEditor) {
                        Image(systemName: "plus")
                            .font(.title3.weight(.semibold))
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(Text(LocalizedStringKey(segment == .todo ? "todo.add" : "memo.add")))
                }
            }
            .sheet(item: $editorTarget) { target in
                switch target {
                case .todo(let target):
                    TodoEditSheet(item: target.item)
                case .memo(let target):
                    MemoEditSheet(note: target.note)
                }
            }
        }
    }

    private func presentNewEditor() {
        HapticManager.shared.light()
        switch segment {
        case .todo:
            editorTarget = .todo(TodoEditorTarget(item: nil))
        case .memo:
            editorTarget = .memo(MemoEditorTarget(note: nil))
        }
    }
}

#Preview {
    TodoTabView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
