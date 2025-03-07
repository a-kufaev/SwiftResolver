//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftResolver open source project
//
// Copyright (c) 2025 Artem Kufaev
// Licensed under MIT License
//
// See https://github.com/a-kufaev/SwiftResolver/blob/main/LICENSE for license information
//
//===----------------------------------------------------------------------===//

/// Identifier (name) of a dependency registered in `Resolver`.
///
/// Allows registering multiple implementations of the same dependency, distinguishing them by name.
/// Supports string literals and is used in the `register(...)` and `resolve(...)` APIs.
///
/// ## Example
/// ```swift
/// Resolver.register(name: ResolverName("mock")) { MyMockService() }
/// Resolver.resolve(MyService.self, name: "mock")
/// ```
///
/// ## Recommended
/// Instead of raw strings, prefer `static let` values declared via `extension ResolverName`:
///
/// ```swift
/// extension ResolverName {
///     static let mock = ResolverName("mock")
///     static let live = ResolverName("live")
/// }
///
/// Resolver.register(name: .mock) { MyMockService() }
/// Resolver.resolve(MyService.self, name: .mock)
/// ```
public struct ResolverName: ExpressibleByStringLiteral, Hashable, Equatable, Sendable {

    /// The string representation of the name.
    public let rawValue: String

    /// Creates a dependency name from a string.
    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    /// Enables the use of string literals.
    public init(stringLiteral: String) {
        rawValue = stringLiteral
    }

    public static func == (lhs: ResolverName, rhs: ResolverName) -> Bool {
        lhs.rawValue == rhs.rawValue
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(rawValue)
    }
}
