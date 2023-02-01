import Foundation

final actor RequestService: RequestServiceProtocol {
    
    private let session: URLSessionProtocol
    private var requestsMap: [URL : Task<Data, Error>] = [:]
    
    init(session: URLSessionProtocol) {
        self.session = session
    }
    
    /**
     Fetches the data at the specified URL. If an existing request was made with the same URL, then the new request will be cancelled and throws a `CancellationError`.
          
     - parameter url: the `URL` to request.
     - returns: `Data`
     */
    func request(url: URL) async throws -> Data {
        let fetchDataTask = buildFetchDataTask(url: url)
        if requestsMap[url] == nil {
            requestsMap[url] = fetchDataTask
        } else {
            fetchDataTask.cancel()
        }
        return try await fetchDataTask.value
    }
    
    private func buildFetchDataTask(url: URL) -> Task<Data, Error> {
        Task(priority: .userInitiated) { () -> Data in
            do {
                let (data, _) = try await self.session.data(from: url)
                try Task.checkCancellation()
                requestsMap[url] = nil
                return data
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                requestsMap[url] = nil
                throw error
            }
        }
    }
}

protocol RequestServiceProtocol {
    
    /**
     Fetches the data at the specified URL. If an existing request was made with the same URL, then the new request will be cancelled and throws a `CancellationError`.
          
     - parameter url: the `URL` to request.
     - returns: `Data`
     */
    func request(url: URL) async throws -> Data
}

protocol URLSessionProtocol {
    
    func data(from: URL) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionProtocol {}
