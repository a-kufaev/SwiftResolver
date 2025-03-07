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

    /// The `Cache` scope keeps dependencies in memory until the cache is manually reset.
    ///
    /// Behaves like a `singleton`, but allows the state to be reset explicitly — convenient for tests,
    /// re-initialization, or dynamic lifetime management.
    ///
    /// Objects in this scope are created **once**, cached, and returned on subsequent `resolve(...)` calls.
    /// Calling `reset()` clears the cache, and the next `resolve` creates a new instance.
    ///
    /// ## Example
    /// ```swift
    /// Resolver.register { MyService() }
    ///     .scope(.cached)
    ///
    /// ResolverScope.cached.reset() // Reset the cache manually
    /// ```
    public final class Cache: ResolverScope, @unchecked Sendable {

        // MARK: - Internal Storage

        private var cachedServices = [ResolutionKey: Any](minimumCapacity: 32)

        // MARK: - Resolution

        /// Resolves a dependency by returning a previously created instance from the cache,
        /// or creates and caches a new one if it is absent.
        override func resolve<P, Service>(
            entity: ResolutionEntry<P, Service>,
            resolver: Resolver,
            parameters: P
        ) -> Service? {
            if let service = cachedServices[entity.key] as? Service {
                return service
            }

            let service = entity.instantiate(resolver: resolver, parameters: parameters)
            if let service {
                cachedServices[entity.key] = service
            }

            return service
        }

        /// Resets all cached dependencies in this scope.
        override public func reset() {
            cachedServices.removeAll()
        }
    }
}
