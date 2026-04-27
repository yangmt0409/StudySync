import SwiftUI
import SwiftData

struct AddTodoView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hSizeClass

    @Query(sort: \GradeCourse.name) private var courses: [GradeCourse]

    @State private var title = ""
    @State private var note = ""
    @State private var emoji = "📌"
    @State private var priority: TodoPriority = .medium
    @State private var selectedCourseName: String? = nil
    @State private var showOtherCourseField = false
    @State private var customCourseName = ""
    @State private var hasDueDate = false
    @State private var dueDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    @State private var showEmojiPicker = false

    private var canSave: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    private let emojis = ["📌", "📝", "📚", "💡", "🎯", "🔥", "⭐️", "🚀",
                          "💻", "📖", "✏️", "🗂️", "📊", "🔔", "🏃", "🎓",
                          "🧪", "📐", "🗓️", "💪", "🎨", "🔬", "📮", "🛒"]

    var body: some View {
        NavigationStack {
            ZStack {
                SSColor.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Emoji picker
                        emojiSection

                        // Title
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.todoTitleField)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)

                            TextField(L10n.todoTitlePlaceholder, text: $title)
                                .font(.system(size: 16))
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: SSRadius.small, style: .continuous)
                                        .fill(SSColor.backgroundCard)
                                )
                        }

                        // Note
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.todoNote)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)

                            TextField(L10n.todoNotePlaceholder, text: $note, axis: .vertical)
                                .font(.system(size: 15))
                                .lineLimit(3...6)
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: SSRadius.small, style: .continuous)
                                        .fill(SSColor.backgroundCard)
                                )
                        }

                        // Priority
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.projectDuePriority)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)

                            HStack(spacing: 10) {
                                ForEach(TodoPriority.allCases) { p in
                                    Button {
                                        priority = p
                                        HapticEngine.shared.selection()
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: p.icon)
                                                .font(.system(size: 12))
                                            Text(p.displayName)
                                                .font(.system(size: 14, weight: .medium))
                                        }
                                        .foregroundStyle(priority == p ? .white : Color(hex: p.colorHex))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background(
                                            Capsule().fill(priority == p ? Color(hex: p.colorHex) : Color(hex: p.colorHex).opacity(0.12))
                                        )
                                    }
                                }
                            }
                        }

                        // Course picker
                        coursePickerSection

                        // Due date
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle(isOn: $hasDueDate.animation(.spring(duration: 0.2))) {
                                Text(L10n.projectDueDate)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            .tint(SSColor.brand)

                            if hasDueDate {
                                DatePicker("", selection: $dueDate, displayedComponents: [.date])
                                    .datePickerStyle(.graphical)
                                    .tint(SSColor.brand)
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: SSRadius.medium, style: .continuous)
                                            .fill(SSColor.backgroundCard)
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, SSSpacing.xl)
                    .padding(.top, SSSpacing.md)
                    .padding(.bottom, SSSpacing.xxl)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(L10n.todoAdd)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.save) {
                        save()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
            .dismissKeyboardToolbar()
        }
    }

    // MARK: - Course Picker Section

    private var coursePickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.todoCourse)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(courses.filter { !$0.isArchived }, id: \.id) { course in
                        let isSelected = selectedCourseName == course.name && !showOtherCourseField
                        Button {
                            showOtherCourseField = false
                            selectedCourseName = isSelected ? nil : course.name
                            HapticEngine.shared.selection()
                        } label: {
                            Text(course.name)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(isSelected ? .white : SSColor.brand)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule().fill(isSelected ? SSColor.brand : SSColor.brand.opacity(0.12))
                                )
                        }
                    }

                    // "Other" option
                    Button {
                        showOtherCourseField.toggle()
                        if !showOtherCourseField {
                            customCourseName = ""
                            selectedCourseName = nil
                        } else {
                            selectedCourseName = nil
                        }
                        HapticEngine.shared.selection()
                    } label: {
                        Text(L10n.todoCourseOther)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(showOtherCourseField ? .white : .secondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(showOtherCourseField ? Color.secondary : Color.secondary.opacity(0.12))
                            )
                    }
                }
                .padding(.vertical, 2)
            }

            if showOtherCourseField {
                TextField(L10n.todoCoursePlaceholder, text: $customCourseName)
                    .font(.system(size: 15))
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: SSRadius.small, style: .continuous)
                            .fill(SSColor.backgroundCard)
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.2), value: showOtherCourseField)
    }

    // MARK: - Emoji Section

    private var emojiSection: some View {
        VStack(spacing: 12) {
            Button {
                withAnimation(.spring(duration: 0.2)) { showEmojiPicker.toggle() }
            } label: {
                Text(emoji)
                    .font(.system(size: 44))
                    .frame(width: 72, height: 72)
                    .background(
                        Circle().fill(Color(.tertiarySystemFill))
                    )
            }

            if showEmojiPicker {
                LazyVGrid(columns: iPadGridColumns(iPhone: 8, spacing: 8, sizeClass: hSizeClass), spacing: 10) {
                    ForEach(emojis, id: \.self) { e in
                        Button {
                            emoji = e
                            HapticEngine.shared.selection()
                        } label: {
                            Text(e)
                                .font(.system(size: 24))
                                .frame(width: 40, height: 40)
                                .background(
                                    Circle()
                                        .fill(emoji == e ? SSColor.brand.opacity(0.15) : Color.clear)
                                )
                        }
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: SSRadius.medium, style: .continuous)
                        .fill(SSColor.backgroundCard)
                )
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Save

    private func save() {
        let todo = TodoItem()
        todo.title = title.trimmingCharacters(in: .whitespaces)
        todo.note = note.trimmingCharacters(in: .whitespaces)
        todo.emoji = emoji
        todo.priority = priority
        todo.dueDate = hasDueDate ? dueDate : nil
        if showOtherCourseField {
            let custom = customCourseName.trimmingCharacters(in: .whitespaces)
            todo.courseName = custom.isEmpty ? nil : custom
        } else {
            todo.courseName = selectedCourseName
        }
        modelContext.insert(todo)
        TodoItemSyncService.shared.pushTodo(todo)
        HapticEngine.shared.success()
        dismiss()
    }
}

#Preview {
    AddTodoView()
        .modelContainer(for: TodoItem.self, inMemory: true)
}
