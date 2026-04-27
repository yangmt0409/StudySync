import SwiftUI

struct JoinProjectView: View {
    let viewModel: TeamProjectViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var code = ""
    @State private var isJoining = false
    @State private var resultMessage: String?
    @State private var isSuccess = false
    @State private var showScanner = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                VStack(spacing: SSSpacing.xxxl) {
                    Spacer().frame(height: 20)

                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 48))
                        .foregroundStyle(SSColor.brand)

                    Text(L10n.projectJoin)
                        .font(.system(size: 22, weight: .bold))

                    Text(L10n.projectEnterCode)
                        .font(SSFont.secondary)
                        .foregroundStyle(.secondary)

                    // Scan QR button
                    Button {
                        HapticEngine.shared.lightImpact()
                        showScanner = true
                    } label: {
                        HStack(spacing: SSSpacing.md) {
                            Image(systemName: "qrcode.viewfinder")
                                .font(SSFont.bodySemibold)
                            Text(L10n.projectScanQR)
                                .font(SSFont.bodySmallSemibold)
                        }
                        .foregroundStyle(SSColor.brand)
                        .padding(.horizontal, SSSpacing.xxl)
                        .padding(.vertical, SSSpacing.mdLg)
                        .background(
                            Capsule().fill(SSColor.brand.opacity(SSOpacity.tagBackground))
                        )
                    }

                    // Code field
                    TextField("ABCD1234", text: $code)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .padding(SSSpacing.xl)
                        .background(
                            RoundedRectangle(cornerRadius: SSRadius.medium, style: .continuous)
                                .fill(Color(.secondarySystemGroupedBackground))
                        )
                        .padding(.horizontal, 40)
                        .onChange(of: code) { _, newValue in
                            code = String(newValue.prefix(8)).uppercased()
                        }

                    // Result message
                    if let message = resultMessage {
                        HStack(spacing: SSSpacing.sm) {
                            Image(systemName: isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(isSuccess ? .green : .red)
                            Text(message)
                                .font(SSFont.chipLabel)
                                .foregroundStyle(isSuccess ? .green : .red)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // Join button
                    Button {
                        joinProject()
                    } label: {
                        if isJoining {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(L10n.projectJoin)
                                .font(SSFont.heading3)
                        }

                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SSSpacing.lgXl)
                    .background(
                        RoundedRectangle(cornerRadius: SSRadius.medium, style: .continuous)
                            .fill(SSColor.brand.opacity(code.count == 8 ? 1 : SSOpacity.disabled))
                    )
                    .padding(.horizontal, 40)
                    .disabled(code.count != 8 || isJoining)

                    Spacer()
                }
            }
            .sheet(isPresented: $showScanner) {
                QRScannerView { payload in
                    if let parsed = DeepLinkRouter.parseProjectCode(from: payload) {
                        code = parsed
                        showScanner = false
                        // Auto-submit after a short beat so the user sees the
                        // code populate before the join request fires.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            joinProject()
                        }
                    } else {
                        HapticEngine.shared.error()
                        showScanner = false
                        withAnimation {
                            isSuccess = false
                            resultMessage = L10n.projectInvalidQR
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .dismissKeyboardToolbar()
        }
    }

    private func joinProject() {
        isJoining = true
        resultMessage = nil
        Task {
            let result = await viewModel.joinByCode(code)
            isJoining = false
            withAnimation(.easeOut(duration: 0.2)) {
                switch result {
                case .success:
                    isSuccess = true
                    resultMessage = L10n.projectJoinSuccess
                    HapticEngine.shared.success()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        dismiss()
                    }
                case .notFound:
                    isSuccess = false
                    resultMessage = L10n.projectNotFound
                    HapticEngine.shared.error()
                case .alreadyMember:
                    isSuccess = false
                    resultMessage = L10n.projectAlreadyMember
                    HapticEngine.shared.warning()
                case .error:
                    isSuccess = false
                    resultMessage = "Error"
                    HapticEngine.shared.error()
                }
            }
        }
    }
}

#Preview {
    JoinProjectView(viewModel: TeamProjectViewModel())
}
