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

// swiftlint:disable file_length

// MARK: - Defaults

extension Resolver {

    /// The global default container used by all `Resolver.resolve(...)` calls.
    ///
    /// Also used by properties and within the `ResolverRegistering` protocol implementation.
    ///
    /// ## Example
    /// ```swift
    /// let service: MyService = Resolver.resolve()
    /// // resolve will use Resolver.root under the hood
    /// ```
    public nonisolated(unsafe) static var root: Resolver = .init()

    /// The default scope applied when registering dependencies.
    ///
    /// Defaults to `.graph`. Can be overridden at runtime.
    ///
    /// ## Example
    /// ```swift
    /// Resolver.defaultScope = .application
    /// ```
    public nonisolated(unsafe) static var defaultScope: ResolverScope = .graph
}

/// The main Dependency Injection container.
///
/// `Resolver` registers and resolves dependencies throughout the application:
/// - allows injecting dependencies with parameters and/or context
/// - supports different scopes: `.application`, `.graph`, `.shared`, `.cached`, `.unique`
/// - provides support for nested containers (`child` containers)
/// - provides a flexible API for modification and extension (decorators, `implements`, `resolveProperties`)
///
/// Used directly or through the global `Resolver.root` container.
///
/// Supports registration via code (without annotations).
///
/// ## Capabilities
/// - Registering dependencies with or without parameters
/// - Resolving with a specified type, name (`name`), and parameters
/// - `@Sendable` support and thread safety
/// - Automatic registration via `ResolverRegistering.registerAll()`
/// - Resetting and re-registering dependencies via `Resolver.reset()`
///
/// ## Core Concepts
///
/// - `register(...)` — registers a dependency and its creation factory.
/// - `resolve(...)` — resolves a dependency.
/// - `scope(...)` — specifies the dependency's lifecycle (analogous to singleton/weak/unique).
/// - `decorator(...)` — wraps a dependency with additional logic (e.g. auto-configuration).
/// - `name` — the name under which a dependency is registered and resolved (when multiple
/// implementations of the same type are needed).
///
/// ## Example
/// ```swift
/// // Registration
/// Resolver.register { MyService() }
///     .scope(.application)
///
/// // Resolution
/// let service: MyService = Resolver.resolve()
///
/// // With a name
/// Resolver.register(MyService.self, name: .mock) { MockService() }
/// let service: MyService = Resolver.resolve(name: .mock)
///
/// // With a parameter
/// Resolver.register { (id: UUID) in MyService(id: id) }
/// let service = Resolver.resolve(parameters: UUID())
/// ```
///
/// ## `Resolver.root` support
/// By default the global `Resolver.root` container is used,
/// but you can use separate containers for modular DI.
///
/// ## Scope support
/// ```swift
/// Resolver.register { MyService() }
///     .scope(.application)
/// ```
public final class Resolver: Sendable {

    // MARK: - Properties

    /// The internal registry of registrations and child containers.
    private let manager: ResolutionRegistry

    // MARK: - Init

    /// Initializes a new container, optionally adding a child container.
    ///
    /// Used when you need to create a local container separated from the global `Resolver.root`.
    /// This is useful in modular architecture (e.g. for DI within a feature) or in unit tests for full isolation.
    ///
    /// If `child` is provided, when resolving services the current container first checks its own registrations,
    /// then delegates the lookup to the child container.
    ///
    /// ## Example
    /// ```swift
    /// let moduleResolver = Resolver(child: Resolver.root)
    /// ```
    public init(child: Resolver? = nil) {
        manager = ResolutionRegistry()
        guard let child else { return }
        manager.addChild(child.manager)
    }
}

// MARK: - Lifecycle

extension Resolver {

    /// Adds a child container to the current one.
    ///
    /// Useful when you need to combine several containers into a single resolution chain.
    ///
    /// Used, for example:
    /// - when building a modular container (DI within a feature)
    /// - to substitute dependencies in tests without affecting the global `Resolver.root`
    ///
    /// ## Example
    /// ```swift
    /// let testResolver = Resolver()
    /// testResolver.add(child: Resolver.root)
    ///
    /// let mockedService: MyService = testResolver.resolve()
    /// ```
    public func add(child: Resolver) {
        manager.addChild(child.manager)
    }

    /// Fully resets the global `Resolver.root` container.
    ///
    /// This includes:
    /// - resetting all registrations
    /// - re-invoking `registerAll()` (if `ResolverRegistering` is implemented)
    /// - clearing the cached `scopes` (.application, .cached, .shared)
    ///
    /// ## Example
    /// ```swift
    /// Resolver.reset()
    /// ```
    public static func reset() {
        globalRecursiveLock.lock()
        defer { globalRecursiveLock.unlock() }

        root = Resolver()

        ResolverScope.application.reset()
        ResolverScope.cached.reset()
        ResolverScope.shared.reset()

        RegistrationGuard.reset()
    }
}

// MARK: - Static Registration API

extension Resolver {

    /// Registers a service without parameters in the global `Resolver.root` container.
    ///
    /// ## Example
    /// ```swift
    /// Resolver.register { MyService() }
    /// ```
    ///
    /// - Parameters:
    ///   - type: The service type. Inferred from the return type by default.
    ///   - name: An optional dependency name.
    ///   - factory: A closure that creates and returns the service instance.
    /// - Returns: `ResolverRegistrationOptions` for further configuration.
    @discardableResult
    public static func register<Service: Sendable>(
        _ type: Service.Type = Service.self,
        name: ResolverName? = nil,
        factory: @escaping ResolverVoidFactory<Service>
    ) -> ResolverRegistrationOptions<Void, Service> {
        root.register(type, name: name, factory: factory)
    }

    /// Registers a service without parameters in the global `Resolver.root` container,
    /// with access to the `Resolver` in the factory.
    ///
    /// ## Example
    /// ```swift
    /// Resolver.register { resolver in
    ///     let dependency = resolver.resolve(MyDependency.self)
    ///     return MyService(dependency: dependency)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - type: The service type. Inferred from the return type by default.
    ///   - name: An optional dependency name.
    ///   - factory: A closure with a `resolver` argument that creates and returns the service instance.
    /// - Returns: `ResolverRegistrationOptions` for further configuration.
    @discardableResult
    public static func register<Service: Sendable>(
        _ type: Service.Type = Service.self,
        name: ResolverName? = nil,
        factory: @escaping ResolverVoidWithResolverFactory<Service>
    ) -> ResolverRegistrationOptions<Void, Service> {
        root.register(type, name: name, factory: factory)
    }

    /// Registers a service with parameters in the global `Resolver.root` container.
    ///
    /// ## Example
    /// ```swift
    /// Resolver.register { (config: AppConfig) in
    ///     MyService(config: config)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - type: The service type. Inferred from the return type by default.
    ///   - name: An optional dependency name.
    ///   - factory: A closure with a parameter of type `P` that creates and returns the service instance.
    /// - Returns: `ResolverRegistrationOptions` for further configuration.
    @discardableResult
    public static func register<P: Sendable, Service: Sendable>(
        _ type: Service.Type = Service.self,
        name: ResolverName? = nil,
        factory: @escaping ResolverParameterFactory<P, Service>
    ) -> ResolverRegistrationOptions<P, Service> {
        root.register(type, name: name, factory: factory)
    }

    /// Registers a service with parameters in the global `Resolver.root` container,
    /// with access to the `Resolver` in the factory.
    ///
    /// ## Example
    /// ```swift
    /// Resolver.register { (resolver, config: AppConfig) in
    ///     let dependency = resolver.resolve(MyDependency.self)
    ///     return MyService(dependency: dependency, config: config)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - type: The service type. Inferred from the return type by default.
    ///   - name: An optional dependency name.
    ///   - factory: A closure with a resolver argument and a parameter of type `P`,
    ///   that creates and returns the service instance.
    /// - Returns: `ResolverRegistrationOptions` for further configuration.
    @discardableResult
    public static func register<P: Sendable, Service: Sendable>(
        _ type: Service.Type = Service.self,
        name: ResolverName? = nil,
        factory: @escaping ResolverParameterWithResolverFactory<P, Service>
    ) -> ResolverRegistrationOptions<P, Service> {
        root.register(type, name: name, factory: factory)
    }
}

// MARK: - Instance Registration

extension Resolver {

    /// Registers a service without parameters.
    ///
    /// ## Example
    /// ```swift
    /// resolver.register { MyService() }
    /// ```
    ///
    /// - Parameters:
    ///   - type: The service type. Inferred from the return type by default.
    ///   - name: An optional dependency name.
    ///   - factory: A closure that creates and returns the service instance.
    /// - Returns: `ResolverRegistrationOptions` for further configuration.
    @discardableResult
    public func register<Service: Sendable>(
        _ type: Service.Type = Service.self,
        name: ResolverName? = nil,
        factory: @escaping ResolverVoidFactory<Service>
    ) -> ResolverRegistrationOptions<Void, Service> {
        register(type, name: name, factory: liftToParameterFactory(factory))
    }

    /// Registers a service without parameters, with access to the `Resolver` in the factory.
    ///
    /// ## Example
    /// ```swift
    /// resolver.register { resolver in
    ///     let dependency = resolver.resolve(MyDependency.self)
    ///     return MyService(dependency: dependency)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - type: The service type. Inferred from the return type by default.
    ///   - name: An optional dependency name.
    ///   - factory: A closure with a `resolver` argument that creates and returns the service instance.
    /// - Returns: `ResolverRegistrationOptions` for further configuration.
    @discardableResult
    public func register<Service: Sendable>(
        _ type: Service.Type = Service.self,
        name: ResolverName? = nil,
        factory: @escaping ResolverVoidWithResolverFactory<Service>
    ) -> ResolverRegistrationOptions<Void, Service> {
        register(type, name: name, factory: liftToParameterFactory(factory))
    }

    /// Registers a service with parameters.
    ///
    /// ## Example
    /// ```swift
    /// resolver.register { (config: AppConfig) in
    ///     MyService(config: config)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - type: The service type. Inferred from the return type by default.
    ///   - name: An optional dependency name.
    ///   - factory: A closure with a parameter of type `P` that creates and returns the service instance.
    /// - Returns: `ResolverRegistrationOptions` for further configuration.
    @discardableResult
    public func register<P: Sendable, Service: Sendable>(
        _ type: Service.Type = Service.self,
        name: ResolverName? = nil,
        factory: @escaping ResolverParameterFactory<P, Service>
    ) -> ResolverRegistrationOptions<P, Service> {
        register(type, name: name, factory: liftToParameterFactory(factory))
    }

    /// Registers a service with parameters, with access to the `Resolver` in the factory.
    ///
    /// ## Example
    /// ```swift
    /// resolver.register { (resolver, config: AppConfig) in
    ///     let dependency = resolver.resolve(MyDependency.self)
    ///     return MyService(dependency: dependency, config: config)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - type: The service type. Inferred from the return type by default.
    ///   - name: An optional dependency name.
    ///   - factory: A closure with a resolver argument and a parameter of type `P`,
    ///   that creates and returns the service instance.
    /// - Returns: `ResolverRegistrationOptions` for further configuration.
    @discardableResult
    public func register<P: Sendable, Service: Sendable>(
        _ type: Service.Type = Service.self,
        name: ResolverName? = nil,
        factory: @escaping ResolverParameterWithResolverFactory<P, Service>
    ) -> ResolverRegistrationOptions<P, Service> {
        let entry = manager.register(type, name: name, in: Resolver.defaultScope, factory: factory)
        return ResolverRegistrationOptions(entry: entry)
    }
}

// MARK: - Resolution

extension Resolver {

    /// Resolves and returns an instance of the specified type from the global `Resolver.root` container.
    ///
    /// ## Example
    /// ```swift
    /// let service: MyService = Resolver.resolve()
    /// let config: AppConfig = Resolver.resolve(name: .mock)
    /// let presenter: Presenter = Resolver.resolve(parameters: viewModel)
    /// ```
    ///
    /// - Parameters:
    ///   - type: The type of the resolved dependency (can be inferred automatically).
    ///   - name: An optional dependency name, if it was registered as `named`.
    ///   - parameters: Optional parameters passed to the factory. Defaults to `Void()`.
    /// - Returns: The resolved `Service` instance.
    public static func resolve<Service>(
        _ type: Service.Type = Service.self,
        name: ResolverName? = nil,
        parameters: some Any = ()
    ) -> Service {
        root.resolve(type, name: name, parameters: parameters)
    }

    /// Resolves and returns an instance of the specified type.
    ///
    /// ## Example
    /// ```swift
    /// let service: MyService = resolver.resolve()
    /// let config: AppConfig = resolver.resolve(name: .mock)
    /// let presenter: Presenter = resolver.resolve(parameters: viewModel)
    /// ```
    ///
    /// - Parameters:
    ///   - type: The type of the resolved dependency (can be inferred automatically).
    ///   - name: An optional dependency name, if it was registered as `named`.
    ///   - parameters: Optional parameters passed to the factory. Defaults to `Void()`.
    /// - Returns: The resolved `Service` instance.
    public func resolve<Service>(
        _ type: Service.Type = Service.self,
        name: ResolverName? = nil,
        parameters: some Any = ()
    ) -> Service {
        manager.resolve(type, name: name, parameters: parameters, resolver: self)
    }

    /// Attempts to resolve and return an instance of the specified type from the global `Resolver.root` container.
    ///
    /// ## Example
    /// ```swift
    /// let service: MyService? = Resolver.resolveOptional()
    /// let config: AppConfig? = Resolver.resolveOptional(name: .mock)
    /// let presenter: Presenter? = Resolver.resolveOptional(parameters: viewModel)
    /// ```
    ///
    /// - Parameters:
    ///   - type: The type of the resolved dependency (can be inferred automatically).
    ///   - name: An optional dependency name, if it was registered as `named`.
    ///   - parameters: Optional parameters passed to the factory. Defaults to `Void()`.
    /// - Returns: A `Service` instance, or `nil` if there was no registration for the given type.
    public static func resolveOptional<Service>(
        _ type: Service.Type = Service.self,
        name: ResolverName? = nil,
        parameters: some Any = ()
    ) -> Service? {
        root.resolveOptional(type, name: name, parameters: parameters)
    }

    /// Attempts to resolve and return an instance of the specified type.
    ///
    /// ## Example
    /// ```swift
    /// let service: MyService? = resolver.resolveOptional()
    /// let config: AppConfig? = resolver.resolveOptional(name: .mock)
    /// let presenter: Presenter? = resolver.resolveOptional(parameters: viewModel)
    /// ```
    ///
    /// - Parameters:
    ///   - type: The type of the resolved dependency (can be inferred automatically).
    ///   - name: An optional dependency name, if it was registered as `named`.
    ///   - parameters: Optional parameters passed to the factory. Defaults to `Void()`.
    /// - Returns: A `Service` instance, or `nil` if there was no registration for the given type.
    public func resolveOptional<Service>(
        _ type: Service.Type = Service.self,
        name: ResolverName? = nil,
        parameters: some Any = ()
    ) -> Service? {
        manager.resolveOptional(type, name: name, parameters: parameters, resolver: self)
    }
}

// MARK: - Internal Factory Adapters

/// Helper adapters for converting factories of different signatures into a single
/// `ResolverParameterWithResolverFactory` format.
///
/// These functions are necessary because of Swift Concurrency specifics:
/// when trying to wrap an `@isolated(any)` factory in another closure,
/// the compiler emits `Call to @isolated(any) parameter in a synchronous nonisolated context`.
/// To avoid this, we add an intermediate `let factory = factory`, **which strips `@isolated(any)`
/// on the outside and lets us correctly invoke the original factory inside the new wrapper**.
///
/// This is important to support:
/// - factories with `@MainActor` (e.g. registering UI entities)
/// - flexible DI without `await`
///
/// This approach is safe and does not violate the concurrency model because:
/// - the calls happen synchronously
/// - they do not escape the available isolation domain
extension Resolver {

    private func liftToParameterFactory<T: Sendable>(
        _ factory: @escaping ResolverVoidFactory<T>
    ) -> ResolverParameterWithResolverFactory<Void, T> {
        let factory: @Sendable () -> T = factory
        return { _, _ in factory() }
    }

    private func liftToParameterFactory<T: Sendable>(
        _ factory: @escaping ResolverVoidWithResolverFactory<T>
    ) -> ResolverParameterWithResolverFactory<Void, T> {
        let factory: @Sendable (Resolver) -> T = factory
        return { resolver, _ in factory(resolver) }
    }

    private func liftToParameterFactory<P: Sendable, T: Sendable>(
        _ factory: @escaping ResolverParameterFactory<P, T>
    ) -> ResolverParameterWithResolverFactory<P, T> {
        let factory: @Sendable (P) -> T = factory
        return { _, parameters in factory(parameters) }
    }
}

// swiftlint:enable file_length
