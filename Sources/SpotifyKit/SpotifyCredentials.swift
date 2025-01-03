//
//  SpotifyCredentials.swift
//  SpotifyKit
//
//  Created by Alexander Eichhorn on 25.04.20.
//

import Foundation

public actor SpotifyCredentials {
    let source: Source
    
    public typealias AccessTokenDelegateHandler = (@escaping @Sendable (Result<(String, Int), Error>) -> Void) -> Void
    
    enum Source {
        case client(clientID: String, clientSecret: String)
        case delegate(handler: AccessTokenDelegateHandler)
    }
    
    public init(clientID: String, clientSecret: String) {
        self.source = .client(clientID: clientID, clientSecret: clientSecret)
    }
    
    public init(handler: @escaping AccessTokenDelegateHandler) {
        self.source = .delegate(handler: handler)
    }
    
    // MARK: -
    
    private let tokenURL = URL(string: "https://accounts.spotify.com/api/token")!
    
    @Expirable(duration: 3600)
    private var accessToken: String?
    
    enum CredentialError: Error {
        case unknown
    }
    
    func getAccessToken(completion: @escaping @Sendable (Result<String, Error>) -> Void) {
        if let accessToken = accessToken {
            completion(.success(accessToken))
        } else {
            requestAccessToken(completion: completion)
        }
    }
    
    @available(iOS 13.0, watchOS 6.0, tvOS 13.0, macOS 10.15, *)
    func getAccessToken() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            getAccessToken { result in
                continuation.resume(with: result)
            }
        }
    }
    
    private func requestAuthorization(for clientID: String, clientSecret: String) -> String {
        (clientID + ":" + clientSecret).data(using: .ascii)?.base64EncodedString() ?? ""
    }
    
    private func requestAccessToken(completion: @escaping @Sendable (Result<String, Error>) -> Void) {
        
        switch source {
        case .delegate(let handler):
            handler { result in
                Task {
                    switch result {
                    case .success(let (token, expiresIn)):
                        await self.setAccessToken(token, duration: TimeInterval(expiresIn))
                        completion(.success(token))
                        
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            }
            
        case .client(let clientID, let clientSecret):
            var components = URLComponents()
            components.queryItems = [
                URLQueryItem(name: "grant_type", value: "client_credentials")
            ]
            
            var request = URLRequest(url: tokenURL)
            request.addValue("Basic \(requestAuthorization(for: clientID, clientSecret: clientSecret))", forHTTPHeaderField: "Authorization")
            request.httpMethod = "post"
            request.httpBody = components.percentEncodedQuery?.data(using: .utf8)
            
            URLSession.shared.dataTask(with: request) { data, reponse, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let data = data,
                    let response = try? JSONDecoder().decode(AccessTokenResponse.self, from: data) else {
                        completion(.failure(CredentialError.unknown))
                        return
                }
                
                Task {
                    await self.setAccessToken(response.access_token)
                    completion(.success(response.access_token))
                }
                
            }.resume()
        }
        
    }
    
    private func setAccessToken(_ token: String, duration: TimeInterval) {
        self._accessToken.set(token, duration: duration)
    }
    
    private func setAccessToken(_ accessToken: String) {
        self.accessToken = accessToken
    }
    
    // MARK: - Request Objects
    
    // MARK: - Response Objects
    
    private struct AccessTokenResponse: Decodable {
        let access_token: String
        let token_type: String
        let expires_in: Int
        let scope: String
    }
}
