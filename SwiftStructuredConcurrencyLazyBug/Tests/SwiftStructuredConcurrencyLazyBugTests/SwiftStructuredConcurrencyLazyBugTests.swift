import XCTest
@testable import SwiftStructuredConcurrencyLazyBug

/**
 This test class contains two **functionally** identical tests.
 The first test uses a locally initialized SUT, and passes.
 The second test uses a lazy initialized SUT, and fails.
 */
final class RequestServiceTests: XCTestCase {
    
    let url = URL(string: "https://abc.example.com/resource/123")!
    let urlSession = MockURLSession()
    lazy var sut = RequestService(session: urlSession)

    func testDuplicateRequestUsingLocalSUT() async throws {
        //Given
        let urlSession = MockURLSession()
        let sut = RequestService(session: urlSession)
        for delay in [5.0, 2.0] {
            urlSession.responsesFIFO.append(MockURLSession.MockResponse(
                result: .success((Data(), URLResponse(url: url))),
                delay: delay)
            )
        }
        do {
            //When
            async let a = sut.request(url: url)
            async let b = sut.request(url: url)
            //Important: calling await on `async let`'s will run each function concurrently. Otherwise, Swift will implicitly wait for it only when exiting its scope.
            print(try await a.count + b.count)
            XCTFail()
        } catch {
            //Then
            XCTAssert(error is CancellationError)
        }
    }
    
    func testDuplicateRequestUsingLazySUT() async throws {
        //Given
        for delay in [5.0, 2.0] {
            urlSession.responsesFIFO.append(MockURLSession.MockResponse(
                result: .success((Data(), URLResponse(url: url))),
                delay: delay)
            )
        }
        do {
            //When
            async let a = sut.request(url: url)
            async let b = sut.request(url: url)
            //Important: calling await on `async let`'s will run each function concurrently. Otherwise, Swift will implicitly wait for it only when exiting its scope.
            //This doesn't seem to work when the calling function resides in a lazy initialized variable. Only one function is called, the second function doesn't get called concurrently. I think that this is a bug.
            print(try await a.count + b.count)
            XCTFail()
        } catch {
            //Then
            XCTAssert(error is CancellationError)
        }
    }
}

final class MockURLSession: URLSessionProtocol {
    
    struct MockResponse {
        let result: Result<(Data, URLResponse), Error>
        let delay: TimeInterval
    }
    
    var responsesFIFO = [MockResponse]()
    
    /**
     This method will return the mocked response `result` property stored in `responsesFIFO`. Additionally, it will sleep the detached task for the amount of time specified in the mocked response `delay` property. This allows you to control the particular order a batch of concurrent `async let`s calls returns when `await`ed.
     */
    func data(from url: URL) async throws -> (Data, URLResponse) {
        try await Task.detached(priority: .userInitiated) { [self] in
            let response = responsesFIFO.removeFirst()
            try await Task.sleep(for: .seconds(response.delay))
            return try response.result.get()
        }.value
    }
}

extension URLResponse {
    
    convenience init(url: URL) {
        self.init(url: url, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
    }
}
