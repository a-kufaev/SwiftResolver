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

extension ResolverScope {

    /// The `Unique` scope creates a new dependency instance **every time** it is resolved.
    ///
    /// This is the simplest and purest scope: it neither caches nor retains the object, always calling the factory directly.
    ///
    /// Useful when dependencies are lightweight, should not be shared, or must have a clear lifecycle.
    ///
    /// Implemented via the default behavior in `ResolverScope`.
    ///
    /// ## Example
    /// ```swift
    /// Resolver.register { MyService() }
    ///     .scope(.unique)
    ///
    /// let a = resolver.resolve(MyService.self)
    /// let b = resolver.resolve(MyService.self)
    /// assert(a !== b) // A new instance every time
    /// ```
    public typealias Unique = ResolverScope
}
