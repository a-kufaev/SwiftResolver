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

/// Configuration options for a dependency registered in `Resolver`.
///
/// Returned from the `register(...)` method and allows you to:
/// - specify the scope (`scope`);
/// - register an interface (`implements`);
/// - apply a decorator (`decorator(...)`) — additional initialization after the object is created.
///
/// ## Example
/// ```swift
/// Resolver.register { MyService() }
///     .scope(.application)
///     .implements(MyServiceProtocol.self)
///     .decorator { resolver, service, _ in
///         service.configure()
///     }
/// ```
public struct ResolverRegistrationOptions<P: Sendable, Service> {

    // MARK: - Internal Entry

    let entry: ResolutionEntry<P, Service>

    // MARK: - Interface Binding

    /// Registers the dependency as the implementation of an additional interface (protocol).
    ///
    /// This allows the service to be resolved not only by its concrete type, but also by the interface.
    ///
    /// - Parameters:
    ///   - type: The interface (protocol) type that the service implements.
    ///   - name: An optional name for the interface registration.
    ///
    /// - Returns: The same `ResolverRegistrationOptions` object for further configuration.
    ///
    /// ## Example
    /// ```swift
    /// Resolver.register { MyService() }
    ///     .implements(MyProtocol.self)
    /// ```
    @discardableResult
    public func implements<Protocol: Sendable>(
        _ type: Protocol.Type,
        name: ResolverName? = nil
    ) -> ResolverRegistrationOptions<P, Service> {
        entry.registry.register(type.self, name: name, in: entry.scope) { (resolver, parameters: P) in
            resolver.resolve(Service.self, parameters: parameters) as? Protocol
        }
        return self
    }

    // MARK: - Scope

    /// Sets the dependency's scope (e.g. `.application`, `.cached`, `.graph`).
    ///
    /// The scope affects the lifecycle of the created object.
    ///
    /// - Parameter scope: The scope (`ResolverScope`) in which the object should live.
    ///
    /// - Returns: The same `ResolverRegistrationOptions` object for further configuration.
    ///
    /// ## Example
    /// ```swift
    /// Resolver.register { MyService() }
    ///     .scope(.application)
    /// ```
    @discardableResult
    public func scope(_ scope: ResolverScope) -> ResolverRegistrationOptions<P, Service> {
        entry.scope = scope
        return self
    }

    /// Applies a decorator invoked after the dependency is created.
    ///
    /// Useful for additional configuration, manual dependency injection, logging, etc.
    ///
    /// - Parameter block: A closure invoked after the object is created.
    ///
    /// - Returns: The same `ResolverRegistrationOptions` object for further configuration.
    ///
    /// ## Example
    /// ```swift
    /// Resolver.register { MyService() }
    ///     .decorator { resolver, service, _ in
    ///         service.configure()
    ///     }
    /// ```
    ///
    /// > Note: If `Service` is a struct, mutations inside `decorator` will not persist.
    /// > For the effect to apply, use reference types (`class`).
    @discardableResult
    public func decorator(
        _ block: @escaping @Sendable (Service, P) -> Void
    ) -> ResolverRegistrationOptions<P, Service> {
        entry.decorate { _, service, parameters in block(service, parameters) }
        return self
    }

    /// Applies a decorator invoked after the dependency is created.
    ///
    /// Useful for additional configuration, manual dependency injection, logging, etc.
    ///
    /// - Parameter block: A closure invoked after the object is created.
    ///
    /// - Returns: The same `ResolverRegistrationOptions` object for further configuration.
    ///
    /// ## Example
    /// ```swift
    /// Resolver.register { MyService() }
    ///     .decorator { resolver, service, _ in
    ///         service.configure()
    ///     }
    /// ```
    ///
    /// > Note: If `Service` is a struct, mutations inside `decorator` will not persist.
    /// > For the effect to apply, use reference types (`class`).
    @discardableResult
    public func decorator(
        _ block: @escaping @Sendable (Resolver, Service, P) -> Void
    ) -> ResolverRegistrationOptions<P, Service> {
        entry.decorate(block)
        return self
    }
}
