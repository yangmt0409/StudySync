import Foundation

/// Debug-only logging. Compiles to a no-op in Release builds.
@inline(__always)
func debugPrint(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    #if DEBUG
    let output = items.map { String(describing: $0) }.joined(separator: separator)
    Swift.print(output, terminator: terminator)
    #endif
}
