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

/// Manager of scopes in the `Resolver` container.
///
/// Scopes are used to define the **lifetime of dependencies**, controlling
/// when and for how long the returned instance should exist.
///
/// By default `Resolver` uses the `.graph` scope, which creates an object once
/// within the current dependency resolution cycle.
///
/// > All scopes are `@unchecked Sendable` because their public state
/// is synchronized via global locks.
///
/// Scopes can be applied when registering dependencies:
/// ```swift
/// Resolver.register { MyService() }
///     .scope(.application)
/// ```
public class ResolverScope: @unchecked Sendable {

    /// The `application` scope keeps a dependency in memory for the entire lifetime of the application.
    ///
    /// This behaves like a `singleton`: the object is created once and reused
    /// on all subsequent `resolve(...)` calls.
    ///
    /// Suitable for global services: loggers, managers, singletons, etc.
    public static let application = Cache()

    /// The `cached` scope keeps a dependency in memory until the cache is explicitly reset.
    ///
    /// The object is created on the first `resolve(...)` call and retained until `reset()` is called.
    ///
    /// Convenient for testing, when dependencies need to be re-initialized between cases,
    /// or when cached objects can be reset manually.
    ///
    /// > Behaves like `application`, but with the ability to be reloaded.
    public static let cached = Cache()

    /// The `graph` scope creates a dependency once for the entire current resolution cycle.
    ///
    /// This is the default behavior. Objects are created on the first `resolve(...)` and reused
    /// across nested resolutions (e.g. `A → B → C`). Once the chain finishes, the graph is cleared.
    ///
    /// It preserves reference identity within a single operation without retaining the object any longer.
    ///
    /// > Only class types are cached within the graph. Structs and values are not retained.
    public static let graph = Graph()

    /// The `shared` scope stores dependencies using weak references (`weak`).
    ///
    /// The object stays in memory as long as external strong references to it exist. If all references
    /// are removed, the object is deallocated and will be created again on the next `resolve(...)`.
    ///
    /// Useful for temporary, cacheable objects that should not be retained unnecessarily.
    ///
    /// > A flexible alternative to `cached` that helps save memory.
    public static let shared = Share()

    /// The `unique` scope creates a new dependency instance **every time** it is resolved.
    ///
    /// Nothing is cached. The factory is invoked on every `resolve(...)`.
    ///
    /// Suitable for short-lived objects, value types, or whenever a "fresh" copy is always required.
    public static let unique = Unique()

    init() {}

    /// The base resolution strategy: creates a new object every time.
    /// Used, for example, by the `.unique` scope.
    ///
    /// - Parameters:
    ///   - registration: The registered dependency factory.
    ///   - resolver: The container in which resolution happens.
    ///   - parameters: Parameters passed to the factory.
    /// - Returns: The resolved instance.
    func resolve<P, Service>(
        entity: ResolutionEntry<P, Service>,
        resolver: Resolver,
        parameters: P
    ) -> Service? {
        entity.instantiate(resolver: resolver, parameters: parameters)
    }

    /// Cache reset method. Does nothing by default.
    /// Overridden by caching scopes.
    public func reset() {
        // nothing by default
    }
}
