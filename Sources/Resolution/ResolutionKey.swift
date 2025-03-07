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

/// Internal unique key under which dependencies are registered and resolved.
///
/// Consists of a type and an optional dependency name. Used as the key in the dependency storage.
struct ResolutionKey: Hashable, Sendable {

    let type: ObjectIdentifier
    let name: ResolverName?

    init(type: Any.Type, name: ResolverName?) {
        self.type = ObjectIdentifier(type)
        self.name = name
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(type)
        hasher.combine(name)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.type == rhs.type && lhs.name == rhs.name
    }
}
