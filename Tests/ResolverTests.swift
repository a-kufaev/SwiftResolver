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
import Testing
@testable import SwiftResolver

// MARK: - Test Services

private protocol ServiceProtocol: Sendable {
    var id: String { get }
}

private final class TestService: ServiceProtocol, @unchecked Sendable {
    let id: String
    var configuredValue: String = ""

    init(id: String = UUID().uuidString) {
        self.id = id
    }
}

private final class DependentService: Sendable {
    let dependency: ServiceProtocol

    init(dependency: ServiceProtocol) {
        self.dependency = dependency
    }
}

// MARK: - All Tests (serialized due to shared global state)

@Suite("Resolver Tests", .serialized)
struct ResolverTests {

    init() {
        Resolver.reset()
    }

    // MARK: - Basic Registration

    @Test("Register and resolve simple service")
    func registerAndResolve() {
        Resolver.register { TestService(id: "test-1") }

        let service: TestService = Resolver.resolve()

        #expect(service.id == "test-1")
    }

    @Test("Register with resolver access")
    func registerWithResolver() {
        Resolver.register { TestService(id: "dependency") }
            .implements(ServiceProtocol.self)

        Resolver.register { resolver in
            DependentService(dependency: resolver.resolve())
        }

        let service: DependentService = Resolver.resolve()

        #expect(service.dependency.id == "dependency")
    }

    @Test("Register with parameters")
    func registerWithParameters() {
        Resolver.register { (id: String) in
            TestService(id: id)
        }

        let service: TestService = Resolver.resolve(parameters: "custom-id")

        #expect(service.id == "custom-id")
    }

    // MARK: - Named Registration

    @Test("Resolve by name")
    func resolveByName() {
        Resolver.register(TestService.self, name: "first") { TestService(id: "1") }
        Resolver.register(TestService.self, name: "second") { TestService(id: "2") }

        let first: TestService = Resolver.resolve(name: "first")
        let second: TestService = Resolver.resolve(name: "second")

        #expect(first.id == "1")
        #expect(second.id == "2")
    }

    // MARK: - Scopes

    @Test("Application scope returns same instance")
    func applicationScope() {
        Resolver.register { TestService() }
            .scope(.application)

        let first: TestService = Resolver.resolve()
        let second: TestService = Resolver.resolve()

        #expect(first === second)
    }

    @Test("Unique scope returns different instances")
    func uniqueScope() {
        Resolver.register { TestService() }
            .scope(.unique)

        let first: TestService = Resolver.resolve()
        let second: TestService = Resolver.resolve()

        #expect(first !== second)
    }

    @Test("Cached scope can be reset")
    func cachedScopeReset() {
        Resolver.register { TestService() }
            .scope(.cached)

        let first: TestService = Resolver.resolve()

        ResolverScope.cached.reset()

        let second: TestService = Resolver.resolve()

        #expect(first !== second)
    }

    // MARK: - Optional Resolution

    @Test("Resolve optional returns nil for unregistered")
    func resolveOptionalUnregistered() {
        let service: TestService? = Resolver.resolveOptional()

        #expect(service == nil)
    }

    @Test("Resolve optional returns instance for registered")
    func resolveOptionalRegistered() {
        Resolver.register { TestService(id: "optional") }

        let service: TestService? = Resolver.resolveOptional()

        #expect(service?.id == "optional")
    }

    // MARK: - Decorators

    @Test("Decorator is called after instantiation")
    func decoratorCalled() {
        Resolver.register { TestService() }
            .decorator { service, _ in
                service.configuredValue = "decorated"
            }

        let service: TestService = Resolver.resolve()

        #expect(service.configuredValue == "decorated")
    }

    @Test("Multiple decorators are chained")
    func multipleDecorators() {
        Resolver.register { TestService() }
            .decorator { service, _ in
                service.configuredValue = "first"
            }
            .decorator { service, _ in
                service.configuredValue += "-second"
            }

        let service: TestService = Resolver.resolve()

        #expect(service.configuredValue == "first-second")
    }

    // MARK: - Child Containers

    @Test("Child container resolves from parent")
    func childResolvesFromParent() {
        Resolver.register { TestService(id: "parent") }

        let child = Resolver(child: Resolver.root)

        let service: TestService = child.resolve()

        #expect(service.id == "parent")
    }

    @Test("Child container overrides parent")
    func childOverridesParent() {
        Resolver.register { TestService(id: "parent") }

        let child = Resolver(child: Resolver.root)
        child.register { TestService(id: "child") }

        let parentService: TestService = Resolver.resolve()
        let childService: TestService = child.resolve()

        #expect(parentService.id == "parent")
        #expect(childService.id == "child")
    }
}
