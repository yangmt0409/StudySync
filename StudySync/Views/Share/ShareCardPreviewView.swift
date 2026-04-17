import SwiftUI
import Photos

struct ShareCardPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    let event: CountdownEvent

    @State private var selectedTemplate: ShareCardTemplate = .minimal
    @State private var selectedSize: ShareCardSize = .square
    @State private var renderedImage: UIImage?
    @State private var showSaveSuccess = false
    @State private var showShareSheet = false
    @State private var showError = false
    @State private var errorMessage = ""

    private var showWatermark: Bool { !StoreManager.shared.isPro }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 预览区
                ScrollView {
                    VStack(spacing: 20) {
                        // 预览图
                        previewCard
                            .padding(.top, 12)

                        // 模板选择
                        templatePicker

                        // 尺寸选择
                        sizePicker
                    }
                    .padding(.horizontal, 20)
                }

                Divider()

                // 底部按钮
                bottomButtons
            }
            .background {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
            }
            .navigationTitle(L10n.shareCard)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .overlay {
                if showSaveSuccess {
                    saveSuccessOverlay
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let image = renderedImage {
                    ActivityView(items: [image])
                }
            }
            .alert(L10n.errorTitle, isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
            .onAppear { renderCard() }
            .onChange(of: selectedTemplate) { _, _ in
                renderCard()
                HapticEngine.shared.selection()
            }
            .onChange(of: selectedSize) { _, _ in
                renderCard()
                HapticEngine.shared.selection()
            }
        }
    }

    // MARK: - Preview

    private var previewCard: some View {
        Group {
            if let image = renderedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    .frame(maxHeight: 400)
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.tertiarySystemFill))
                    .frame(height: 300)
                    .overlay(ProgressView())
            }
        }
    }

    // MARK: - Template Picker

    private var templatePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.template)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                ForEach(ShareCardTemplate.allCases) { template in
                    Button {
                        selectedTemplate = template
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: templateIcon(template))
                                .font(.system(size: 22))
                                .frame(width: 56, height: 56)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(selectedTemplate == template
                                              ? Color(hex: event.colorHex).opacity(0.15)
                                              : Color(.tertiarySystemFill))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(selectedTemplate == template
                                                ? Color(hex: event.colorHex) : .clear, lineWidth: 2)
                                )

                            Text(template.displayName)
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(selectedTemplate == template
                                         ? Color(hex: event.colorHex) : .secondary)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
        }
    }

    private func templateIcon(_ template: ShareCardTemplate) -> String {
        switch template {
        case .minimal: return "textformat.size"
        case .dotGrid: return "circle.grid.3x3.fill"
        case .card: return "rectangle.on.rectangle"
        }
    }

    // MARK: - Size Picker

    private var sizePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.sizeLabel)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)

            Picker("", selection: $selectedSize) {
                ForEach(ShareCardSize.allCases, id: \.self) { size in
                    Text(size.rawValue).tag(size)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Bottom Buttons

    private var bottomButtons: some View {
        HStack(spacing: 16) {
            Button {
                saveToPhotos()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.down")
                    Text(L10n.saveToPhotos)
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(hex: event.colorHex))
                )
            }

            Button {
                renderCard()
                showShareSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                    Text(L10n.share)
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(hex: event.colorHex))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(hex: event.colorHex), lineWidth: 2)
                )
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
    }

    // MARK: - Save Success Overlay

    private var saveSuccessOverlay: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)
                Text(L10n.savedToPhotos)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(32)
            .background(RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial))
        }
        .transition(.opacity)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation { showSaveSuccess = false }
            }
        }
    }

    // MARK: - Actions

    @MainActor
    private func renderCard() {
        renderedImage = ShareCardGenerator.render(
            event: event,
            template: selectedTemplate,
            size: selectedSize,
            showWatermark: showWatermark
        )
    }

    private func saveToPhotos() {
        guard let image = renderedImage else { return }

        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            DispatchQueue.main.async {
                if status == .authorized || status == .limited {
                    UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                    HapticEngine.shared.success()
                    withAnimation { showSaveSuccess = true }
                } else {
                    errorMessage = L10n.photoAccessDenied
                    showError = true
                }
            }
        }
    }
}

// MARK: - UIActivityViewController wrapper

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
