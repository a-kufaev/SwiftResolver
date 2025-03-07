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

    /// The `Share` scope stores dependencies using weak (`weak`) references.
    ///
    /// The object is created once and retained while **external strong references** to it exist.
    /// If all external references are lost, the object is automatically removed from memory and will be
    /// created again on the next `resolve(...)`.
    ///
    /// This is a flexible caching approach that saves memory when working with temporary or reusable
    /// objects, without keeping them in memory "forever" like `.cached` or `.application`.
    ///
    /// ## Example
    /// ```swift
    /// Resolver.register { MyService() }
    ///     .scope(.shared)
    ///
    /// let s1 = resolver.resolve(MyService.self)
    /// var s2: MyService? = resolver.resolve()
    /// s2 = nil
    /// // The next resolve will create a new instance
    /// ```
    public final class Share: ResolverScope, @unchecked Sendable {

        // MARK: - Internal Storage

        private var cachedServices = [ResolutionKey: BoxWeak](minimumCapacity: 32)

        // MARK: - Resolution

        /// Returns a previously created object if it still exists, otherwise creates a new one.
        ///
        /// - The object is stored in a weak (`weak`) box.
        /// - If the object has already been deallocated, a new instance is created.
        override func resolve<P, Service>(
            entity: ResolutionEntry<P, Service>,
            resolver: Resolver,
            parameters: P
        ) -> Service? {
            // Try to retrieve a previously created, not-yet-deallocated dependency
            if let service = cachedServices[entity.key]?.service as? Service {
                return service
            }

            // Create a new dependency
            let service = entity.instantiate(resolver: resolver, parameters: parameters)

            // If it is a class type — store it in a weak box
            if let service, type(of: service as Any) is AnyClass {
                cachedServices[entity.key] = BoxWeak(service: service as AnyObject)
            }

            return service
        }

        // MARK: - Reset

        /// Forcibly clears all weak references from the cache.
        override public func reset() {
            cachedServices.removeAll()
        }
    }
}

/// A wrapper for storing weak references to objects.
private struct BoxWeak {
    weak var service: AnyObject?
}
