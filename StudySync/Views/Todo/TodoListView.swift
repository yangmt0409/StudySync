import SwiftUI
import SwiftData

struct TodoListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @Query(filter: #Predicate<TodoItem> { $0.isCompleted == false },
           sort: \TodoItem.createdAt, order: .reverse)
    private var activeTodos: [TodoItem]

    @Query(filter: #Predicate<TodoItem> { $0.isCompleted == true },
           sort: \TodoItem.createdAt, order: .reverse)
    private var completedTodos: [TodoItem]

    @State private var showingAddTodo = false
    @State private var editingTodo: TodoItem?
    @State private var showCompleted = false
    @State private var hasAppeared = false
    @State private var showClearAlert = false

    private var sortedActive: [TodoItem] {
        activeTodos.sorted { a, b in
            if a.priority.sortOrder != b.priority.sortOrder {
                return a.priority.sortOrder < b.priority.sortOrder
            }
            if let ad = a.dueDate, let bd = b.dueDate {
                return ad < bd
            }
            if a.dueDate != nil { return true }
            if b.dueDate != nil { return false }
            return a.createdAt > b.createdAt
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SSColor.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        if activeTodos.isEmpty && completedTodos.isEmpty {
                            emptyState
                        } else {
                            // Active todos
                            if !sortedActive.isEmpty {
                                VStack(spacing: 10) {
                                    ForEach(sortedActive) { todo in
                                        TodoRowView(todo: todo, onToggle: {
                                            toggleCompletion(todo)
                                        })
                                        .onTapGesture {
                                            editingTodo = todo
                                            HapticEngine.shared.lightImpact()
                                        }
                                        .opacity(hasAppeared ? 1 : 0)
                                        .offset(y: hasAppeared ? 0 : 10)
                                    }
                                }
                            } else {
                                allDoneState
                            }

                            // Completed section
                            if !completedTodos.isEmpty {
                                completedSection
                            }
                        }
                    }
                    .padding(.horizontal, SSSpacing.xl)
                    .padding(.top, SSSpacing.md)
                    .padding(.bottom, SSSpacing.xxl)
                }
            }
            .navigationTitle(L10n.todoTitle)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddTodo = true
                        HapticEngine.shared.lightImpact()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(SSColor.brand)
                    }
                }
            }
            .sheet(isPresented: $showingAddTodo) {
                AddTodoView()
            }
            .sheet(item: $editingTodo) { todo in
                EditTodoView(todo: todo)
            }
            .onAppear {
                withAnimation(.spring(duration: 0.5)) { hasAppeared = true }
            }
            .animation(.spring(duration: 0.3), value: activeTodos.count)
            .animation(.spring(duration: 0.3), value: completedTodos.count)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 60)

            Image(systemName: "checklist")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text(L10n.todoEmpty)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(L10n.todoEmptyDesc)
                .font(.system(size: 14))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            Button {
                showingAddTodo = true
                HapticEngine.shared.lightImpact()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                    Text(L10n.todoAdd)
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    Capsule().fill(SSColor.brand)
                )
            }
            .padding(.top, 8)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var allDoneState: some View {
        VStack(spacing: 12) {
            Text("🎉")
                .font(.system(size: 36))
            Text(L10n.todoAllDone)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Completed Section

    private var completedSection: some View {
        VStack(spacing: 10) {
            Button {
                withAnimation(.spring(duration: 0.3)) {
                    showCompleted.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: showCompleted ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)

                    Text(L10n.todoCompleted(completedTodos.count))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)

                    Spacer()

                    if showCompleted {
                        Button {
                            showClearAlert = true
                        } label: {
                            Text(L10n.todoClearCompleted)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.red.opacity(0.8))
                        }
                    }
                }
            }
            .buttonStyle(.plain)

            if showCompleted {
                ForEach(completedTodos.prefix(20)) { todo in
                    TodoRowView(todo: todo, onToggle: {
                        toggleCompletion(todo)
                    })
                    .opacity(0.6)
                }

                if completedTodos.count > 20 {
                    Text(L10n.todoMoreCompleted(completedTodos.count - 20))
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
            }
        }
        .alert(L10n.todoClearCompletedTitle, isPresented: $showClearAlert) {
            Button(L10n.todoClearCompletedConfirm, role: .destructive) {
                clearCompleted()
                HapticEngine.shared.warning()
            }
            Button(L10n.cancel, role: .cancel) { }
        } message: {
            Text(L10n.todoClearCompletedMessage(completedTodos.count))
        }
    }

    // MARK: - Actions

    private func toggleCompletion(_ todo: TodoItem) {
        withAnimation(.spring(duration: 0.3)) {
            todo.isCompleted.toggle()
            todo.completedAt = todo.isCompleted ? Date() : nil
            HapticEngine.shared.lightImpact()
        }
    }

    private func clearCompleted() {
        for todo in completedTodos {
            modelContext.delete(todo)
        }
    }
}

// MARK: - Todo Row

struct TodoRowView: View {
    let todo: TodoItem
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button(action: onToggle) {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(todo.isCompleted ? .green : Color(.tertiaryLabel))
            }
            .buttonStyle(.plain)

            // Emoji
            Text(todo.emoji)
                .font(.system(size: 20))

            // Content
            VStack(alignment: .leading, spacing: 3) {
                Text(todo.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(todo.isCompleted ? .secondary : .primary)
                    .strikethrough(todo.isCompleted)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    // Priority badge
                    HStack(spacing: 3) {
                        Image(systemName: todo.priority.icon)
                            .font(.system(size: 9))
                        Text(todo.priority.displayName)
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(Color(hex: todo.priority.colorHex))

                    // Due date
                    if let days = todo.daysRemaining {
                        Text(dueDateLabel(days))
                            .font(.system(size: 11))
                            .foregroundStyle(days < 0 ? .red : days == 0 ? .orange : .secondary)
                    }
                }
            }

            Spacer(minLength: 0)

            // Overdue indicator
            if todo.isOverdue {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.red)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: SSRadius.medium, style: .continuous)
                .fill(SSColor.backgroundCard)
        )
        .contentShape(Rectangle())
    }

    private func dueDateLabel(_ days: Int) -> String {
        if days < 0 { return L10n.projectDueOverdue }
        if days == 0 { return L10n.projectDueToday }
        return L10n.projectDueDaysLeft(days)
    }
}

#Preview {
    TodoListView()
        .modelContainer(for: TodoItem.self, inMemory: true)
}
