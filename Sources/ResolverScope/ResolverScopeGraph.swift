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

    /// The `Graph` scope resolves a dependency **once** within the current resolution cycle.
    ///
    /// This is the default scope in `Resolver`. It provides an optimal balance between performance
    /// and control over the lifetime of dependencies.
    ///
    /// `Graph` behaves like a cache, but only within a single nested `resolve(...)` call.
    /// This means that if resolving one dependency requires resolving others (e.g. nested services),
    /// each of them is created **once** for the whole cycle and then cleared.
    ///
    /// ## Example
    /// ```swift
    /// Resolver.register { ServiceImpl() }
    ///     .scope(.graph)
    ///
    /// let vm = resolver.resolve(MyViewModel.self)
    /// // All dependencies in the graph are created only once
    /// ```
    ///
    /// Suitable for dependency graphs where reference identity of objects must be preserved
    /// for the duration of resolution, but no longer.
    public final class Graph: ResolverScope, @unchecked Sendable {

        // MARK: - Internal Storage

        private var graph = [ResolutionKey: Any?](minimumCapacity: 32)
        private var resolutionDepth: Int = 0

        // MARK: - Resolution

        /// Resolves a dependency and retains it until the current `resolve` cycle finishes.
        ///
        /// - If the dependency has already been resolved within the current graph, it is returned from the cache.
        /// - If this is the first `resolve` call, the graph is cleared once it completes.
        /// - Only class types are cached across levels — value types are not retained.
        override func resolve<P, Service>(
            entity: ResolutionEntry<P, Service>,
            resolver: Resolver,
            parameters: P
        ) -> Service? {
            // If this service has already been created within the current resolution cycle, return it
            if let service = graph[entity.key] as? Service {
                return service
            }

            // Resolution cycle nesting:
            // we invoke the dependency factory, which may itself request other dependencies,
            // deepening the call stack. Once the top level completes, the graph is cleared.
            resolutionDepth += 1
            let service = entity.instantiate(resolver: resolver, parameters: parameters)
            resolutionDepth -= 1

            if resolutionDepth == 0 {
                // The top level of resolution finished — reset the graph cache
                graph.removeAll()
            } else if let service, type(of: service as Any) is AnyClass {
                // Cache the object (only if it is a class type) to reuse it within the current graph
                graph[entity.key] = service
            }

            return service
        }
    }
}
