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

/// Global recursive lock used to synchronize access to shared data.
///
/// Used, for example, during dependency resolution, where nested access to the same
/// resource is possible (e.g. a service depends on a service that depends on the first one).
///
/// It is also suitable for ensuring thread safety in any other critical sections of code.
///
/// Declared as `nonisolated(unsafe)` so it can be used without `async` isolation.
nonisolated(unsafe)
var globalRecursiveLock = RecursiveLock()

/// A thread-safe wrapper around `pthread_mutex_t` with support for recursive locking.
///
/// Allows synchronizing access to a resource from different threads and re-acquiring the lock
/// within the same thread. Suitable for safely working with shared data or with
/// nested calls within a single thread (e.g. during dependency resolution).
final class RecursiveLock {

    /// POSIX mutex.
    private var recursiveMutex = pthread_mutex_t()

    /// Mutex attributes with the `PTHREAD_MUTEX_RECURSIVE` type.
    private var recursiveMutexAttr = pthread_mutexattr_t()

    // MARK: - Init & Deinit

    /// Initializes a recursive POSIX lock.
    init() {
        pthread_mutexattr_init(&recursiveMutexAttr)
        pthread_mutexattr_settype(&recursiveMutexAttr, PTHREAD_MUTEX_RECURSIVE)
        pthread_mutex_init(&recursiveMutex, &recursiveMutexAttr)
    }

    /// Releases the resources associated with the lock.
    deinit {
        pthread_mutex_destroy(&recursiveMutex)
    }

    // MARK: - Public API

    /// Acquires the lock. If the same thread already holds the lock, it is acquired again.
    @inline(__always)
    func lock() {
        pthread_mutex_lock(&recursiveMutex)
    }

    /// Releases the lock.
    @inline(__always)
    func unlock() {
        pthread_mutex_unlock(&recursiveMutex)
    }
}
