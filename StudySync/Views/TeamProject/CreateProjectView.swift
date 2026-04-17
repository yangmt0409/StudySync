import SwiftUI

struct CreateProjectView: View {
    let viewModel: TeamProjectViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var emoji = "📁"
    @State private var colorHex = "#5B7FFF"
    @State private var isCreating = false

    private let emojiOptions = ["📁", "📚", "💻", "🎓", "🔬", "🎨", "📊", "🏗️", "🎯", "🚀", "📝", "🧪", "📐", "🌍", "🎵", "⚡"]
    private let colorOptions = ["#5B7FFF", "#FF6B6B", "#4ECDC4", "#FFD93D", "#FF8A5C", "#A8E6CF", "#DDA0DD", "#87CEEB"]

    var body: some View {
        NavigationStack {
            ZStack {
            SSColor.backgroundPrimary
                .ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    // Preview
                    VStack(spacing: 8) {
                        Text(emoji)
                            .font(.system(size: 56))
                        Text(name.isEmpty ? L10n.projectName : name)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(name.isEmpty ? .secondary : .primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color(hex: colorHex).opacity(0.08))
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )

                    // Name field
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.projectName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                        TextField(L10n.projectName, text: $name)
                            .font(.system(size: 16))
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(.secondarySystemGroupedBackground))
                            )
                    }

                    // Emoji picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.projectEmoji)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8), spacing: 8) {
                            ForEach(emojiOptions, id: \.self) { option in
                                Button {
                                    emoji = option
                                    HapticEngine.shared.selection()
                                } label: {
                                    Text(option)
                                        .font(.system(size: 28))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 6)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(emoji == option ? Color(hex: colorHex).opacity(0.15) : Color.clear)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .stroke(emoji == option ? Color(hex: colorHex) : Color.clear, lineWidth: 2)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Color picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.projectColor)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                        HStack(spacing: 10) {
                            ForEach(colorOptions, id: \.self) { hex in
                                Button {
                                    colorHex = hex
                                    HapticEngine.shared.selection()
                                } label: {
                                    Circle()
                                        .fill(Color(hex: hex))
                                        .frame(width: 34, height: 34)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: colorHex == hex ? 3 : 0)
                                                .shadow(color: Color(hex: hex).opacity(0.5), radius: colorHex == hex ? 4 : 0)
                                        )
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(L10n.projectCreate)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.cancel) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        createProject()
                    } label: {
                        if isCreating {
                            ProgressView()
                        } else {
                            Text(L10n.projectCreate)
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
                }
            }
        }
    }

    private func createProject() {
        isCreating = true
        Task {
            let success = await viewModel.createProject(
                name: name.trimmingCharacters(in: .whitespaces),
                emoji: emoji,
                colorHex: colorHex
            )
            isCreating = false
            if success {
                HapticEngine.shared.success()
                dismiss()
            }
        }
    }
}

#Preview {
    CreateProjectView(viewModel: TeamProjectViewModel())
}
