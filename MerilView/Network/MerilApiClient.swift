import Foundation

/// Low-level HTTP client wrapping URLSession with TLS, JSON decoding, and authentication.
public final class MerilApiClient {
    
    public enum ApiError: Error, LocalizedError {
        case invalidURL
        case requestFailed(Int, String)
        case decodingFailed(Error)
        case networkError(Error)
        
        public var errorDescription: String? {
            switch self {
            case .invalidURL: return "The configured server URL is invalid."
            case .requestFailed(let code, let msg): return "HTTP Error \(code): \(msg)"
            case .decodingFailed(let err): return "Failed to parse server response: \(err.localizedDescription)"
            case .networkError(let err): return "Network connection failed: \(err.localizedDescription)"
            }
        }
    }
    
    private var baseUrl: String
    private let session: URLSession
    private var authToken: String?
    
    public init(baseUrl: String = "http://127.0.0.1:3001", timeoutSeconds: TimeInterval = 15) {
        self.baseUrl = baseUrl
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeoutSeconds
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }
    
    public func setBaseUrl(_ url: String) {
        self.baseUrl = url
    }
    
    public func getBaseUrl() -> String {
        return baseUrl
    }
    
    public func setAuthToken(_ token: String?) {
        self.authToken = token
    }
    
    public func get<T: Decodable>(path: String) async throws -> T {
        guard let url = URL(string: "\(baseUrl)\(path)") else {
            throw ApiError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ApiError.requestFailed(-1, "Unknown response type")
            }
            guard (200...299).contains(httpResponse.statusCode) else {
                let msg = String(data: data, encoding: .utf8) ?? ""
                throw ApiError.requestFailed(httpResponse.statusCode, msg)
            }
            
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                throw ApiError.decodingFailed(error)
            }
        } catch let apiErr as ApiError {
            throw apiErr
        } catch {
            throw ApiError.networkError(error)
        }
    }
    
    public func post<B: Encodable, T: Decodable>(path: String, body: B) async throws -> T {
        guard let url = URL(string: "\(baseUrl)\(path)") else {
            throw ApiError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        request.httpBody = try JSONEncoder().encode(body)
        
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ApiError.requestFailed(-1, "Unknown response type")
            }
            guard (200...299).contains(httpResponse.statusCode) else {
                let msg = String(data: data, encoding: .utf8) ?? ""
                throw ApiError.requestFailed(httpResponse.statusCode, msg)
            }
            
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                throw ApiError.decodingFailed(error)
            }
        } catch let apiErr as ApiError {
            throw apiErr
        } catch {
            throw ApiError.networkError(error)
        }
    }
    
    public func downloadData(path: String) async throws -> Data {
        guard let url = URL(string: "\(baseUrl)\(path)") else {
            throw ApiError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw ApiError.requestFailed((response as? HTTPURLResponse)?.statusCode ?? -1, "Download failed")
        }
        return data
    }
}
