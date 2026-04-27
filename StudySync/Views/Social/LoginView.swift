import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @State private var isLogin = true
    @AppStorage("lastLoginEmail") private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var showResetSheet = false
    @State private var addBirthday = false
    @State private var birthdayDate = Calendar.current.date(byAdding: .year, value: -20, to: Date()) ?? Date()

    private var auth: AuthService { .shared }

    var body: some View {
        VStack(spacing: SSSpacing.xxxl) {
            Spacer()

            // Header
            VStack(spacing: SSSpacing.md) {
                Image(systemName: "person.2.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(SSColor.brand.gradient)

                Text(L10n.socialWelcome)
                    .font(.system(size: 22, weight: .bold))

                Text(L10n.socialWelcomeDesc)
                    .font(SSFont.secondary)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()

            // Apple Sign In
            SignInWithAppleButton(.signIn) { request in
                let hashedNonce = auth.prepareAppleSignIn()
                request.requestedScopes = [.fullName, .email]
                request.nonce = hashedNonce
            } onCompletion: { result in
                Task { await auth.handleAppleSignIn(result: result) }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .cornerRadius(SSRadius.fieldCard)
            .padding(.horizontal, SSSpacing.xxxl)

            // Divider
            HStack {
                Rectangle().fill(Color(.separator)).frame(height: 1)
                Text(L10n.socialOrEmail)
                    .font(SSFont.caption)
                    .foregroundStyle(.secondary)
                Rectangle().fill(Color(.separator)).frame(height: 1)
            }
            .padding(.horizontal, SSSpacing.xxxl)

            // Email form
            VStack(spacing: SSSpacing.lg) {
                if !isLogin {
                    TextField(L10n.socialDisplayName, text: $displayName)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.name)

                    // Birthday (optional)
                    HStack(spacing: SSSpacing.mdLg) {
                        Image(systemName: "birthday.cake")
                            .foregroundStyle(SSColor.brand)
                            .frame(width: 20)
                        if addBirthday {
                            DatePicker("", selection: $birthdayDate, in: ...Date(), displayedComponents: .date)
                                .labelsHidden()
                            Spacer()
                            Button {
                                withAnimation(.spring(duration: 0.25)) { addBirthday = false }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Button {
                                withAnimation(.spring(duration: 0.25)) { addBirthday = true }
                            } label: {
                                Text(L10n.birthdayAddOptional)
                                    .font(SSFont.secondary)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                    .padding(.horizontal, SSSpacing.md)
                    .padding(.vertical, SSSpacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(.systemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Color(.systemGray4), lineWidth: 0.5)
                            )
                    )
                }

                TextField(L10n.socialEmail, text: $email)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)

                SecureField(L10n.socialPassword, text: $password)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(isLogin ? .password : .newPassword)

                if isLogin {
                    HStack {
                        Spacer()
                        Button {
                            HapticEngine.shared.lightImpact()
                            showResetSheet = true
                        } label: {
                            Text(L10n.authForgotPassword)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(SSColor.brand)
                        }
                    }
                }
            }
            .padding(.horizontal, SSSpacing.xxxl)

            // Submit button
            Button {
                Task {
                    if isLogin {
                        await auth.signInWithEmail(email: email, password: password)
                    } else {
                        await auth.signUpWithEmail(email: email, password: password, displayName: displayName, birthday: addBirthday ? birthdayDate : nil)
                    }
                }
            } label: {
                if auth.isLoading {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SSSpacing.lgXl)
                } else {
                    Text(isLogin ? L10n.socialLogin : L10n.socialRegister)
                        .font(SSFont.bodySemibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SSSpacing.lgXl)
                }
            }
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: SSRadius.fieldCard, style: .continuous)
                    .fill(SSColor.brand.gradient)
            )
            .padding(.horizontal, SSSpacing.xxxl)
            .disabled(email.isEmpty || password.isEmpty || (!isLogin && displayName.trimmingCharacters(in: .whitespaces).isEmpty) || auth.isLoading)

            // Toggle login/register
            Button {
                withAnimation(.spring(duration: 0.3)) {
                    isLogin.toggle()
                }
            } label: {
                Text(isLogin ? L10n.socialNoAccount : L10n.socialHasAccount)
                    .font(SSFont.secondary)
                    .foregroundStyle(SSColor.brand)
            }

            // Error
            if let error = auth.errorMessage {
                Text(error)
                    .font(SSFont.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SSSpacing.xxxl)
            }

            Spacer()
        }
        .sheet(isPresented: $showResetSheet) {
            PasswordResetView(initialEmail: email)
                .presentationDetents([.medium])
        }
    }
}

// MARK: - Password Reset Sheet

private struct PasswordResetView: View {
    let initialEmail: String
    @Environment(\.dismiss) private var dismiss
    private var auth: AuthService { .shared }

    @State private var email: String = ""
    @State private var didSend = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                VStack(spacing: SSSpacing.xxl) {
                    Spacer().frame(height: 12)

                    Image(systemName: "key.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(SSColor.brand)

                    Text(L10n.authResetTitle)
                        .font(SSFont.heading2)

                    Text(L10n.authResetSubtitle)
                        .font(SSFont.secondary)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    if didSend {
                        VStack(spacing: SSSpacing.md) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(.green)
                            Text(L10n.authResetSent)
                                .font(SSFont.chipLabel)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .padding(.top, SSSpacing.md)
                    } else {
                        TextField(L10n.socialEmail, text: $email)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .padding(.horizontal, SSSpacing.xxxl)

                        if let errorText = errorText {
                            Text(errorText)
                                .font(SSFont.footnote)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, SSSpacing.xxxl)
                        }

                        Button {
                            Task { await send() }
                        } label: {
                            if auth.isLoading {
                                ProgressView().tint(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, SSSpacing.lgXl)
                            } else {
                                Text(L10n.authResetSendButton)
                                    .font(SSFont.bodySemibold)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, SSSpacing.lgXl)
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: SSRadius.fieldCard, style: .continuous)
                                .fill(SSColor.brand.opacity(email.isEmpty ? SSOpacity.disabled : 1))
                        )
                        .padding(.horizontal, SSSpacing.xxxl)
                        .disabled(email.isEmpty || auth.isLoading)
                    }

                    Spacer()
                }
                .padding(.top, SSSpacing.md)
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
            .onAppear {
                if email.isEmpty { email = initialEmail }
            }
        }
    }

    private func send() async {
        errorText = nil
        let ok = await auth.sendPasswordReset(email: email)
        if ok {
            HapticEngine.shared.success()
            withAnimation { didSend = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { dismiss() }
        } else {
            HapticEngine.shared.error()
            errorText = auth.errorMessage
        }
    }
}

#Preview {
    LoginView()
}
