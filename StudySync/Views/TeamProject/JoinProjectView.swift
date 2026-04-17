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
                VStack(spacing: 24) {
                    Spacer().frame(height: 20)

                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 48))
                        .foregroundStyle(Color(hex: "#5B7FFF"))

                    Text(L10n.projectJoin)
                        .font(.system(size: 22, weight: .bold))

                    Text(L10n.projectEnterCode)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)

                    // Scan QR button
                    Button {
                        HapticEngine.shared.lightImpact()
                        showScanner = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "qrcode.viewfinder")
                                .font(.system(size: 16, weight: .semibold))
                            Text(L10n.projectScanQR)
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(Color(hex: "#5B7FFF"))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            Capsule().fill(Color(hex: "#5B7FFF").opacity(0.12))
                        )
                    }

                    // Code field
                    TextField("ABCD1234", text: $code)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(.secondarySystemGroupedBackground))
                        )
                        .padding(.horizontal, 40)
                        .onChange(of: code) { _, newValue in
                            code = String(newValue.prefix(8)).uppercased()
                        }

                    // Result message
                    if let message = resultMessage {
                        HStack(spacing: 6) {
                            Image(systemName: isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(isSuccess ? .green : .red)
                            Text(message)
                                .font(.system(size: 14, weight: .medium))
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
                                .font(.system(size: 17, weight: .semibold))
                        }

                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(hex: "#5B7FFF").opacity(code.count == 8 ? 1 : 0.4))
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
