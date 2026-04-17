import SwiftUI

/// Identity roles displayed as tags on user profiles.
/// Stored as `roles: [String]` in Firestore UserProfile.
enum UserRole: String, CaseIterable, Identifiable {
    case developer   = "developer"
    case pro         = "pro"
    case tester      = "tester"
    case earlyBird   = "early_bird"
    case contributor = "contributor"

    var id: String { rawValue }

    /// Display priority — lower number = shown first.
    var priority: Int {
        switch self {
        case .developer:   return 0
        case .pro:         return 1
        case .tester:      return 2
        case .earlyBird:   return 3
        case .contributor: return 4
        }
    }

    var label: String {
        switch self {
        case .developer:   return L10n.roleDeveloper
        case .pro:         return L10n.rolePro
        case .tester:      return L10n.roleTester
        case .earlyBird:   return L10n.roleEarlyBird
        case .contributor: return L10n.roleContributor
        }
    }

    var icon: String {
        switch self {
        case .developer:   return "hammer.fill"
        case .pro:         return "star.fill"
        case .tester:      return "flask.fill"
        case .earlyBird:   return "bird.fill"
        case .contributor: return "lightbulb.fill"
        }
    }

    var color: Color {
        switch self {
        case .developer:   return Color(hex: "#7C3AED")
        case .pro:         return Color(hex: "#F59E0B")
        case .tester:      return Color(hex: "#10B981")
        case .earlyBird:   return Color(hex: "#38BDF8")
        case .contributor: return Color(hex: "#14B8A6")
        }
    }

    /// Parse an array of role strings into sorted UserRole values.
    static func parse(_ rawRoles: [String]) -> [UserRole] {
        rawRoles
            .compactMap { UserRole(rawValue: $0) }
            .sorted { $0.priority < $1.priority }
    }
}

// MARK: - Role Tag View

/// A compact capsule tag showing a role icon + label.
struct RoleTagView: View {
    let role: UserRole

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: role.icon)
                .font(.system(size: 9, weight: .semibold))
            Text(role.label)
                .font(.system(size: 10, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(role.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(role.color.opacity(0.12))
        )
        .overlay(
            Capsule()
                .strokeBorder(role.color.opacity(0.25), lineWidth: 0.5)
        )
        .fixedSize(horizontal: true, vertical: false)
    }
}

/// A horizontal flow of role tags for a user.
struct RoleTagsView: View {
    let roles: [String]

    var body: some View {
        let parsed = UserRole.parse(roles)
        if !parsed.isEmpty {
            HStack(spacing: 6) {
                ForEach(parsed) { role in
                    RoleTagView(role: role)
                }
            }
        }
    }
}
