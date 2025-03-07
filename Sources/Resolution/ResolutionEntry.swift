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

// MARK: - Aliases

/// The type of a factory that creates a dependency instance.
typealias FactoryType<P, Service> = @Sendable (Resolver, P) -> Service?

/// The type of a decorator invoked after a dependency is created.
typealias FactoryDecorator<P, Service> = @Sendable (Resolver, Service, P) -> Void

/// A unit of dependency resolution inside the `Resolver` container.
///
/// Holds all the information required to create and manage a dependency instance:
/// - the registration key;
/// - the scope that controls the lifecycle;
/// - the factory that creates the object;
/// - a reference to the owning container.
///
/// `ResolutionEntry` is created during registration and can later be modified
/// via `ResolverRegistrationOptions` (e.g. by adding `.scope(...)`, `.decorator { ... }`, etc.).
final class ResolutionEntry<P, Service> {

    // MARK: - Identity

    /// The unique key under which the dependency is resolved.
    let key: ResolutionKey

    // MARK: - Owner

    /// The registry that owns this entry.
    unowned let registry: ResolutionRegistry

    // MARK: - Factory & Scope

    /// The primary factory that creates a dependency instance.
    private let factory: FactoryType<P, Service>

    /// Additional logic applied to an already-created object.
    private var decorator: FactoryDecorator<P, Service>?

    /// The dependency's scope.
    var scope: ResolverScope

    // MARK: - Init

    init(
        registry: ResolutionRegistry,
        key: ResolutionKey,
        scope: ResolverScope,
        factory: @escaping @Sendable FactoryType<P, Service>
    ) {
        self.registry = registry
        self.key = key
        self.scope = scope
        self.factory = factory
    }

    // MARK: - Resolution

    /// Resolves the dependency, respecting its scope.
    ///
    /// Called by the container during `resolve(...)`.
    func resolve(
        resolver: Resolver,
        parameters: P
    ) -> Service? {
        scope.resolve(entity: self, resolver: resolver, parameters: parameters)
    }

    /// Creates a new dependency instance via the `factory`.
    ///
    /// If a `decorator` is set, it is invoked after the object is created.
    func instantiate(
        resolver: Resolver,
        parameters: P
    ) -> Service? {
        guard let service = factory(resolver, parameters) else {
            return nil
        }

        decorator?(resolver, service, parameters)

        return service
    }

    // MARK: - Configuration

    /// Adds (or chains) a decorator invoked after the object is created.
    ///
    /// Can be called multiple times — decorators are applied sequentially.
    func decorate(
        _ block: @escaping FactoryDecorator<P, Service>
    ) {
        if let existing = decorator {
            decorator = { resolver, service, params in
                existing(resolver, service, params)
                block(resolver, service, params)
            }
        } else {
            decorator = block
        }
    }
}
