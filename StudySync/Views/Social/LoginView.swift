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
        VStack(spacing: 24) {
            Spacer()

            // Header
            VStack(spacing: 8) {
                Image(systemName: "person.2.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color(hex: "#5B7FFF").gradient)

                Text(L10n.socialWelcome)
                    .font(.system(size: 22, weight: .bold))

                Text(L10n.socialWelcomeDesc)
                    .font(.system(size: 14))
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
            .cornerRadius(12)
            .padding(.horizontal, 24)

            // Divider
            HStack {
                Rectangle().fill(Color(.separator)).frame(height: 1)
                Text(L10n.socialOrEmail)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Rectangle().fill(Color(.separator)).frame(height: 1)
            }
            .padding(.horizontal, 24)

            // Email form
            VStack(spacing: 12) {
                if !isLogin {
                    TextField(L10n.socialDisplayName, text: $displayName)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.name)

                    // Birthday (optional)
                    HStack(spacing: 10) {
                        Image(systemName: "birthday.cake")
                            .foregroundStyle(Color(hex: "#5B7FFF"))
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
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
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
                                .foregroundStyle(Color(hex: "#5B7FFF"))
                        }
                    }
                }
            }
            .padding(.horizontal, 24)

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
                        .padding(.vertical, 14)
                } else {
                    Text(isLogin ? L10n.socialLogin : L10n.socialRegister)
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
            }
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(hex: "#5B7FFF").gradient)
            )
            .padding(.horizontal, 24)
            .disabled(email.isEmpty || password.isEmpty || (!isLogin && displayName.trimmingCharacters(in: .whitespaces).isEmpty) || auth.isLoading)

            // Toggle login/register
            Button {
                withAnimation(.spring(duration: 0.3)) {
                    isLogin.toggle()
                }
            } label: {
                Text(isLogin ? L10n.socialNoAccount : L10n.socialHasAccount)
                    .font(.system(size: 14))
                    .foregroundStyle(Color(hex: "#5B7FFF"))
            }

            // Error
            if let error = auth.errorMessage {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
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
                VStack(spacing: 20) {
                    Spacer().frame(height: 12)

                    Image(systemName: "key.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Color(hex: "#5B7FFF"))

                    Text(L10n.authResetTitle)
                        .font(.system(size: 20, weight: .bold))

                    Text(L10n.authResetSubtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    if didSend {
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(.green)
                            Text(L10n.authResetSent)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .padding(.top, 8)
                    } else {
                        TextField(L10n.socialEmail, text: $email)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .padding(.horizontal, 24)

                        if let errorText = errorText {
                            Text(errorText)
                                .font(.system(size: 12))
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }

                        Button {
                            Task { await send() }
                        } label: {
                            if auth.isLoading {
                                ProgressView().tint(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                            } else {
                                Text(L10n.authResetSendButton)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(hex: "#5B7FFF").opacity(email.isEmpty ? 0.4 : 1))
                        )
                        .padding(.horizontal, 24)
                        .disabled(email.isEmpty || auth.isLoading)
                    }

                    Spacer()
                }
                .padding(.top, 8)
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
