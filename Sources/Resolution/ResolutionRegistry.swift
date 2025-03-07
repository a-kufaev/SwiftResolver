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

import Foundation

/// The internal container manager that holds all registered dependencies and their resolutions.
///
/// Manages dependency registration, resolution with respect to the hierarchy, and scope.
/// Used inside `Resolver` and not intended for direct interaction.
///
/// All accesses are protected by the global recursive lock.
///
/// > Note: It is not thread-safe on its own without `globalRecursiveLock`.
final class ResolutionRegistry: @unchecked Sendable {

    // MARK: - Hierarchy

    private var childContainers: [ResolutionRegistry] = []

    // MARK: - Registrations

    private var registrations = [ResolutionKey: Any]()

    /// Adds a child container to the current one.
    ///
    /// Used to build container hierarchies with scopes.
    ///
    /// - Parameter child: The container to be added as a child.
    func addChild(_ child: ResolutionRegistry) {
        globalRecursiveLock.lock()
        defer { globalRecursiveLock.unlock() }

        childContainers.append(child)
    }

    /// Registers a new dependency with the given `scope` and factory.
    ///
    /// - Parameters:
    ///   - type: The dependency type (optional).
    ///   - name: An optional name.
    ///   - scope: The scope (e.g. `.application`).
    ///   - factory: The factory that creates the dependency instance.
    ///
    /// - Returns: A `ResolutionEntry` associated with the registration.
    @discardableResult
    func register<P: Sendable, Service: Sendable>(
        _ type: Service.Type = Service.self,
        name: ResolverName? = nil,
        in scope: ResolverScope,
        factory: @escaping @Sendable @isolated(any) (_ resolver: Resolver, P) -> Service?
    ) -> ResolutionEntry<P, Service> where Resolver: Sendable {
        globalRecursiveLock.lock()
        defer { globalRecursiveLock.unlock() }

        let key = ResolutionKey(type: type, name: name)
        let registration = ResolutionEntry(
            registry: self,
            key: key,
            scope: scope,
            factory: factory
        )
        registrations[key] = registration
        return registration
    }

    /// Resolves a dependency registered by type and name.
    /// Triggers a `fatalError` if there is no registration.
    ///
    /// - Parameters:
    ///   - type: The dependency type.
    ///   - name: An optional registration name.
    ///   - parameters: Arguments for the factory.
    ///   - resolver: The referencing container.
    ///
    /// - Returns: The resolved `Service` instance.
    func resolve<P, Service>(
        _ type: Service.Type = Service.self,
        name: ResolverName? = nil,
        parameters: P,
        resolver: Resolver
    ) -> Service {
        globalRecursiveLock.lock()
        defer { globalRecursiveLock.unlock() }

        RegistrationGuard.ensureRegistration()

        guard let registration: ResolutionEntry<P, Service> = lookup(type, name: name),
              let service = registration.resolve(resolver: resolver, parameters: parameters)
        else {
            let nameInfo = name.map { " (name: \($0.rawValue))" } ?? ""
            fatalError(
                """
                Resolver: \(Service.self)\(nameInfo) was not resolved.
                Make sure the dependency was registered before calling resolve().
                """
            )
        }
        return service
    }

    /// Attempts to resolve a dependency registered by type and name.
    /// Unlike `resolve`, it does not trigger a `fatalError` but returns `nil`
    /// if the dependency is not found or could not be created.
    ///
    /// - Parameters:
    ///   - type: The dependency type.
    ///   - name: An optional registration name.
    ///   - parameters: Arguments for the factory.
    ///   - resolver: The referencing container.
    ///
    /// - Returns: A `Service` instance, or `nil` if there was no registration for the given type/name.
    func resolveOptional<P, Service>(
        _ type: Service.Type = Service.self,
        name: ResolverName? = nil,
        parameters: P,
        resolver: Resolver
    ) -> Service? {
        globalRecursiveLock.lock()
        defer { globalRecursiveLock.unlock() }

        RegistrationGuard.ensureRegistration()

        guard let entry: ResolutionEntry<P, Service> = lookup(type, name: name) else {
            return nil
        }
        return entry.resolve(resolver: resolver, parameters: parameters)
    }
}

// MARK: - Lookup

extension ResolutionRegistry {

    /// Looks up a `ResolutionEntry` first in the current container, then recursively in child containers.
    ///
    /// - Parameters:
    ///   - type: The dependency type.
    ///   - name: An optional registration name.
    ///
    /// - Returns: The `ResolutionEntry` if found.
    private func lookup<P, Service>(
        _ type: Service.Type,
        name: ResolverName?
    ) -> ResolutionEntry<P, Service>? {
        let key = ResolutionKey(type: type, name: name)

        if let registration = registrations[key] as? ResolutionEntry<P, Service> {
            return registration
        }

        for child in childContainers {
            if let registration: ResolutionEntry<P, Service> = child.lookup(type, name: name) {
                return registration
            }
        }

        return nil
    }
}
