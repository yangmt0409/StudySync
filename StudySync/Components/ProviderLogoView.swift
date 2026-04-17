import SwiftUI

/// Displays an AI provider's official logo on a colored circle background.
/// Uses asset catalog SVG logos (template rendering).
struct ProviderLogoView: View {
    let provider: AIProvider
    var size: CGFloat = 40
    var iconSize: CGFloat = 18

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: provider.colorHex).gradient)
                .frame(width: size, height: size)

            Image(provider.logoAsset)
                .resizable()
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)
                .foregroundStyle(.white)
        }
    }
}

/// Displays the OpenAI Codex terminal-style logo on a dark circle.
struct CodexLogoView: View {
    var size: CGFloat = 40
    var iconSize: CGFloat = 18

    /// Codex brand color (dark charcoal)
    static let colorHex = "#1A1A2E"

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: Self.colorHex).gradient)
                .frame(width: size, height: size)

            Image("logo_codex")
                .resizable()
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)
                .foregroundStyle(.white)
        }
    }
}

#Preview {
    HStack(spacing: 16) {
        VStack(spacing: 8) {
            ProviderLogoView(provider: .claude, size: 56, iconSize: 26)
            Text("Claude").font(.caption)
        }
        VStack(spacing: 8) {
            ProviderLogoView(provider: .openai, size: 56, iconSize: 28)
            Text("ChatGPT").font(.caption)
        }
        VStack(spacing: 8) {
            CodexLogoView(size: 56, iconSize: 26)
            Text("Codex").font(.caption)
        }
        VStack(spacing: 8) {
            ProviderLogoView(provider: .google, size: 56, iconSize: 26)
            Text("Gemini").font(.caption)
        }
    }
    .padding()
}
