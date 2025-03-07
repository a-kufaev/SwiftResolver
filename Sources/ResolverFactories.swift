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

public typealias ResolverVoidFactory<T> = @Sendable @isolated(any) () -> T
public typealias ResolverVoidWithResolverFactory<T> = @Sendable @isolated(any) (_ resolver: Resolver) -> T
public typealias ResolverParameterFactory<P, T> = @Sendable @isolated(any) (P) -> T
public typealias ResolverParameterWithResolverFactory<P, T> = @Sendable @isolated(any) (
    _ resolver: Resolver,
    P
) -> T
