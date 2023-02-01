import Foundation

final actor SomeActor {
    func dateAfter(seconds: TimeInterval) async throws -> Date {
        try await Task.detached(priority: .userInitiated) {
            try await Task.sleep(for: .seconds(seconds))
            return Date()
        }.value
    }
}

final class SomeClass {
    
    func runConcurrentTasks() {
        Task {
            let sut = SomeActor()
            let now = Date()
            async let a = sut.dateAfter(seconds: 2)
            async let b = sut.dateAfter(seconds: 3)
            //Calling await on `async let`s will run each function concurrently.
            print("Local SUT T \(try await a.timeIntervalSince(now) + b.timeIntervalSince(now))")
            print("Local SUT A \(try await a.timeIntervalSince(now))")
            print("Local SUT B \(try await b.timeIntervalSince(now))")
        }
    }
}

final class SomeClassWithLazySUT {
    
    lazy var sut = SomeActor()
    
    func runConcurrentTasks() {
        Task {
            let now = Date()
            async let a = sut.dateAfter(seconds: 2)
            async let b = sut.dateAfter(seconds: 3)
            //Calling await on `async let`s will run each function concurrently.
            print("Lazy  SUT T \(try await a.timeIntervalSince(now) + b.timeIntervalSince(now))")
            print("Lazy  SUT A \(try await a.timeIntervalSince(now))")
            print("Lazy  SUT B \(try await b.timeIntervalSince(now))")
        }
    }
}

SomeClass().runConcurrentTasks()
SomeClassWithLazySUT().runConcurrentTasks()
/**
 Observation: here a lazy initialized SUT doesn't exhibit the same behaviour as in an XCTest test case method, where it seems each `async let` function is run concurrently, as suggested by the timings output below.
 
 Output:
 Lazy  SUT T 5.188830018043518
 Local SUT T 5.188886046409607
 Lazy  SUT A 2.0105329751968384
 Local SUT A 2.010563015937805
 Lazy  SUT B 3.1782970428466797
 Local SUT B 3.1783230304718018
 */

