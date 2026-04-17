import SwiftUI

// ╔══════════════════════════════════════════════════════════════════╗
// ║  ScrollView 深色背景 + 左右 Margin 问题修复方案                      ║
// ║                                                                  ║
// ║  问题: iOS 18 中 ScrollView 在 NavigationStack + TabView 内       ║
// ║       使用 .background(Color(...)) 时，背景色不会延伸到屏幕边缘，     ║
// ║       导致左右出现 margin/条纹。                                    ║
// ║                                                                  ║
// ║  ❌ 无效方案:                                                     ║
// ║    .background(Color(.systemGroupedBackground))                  ║
// ║    .scrollContentBackground(.hidden) // 只对 List/Form 有效       ║
// ║                                                                  ║
// ║  ❌ 部分无效方案:                                                  ║
// ║    .background { Color(...).ignoresSafeArea() }                  ║
// ║    // 如果 ScrollView 上链有 .overlay + .animation 仍然会失效      ║
// ║                                                                  ║
// ║  ✅ 正确方案: ZStack 包裹                                         ║
// ║    NavigationStack {                                             ║
// ║        ZStack {                                                  ║
// ║            Color(.systemGroupedBackground)                       ║
// ║                .ignoresSafeArea()                                ║
// ║            ScrollView {                                          ║
// ║                // content                                        ║
// ║            }                                                     ║
// ║        }                                                         ║
// ║        .navigationTitle(...)                                     ║
// ║    }                                                             ║
// ║                                                                  ║
// ║  注意: .overlay 和 .animation 不要链在 ScrollView 上，             ║
// ║        应放在 NavigationStack 外层，避免干扰布局。                   ║
// ║                                                                  ║
// ║  参考: StudyGoalView.swift (首次修复)                              ║
// ╚══════════════════════════════════════════════════════════════════╝

// 便捷 ViewModifier: 用于 ScrollView 页面的标准背景处理
struct ScrollViewBackground: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            content
        }
    }
}

extension View {
    /// 给 ScrollView 添加全屏背景色，解决 iOS 18 margin 问题。
    /// 用法: ScrollView { ... }.scrollViewBackground()
    func scrollViewBackground() -> some View {
        modifier(ScrollViewBackground())
    }
}
