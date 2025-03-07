# SwiftResolver

A lightweight Dependency Injection container for Swift, built from scratch with first-class Swift 6 Concurrency support and inspired by [Resolver](https://github.com/hmlongco/Resolver) by Michael Long.

## Features

- ⚡️ **Swift 6 Concurrency** — full `Sendable` support and `@isolated(any)` factories for working with `@MainActor` and other actors
- 🔒 **Thread-safe** — synchronization via a recursive lock
- 🧩 **Scopes** — flexible control over dependency lifetime
- 🪶 **Fluent API** — convenient chainable configuration syntax
- 🎛 **Parameterized factories** — pass arguments at resolution time
- 🌳 **Container hierarchy** — child containers for modular architecture
- 🧪 **Test-friendly** — isolate and override dependencies with child containers

## Requirements

- Swift 6.0+
- iOS 14.0+ / macOS 11.0+ / tvOS 14.0+ / watchOS 7.0+ / visionOS 1.0+

## Installation

### Swift Package Manager

Add SwiftResolver to your project using Xcode or by adding it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/a-kufaev/SwiftResolver.git", from: "1.0.0")
]
```

## Quick Start

### Registering dependencies

```swift
import SwiftResolver

extension Resolver: @retroactive ResolverRegistering {
    public static func registerAll() {
        // Simple registration
        register { NetworkService() }

        // With dependencies
        register { resolver in
            UserRepository(network: resolver.resolve())
        }

        // With parameters
        register { (userId: String) in
            UserProfileService(userId: userId)
        }
    }
}
```

### Resolving dependencies

```swift
// Automatic type inference
let network: NetworkService = Resolver.resolve()

// Explicit type
let repo = Resolver.resolve(UserRepository.self)

// With parameters
let profile: UserProfileService = Resolver.resolve(parameters: "user-123")

// Optional resolution (no fatalError)
let optional: SomeService? = Resolver.resolveOptional()
```

## Scopes

| Scope | Behavior |
|-------|----------|
| `.graph` | **Default.** A single instance within the current resolution cycle |
| `.application` | Singleton for the entire application lifetime |
| `.cached` | Like a singleton, but can be reset via `reset()` |
| `.shared` | Weak reference: lives while external strong references exist |
| `.unique` | A new instance on every `resolve()` |

```swift
Resolver.register { DatabaseManager() }
    .scope(.application)

Resolver.register { AnalyticsService() }
    .scope(.cached)
```

## Named dependencies

```swift
extension ResolverName {
    static let mock = ResolverName("mock")
    static let production = ResolverName("production")
}

Resolver.register(APIClient.self, name: .mock) { MockAPIClient() }
Resolver.register(APIClient.self, name: .production) { ProductionAPIClient() }

let client: APIClient = Resolver.resolve(name: .mock)
```

## Interfaces (protocols)

```swift
Resolver.register { UserRepositoryImpl() }
    .implements(UserRepository.self)

let repo: UserRepository = Resolver.resolve()
```

## Decorators

```swift
Resolver.register { MyService() }
    .decorator { service, _ in
        service.configure()
    }
    .decorator { resolver, service, _ in
        service.logger = resolver.resolve()
    }
```

## Child containers

Useful for modular architecture or isolation in tests:

```swift
let featureContainer = Resolver(child: Resolver.root)
featureContainer.register { FeatureService() }

let service: FeatureService = featureContainer.resolve()
```

## Resetting state

```swift
// Full reset (registrations + caches)
Resolver.reset()

// Reset only the cache of a specific scope
ResolverScope.cached.reset()
ResolverScope.shared.reset()
```

## Working with @MainActor

Thanks to `@isolated(any)`, factories can be bound to a specific actor:

```swift
Resolver.register { @MainActor in
    ViewModel()
}
```

## Architecture

```
Sources/
├── Resolver.swift                   # Main container
├── ResolverFactories.swift          # Factory types
├── ResolverName.swift               # Named dependencies
├── ResolverRegistering.swift        # Auto-registration protocol
├── ResolverRegistrationOptions.swift # Fluent API
├── Resolution/
│   ├── ResolutionEntry.swift        # Registration unit
│   ├── ResolutionKey.swift          # Storage key
│   ├── ResolutionRegistry.swift     # Registration manager
│   └── Helpers/
│       ├── RecursiveLock.swift      # Thread safety
│       └── RegistrationGuard.swift  # Lazy initialization
└── ResolverScope/
    ├── ResolverScope.swift          # Base class
    ├── ResolverScopeCache.swift
    ├── ResolverScopeGraph.swift
    ├── ResolverScopeShare.swift
    └── ResolverScopeUnique.swift
```

## Inspiration

This library is built from scratch in the spirit of [Resolver](https://github.com/hmlongco/Resolver) — a popular Swift DI container. Key differences:

- Full Swift 6 Concurrency support
- A simplified API without property wrappers
- A focus on explicit registration without magic

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

SwiftResolver is available under the MIT license. See the [LICENSE](https://github.com/a-kufaev/SwiftResolver/blob/main/LICENSE) file for more info.
