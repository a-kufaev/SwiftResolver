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

/// Protocol implemented to register dependencies in `Resolver`.
///
/// The `registerAll()` method is called automatically on the first `resolve(...)`,
/// provided that `Resolver.root` conforms to this protocol.
///
/// ## Example
/// Extend `Resolver` and implement `registerAll()`, registering all of the
/// application's dependencies inside it:
///
/// ```swift
/// extension Resolver: @retroactive ResolverRegistering {
///     public static func registerAll() {
///         register { MyService() }
///         register { MyRepository() }
///     }
/// }
/// ```
///
/// > The method is invoked automatically on the first dependency resolution `Resolver.resolve(...)`.
public protocol ResolverRegistering {

    static func registerAll()
}
