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

/// Internal trigger for one-time dependency registration.
///
/// Called on the first `resolve(...)` to perform registration
/// via `ResolverRegistering.registerAll()`, if `Resolver.root` conforms to that protocol.
enum RegistrationGuard {

    /// Internal flag indicating whether registration has already been performed.
    private nonisolated(unsafe) static var registrationNeeded: Bool = true

    /// Performs registration if it has not been done yet.
    @inline(__always)
    static func ensureRegistration() {
        globalRecursiveLock.lock()
        defer { globalRecursiveLock.unlock() }

        guard registrationNeeded else { return }

        if let registering = Resolver.root as? ResolverRegistering {
            type(of: registering).registerAll()
        }

        registrationNeeded = false
    }

    /// Resets the internal registration flag.
    static func reset() {
        globalRecursiveLock.lock()
        defer { globalRecursiveLock.unlock() }

        registrationNeeded = true
    }
}
