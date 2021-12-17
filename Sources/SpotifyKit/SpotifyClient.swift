//
//  File.swift
//  
//
//  Created by Alexander Eichhorn on 25.04.20.
//

import Foundation

public class SpotifyClient {
    
    let credentials: SpotifyCredentials
    
    public var market: Market?
    
    private let baseURL = URL(string: "https://api.spotify.com/v1")!
    
    public init(credentials: SpotifyCredentials) {
        self.credentials = credentials
    }
    
    enum RequestError: Error {
        case unknown
    }
    
    public typealias Completion<T> = (Result<T, Error>) -> Void
    
    private func authenticationHeader(completion: @escaping (Result<[String: String], Error>) -> Void) {
        credentials.getAccessToken { result in
            switch result {
            case .success(let accessToken):
                completion(.success(["Authorization": "Bearer \(accessToken)"]))
            case .failure(let error):
                completion(.failure(error))
            }
        }
        
    }
    
    private func url(forPath path: String, query: [URLQueryItem]) -> URL {
        var urlComponents = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        urlComponents.path += path
        urlComponents.queryItems = query.filter({ $0.value != nil })
        
        if let market = market {
            urlComponents.queryItems?.append(URLQueryItem(name: "market", value: market.rawValue.uppercased()))
        }
        
        return urlComponents.url!
    }
    
    private func get(path: String, query: [URLQueryItem], additionalHeader: [String: String]? = nil, completion: @escaping (Result<(Data, URLResponse), Error>) -> Void) {
        
        authenticationHeader { result in
            switch result {
            case .success(let header):
                let url = self.url(forPath: path, query: query)
                var request = URLRequest(url: url)
                request.allHTTPHeaderFields = header
                
                if let additionalHeader = additionalHeader {
                    additionalHeader.forEach {
                        request.setValue($0.value, forHTTPHeaderField: $0.key)
                    }
                }
                
                URLSession.shared.dataTask(with: request) { data, response, error in
                    if let error = error {
                        completion(.failure(error))
                        return
                    }
                    
                    if let data = data, let response = response {
                        completion(.success((data, response)))
                        return
                    }
                    
                    completion(.failure(RequestError.unknown))
                    
                }.resume()
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
        
    }
    
    private func getDecodableAndResponse<T: Decodable>(_ type: T.Type, path: String, query: [URLQueryItem], header: [String: String]? = nil, completion: @escaping (Result<(T, URLResponse), Error>) -> Void) {
        get(path: path, query: query, additionalHeader: header) { result in
            switch result {
            case .success(let (data, response)):
                do {
                    let decoded = try JSONDecoder().decode(T.self, from: data)
                    completion(.success((decoded, response)))
                } catch let error {
                    completion(.failure(error))
                }
            
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    private func getDecodable<T: Decodable>(_ type: T.Type, path: String, query: [URLQueryItem], completion: @escaping (Result<T, Error>) -> Void) {
        getDecodableAndResponse(type, path: path, query: query) { result in
            completion(result.map { $0.0 })
        }
    }
    
    @available(iOS 13.0, watchOS 6.0, tvOS 13.0, macOS 10.15, *)
    private func getDecodable<T: Decodable>(_ type: T.Type, path: String, query: [URLQueryItem]) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            getDecodable(type, path: path, query: query) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    /// - parameter etag: current etag which should be compared against
    /// - parameter preventLocalCacheResponse: Makes sure result isn't returned when etags match (could occur when local cache is used) (default: true)
    private func getDecodableAndEtag<T: Decodable>(_ type: T.Type, path: String, query: [URLQueryItem], etag: String? = nil, preventLocalCacheResponse: Bool = true, completion: @escaping (Result<(T?, String?), Error>) -> Void) {
        
        let header = etag.map { ["If-None-Match": $0] }
        
        get(path: path, query: query, additionalHeader: header) { result in
            switch result {
            case .success(let (data, response)):
                let updatedEtag = (response as? HTTPURLResponse)?.allHeaderFields["Etag"] as? String
                let statusCode = (response as? HTTPURLResponse)?.statusCode
                
                if statusCode == 304 || (preventLocalCacheResponse && statusCode == 200 && etag == updatedEtag) { // not modified
                    completion(.success((nil, updatedEtag)))
                    return
                }
                
                do {
                    let decoded = try JSONDecoder().decode(T.self, from: data)
                    completion(.success((decoded, updatedEtag)))
                } catch let error {
                    completion(.failure(error))
                }
            
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    
    // MARK: - Search
    
    public func search(_ query: String, limit: Int = 10, offset: Int = 0, types: [SearchType] = [.track], completion: @escaping (Result<SpotifySearchResult, Error>) -> Void) {
        
        let encodedType = types.map { $0.rawValue }.joined(separator: ",")
        
        getDecodable(SpotifySearchResult.self, path: "/search", query: [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "type", value: encodedType),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ], completion: completion)
        
    }
    
    @available(iOS 13.0, watchOS 6.0, tvOS 13.0, macOS 10.15, *)
    public func search(_ query: String, limit: Int = 10, offset: Int = 0, types: [SearchType] = [.track]) async throws -> SpotifySearchResult {
        try await withCheckedThrowingContinuation { continuation in
            search(query, limit: limit, offset: offset, types: types) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    
    // MARK: - Track
    
    public func getTrack(with id: String, completion: @escaping Completion<SpotifyTrack>) {
        getDecodable(SpotifyTrack.self, path: "/tracks/\(id)", query: [], completion: completion)
    }
    
    @available(iOS 13.0, watchOS 6.0, tvOS 13.0, macOS 10.15, *)
    public func getTrack(with id: String) async throws -> SpotifyTrack {
        return try await getDecodable(SpotifyTrack.self, path: "/tracks/\(id)", query: [])
    }
    
    public func getTrackDetails(for track: SpotifyTrack, completion: @escaping Completion<SpotifyTrack>) {
        getTrack(with: track.id, completion: completion)
    }
    
    @available(iOS 13.0, watchOS 6.0, tvOS 13.0, macOS 10.15, *)
    public func getTrackDetails(for track: SpotifyTrack) async throws -> SpotifyTrack {
        return try await getTrack(with: track.id)
    }
    
    /// - parameter ids: maximum 50 ids accepted
    public func getTracks(with ids: [String], completion: @escaping Completion<[SpotifyTrack]>) {
        assert(ids.count <= 50, "Only 50 ids accepted")
        
        getDecodable(SpotifyTopTracks.self, path: "/tracks", query: [
            URLQueryItem(name: "ids", value: ids.joined(separator: ","))
        ]) { result in
            completion(result.map { $0.tracks })
        }
    }
    
    /// - parameter ids: maximum 50 ids accepted
    @available(iOS 13.0, watchOS 6.0, tvOS 13.0, macOS 10.15, *)
    public func getTracks(with ids: [String]) async throws -> [SpotifyTrack] {
        assert(ids.count <= 50, "Only 50 ids accepted")
        
        return try await getDecodable(SpotifyTopTracks.self, path: "/tracks", query: [
            URLQueryItem(name: "ids", value: ids.joined(separator: ","))
        ]).tracks
    }
    
    /// - parameter tracks: maximum 50 tracks accepted
    public func getMultipleTrackDetails(for tracks: [SpotifyTrack], completion: @escaping Completion<[SpotifyTrack]>) {
        getTracks(with: tracks.map { $0.id }, completion: completion)
    }
    
    /// - parameter tracks: maximum 50 tracks accepted
    @available(iOS 13.0, watchOS 6.0, tvOS 13.0, macOS 10.15, *)
    public func getMultipleTrackDetails(for tracks: [SpotifyTrack]) async throws -> [SpotifyTrack] {
        try await getTracks(with: tracks.map { $0.id })
    }
    
    
    // MARK: - Album
    
    public func getAlbum(withID id: String, completion: @escaping (Result<SpotifyAlbum, Error>) -> Void) {
        getDecodable(SpotifyAlbum.self, path: "/albums/\(id)", query: [], completion: completion)
    }
    
    @available(iOS 13.0, watchOS 6.0, tvOS 13.0, macOS 10.15, *)
    public func getAlbum(withID id: String) async throws -> SpotifyAlbum {
        return try await getDecodable(SpotifyAlbum.self, path: "/albums/\(id)", query: [])
    }
    
    /// load missing values
    public func getAlbumDetails(for album: SpotifyAlbum, completion: @escaping (Result<SpotifyAlbum, Error>) -> Void) {
        getAlbum(withID: album.id, completion: completion)
    }
    
    /// load missing values
    @available(iOS 13.0, watchOS 6.0, tvOS 13.0, macOS 10.15, *)
    public func getAlbumDetails(for album: SpotifyAlbum) async throws -> SpotifyAlbum {
        return try await getAlbumDetails(for: album)
    }
    
    /// - parameter limit: maximum is 50 (default: 50)
    public func getAlbumTracks(forID id: String, @Clamped(max: 50) limit: Int = 50, offset: Int = 0, completion: @escaping Completion<SpotifyPagingResult<SpotifyTrack>>) {
        getDecodable(SpotifyPagingResult<SpotifyTrack>.self, path: "/albums/\(id)/tracks", query: [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ], completion: completion)
    }
    
    /// - parameter limit: maximum is 50 (default: 50)
    @available(iOS 13.0, watchOS 6.0, tvOS 13.0, macOS 10.15, *)
    public func getAlbumTracks(forID id: String, @Clamped(max: 50) limit: Int = 50, offset: Int = 0) async throws -> SpotifyPagingResult<SpotifyTrack> {
        try await withCheckedThrowingContinuation { continuation in
            getAlbumTracks(forID: id, limit: limit, offset: offset) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    /// - parameter limit: maximum is 50 (default: 50)
    public func getAlbumTracks(for album: SpotifyAlbum, @Clamped(max: 50) limit: Int = 50, offset: Int = 0, completion: @escaping Completion<SpotifyPagingResult<SpotifyTrack>>) {
        getAlbumTracks(forID: album.id, limit: limit, offset: offset, completion: completion)
    }
    
    /// - parameter limit: maximum is 50 (default: 50)
    @available(iOS 13.0, watchOS 6.0, tvOS 13.0, macOS 10.15, *)
    public func getAlbumTracks(for album: SpotifyAlbum, @Clamped(max: 50) limit: Int = 50, offset: Int = 0) async throws -> SpotifyPagingResult<SpotifyTrack> {
        return try await getAlbumTracks(forID: album.id, limit: limit, offset: offset)
    }
    
    
    // MARK: - Artist
    
    public func getArtist(withID id: String, completion: @escaping (Result<SpotifyArtist, Error>) -> Void) {
        getDecodable(SpotifyArtist.self, path: "/artists/\(id)", query: [], completion: completion)
    }
    
    @available(iOS 13.0, watchOS 6.0, tvOS 13.0, macOS 10.15, *)
    public func getArtist(withID id: String) async throws -> SpotifyArtist {
        return try await getDecodable(SpotifyArtist.self, path: "/artists/\(id)", query: [])
    }
    
    /// - parameter completion: returns array of **simplified** album objects
    public func getAlbums(for artist: SpotifyArtist, ofTypes types: [SpotifyAlbum.AlbumType]? = nil, limit: Int = 10, offset: Int = 0, completion: @escaping Completion<SpotifyPagingResult<SpotifyAlbum>>) {
        
        var query = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]
        
        if let encodedTypes = types?.map({ $0.rawValue }).joined(separator: ",") {
            query.append(URLQueryItem(name: "include_groups", value: encodedTypes))
        }
        getDecodable(SpotifyPagingResult<SpotifyAlbum>.self, path: "/artists/\(artist.id)/albums", query: query, completion: completion)
    }
    
    /// - parameter completion: returns array of **simplified** album objects
    @available(iOS 13.0, watchOS 6.0, tvOS 13.0, macOS 10.15, *)
    public func getAlbums(for artist: SpotifyArtist, ofTypes types: [SpotifyAlbum.AlbumType]? = nil, limit: Int = 10, offset: Int = 0) async throws -> SpotifyPagingResult<SpotifyAlbum> {
        try await withCheckedThrowingContinuation { continuation in
            getAlbums(for: artist, ofTypes: types, limit: limit, offset: offset) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    /// - parameter completion: returns array of **full** track objects
    public func getTopTracks(for artist: SpotifyArtist, completion: @escaping Completion<[SpotifyTrack]>) {
        getDecodable(SpotifyTopTracks.self, path: "/artists/\(artist.id)/top-tracks", query: []) { result in
            let tracks = result.map { $0.tracks }
            completion(tracks)
        }
    }
    
    /// - parameter completion: returns array of **full** track objects
    @available(iOS 13.0, watchOS 6.0, tvOS 13.0, macOS 10.15, *)
    public func getTopTracks(for artist: SpotifyArtist) async throws -> [SpotifyTrack] {
        return try await getDecodable(SpotifyTopTracks.self, path: "/artists/\(artist.id)/top-tracks", query: []).tracks
    }
    
    /// - parameter completion: returns array of **full** artist objects
    public func getRelatedArtists(for artist: SpotifyArtist, completion: @escaping Completion<[SpotifyArtist]>) {
        getDecodable(SpotifyRelatedArtists.self, path: "/artists/\(artist.id)/related-artists", query: []) { result in
            let artists = result.map { $0.artists }
            completion(artists)
        }
    }
    
    /// - parameter completion: returns array of **full** artist objects
    @available(iOS 13.0, watchOS 6.0, tvOS 13.0, macOS 10.15, *)
    public func getRelatedArtists(for artist: SpotifyArtist) async throws -> [SpotifyArtist] {
        return try await getDecodable(SpotifyRelatedArtists.self, path: "/artists/\(artist.id)/related-artists", query: []).artists
    }
    
    
    // MARK: - Playlist
    
    public func getPlaylist(withID id: String, completion: @escaping Completion<SpotifyPlaylist>) {
        getDecodable(SpotifyPlaylist.self, path: "/playlists/\(id)", query: [], completion: completion)
    }
    
    @available(iOS 13.0, watchOS 6.0, tvOS 13.0, macOS 10.15, *)
    public func getPlaylist(withID id: String) async throws -> SpotifyPlaylist {
        return try await getDecodable(SpotifyPlaylist.self, path: "/playlists/\(id)", query: [])
    }
    
    public func getPlaylistTracks(forID id: String, limit: Int = 100, offset: Int = 0, completion: @escaping Completion<SpotifyPagingResult<SpotifyPlaylist.Track>>) {
        getDecodable(SpotifyPagingResult<SpotifyPlaylist.Track>.self, path: "/playlists/\(id)/tracks", query: [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ], completion: completion)
    }
    
    @available(iOS 13.0, watchOS 6.0, tvOS 13.0, macOS 10.15, *)
    public func getPlaylistTracks(forID id: String, limit: Int = 100, offset: Int = 0) async throws -> SpotifyPagingResult<SpotifyPlaylist.Track> {
        try await withCheckedThrowingContinuation { continuation in
            getPlaylistTracks(forID: id, limit: limit, offset: offset) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    public func getPlaylistTracks(for playlist: SpotifyPlaylist, limit: Int = 100, offset: Int = 0, completion: @escaping Completion<SpotifyPagingResult<SpotifyPlaylist.Track>>) {
        getPlaylistTracks(forID: playlist.id, limit: limit, offset: offset, completion: completion)
    }
    
    @available(iOS 13.0, watchOS 6.0, tvOS 13.0, macOS 10.15, *)
    public func getPlaylistTracks(for playlist: SpotifyPlaylist, limit: Int = 100, offset: Int = 0) async throws -> SpotifyPagingResult<SpotifyPlaylist.Track> {
        return try await getPlaylistTracks(forID: playlist.id, limit: limit, offset: offset)
    }
    
    public func hasPlaylistChanged(withID id: String, etag: String?, completion: @escaping Completion<SpotifyPlaylist.VersionControl>) {
        getDecodableAndEtag(SpotifyPlaylist.VersionControl.MinimalPlaylist.self, path: "/playlists/\(id)", query: [
            URLQueryItem(name: "fields", value: "name,description,snapshot_id")
        ], etag: etag) { result in
            completion(result.map { value, etag in
                return SpotifyPlaylist.VersionControl(id: id, etag: etag, updates: value)
            })
        }
    }
    
    @available(iOS 13.0, watchOS 6.0, tvOS 13.0, macOS 10.15, *)
    public func hasPlaylistChanged(withID id: String, etag: String?) async throws -> SpotifyPlaylist.VersionControl {
        try await withCheckedThrowingContinuation { continuation in
            hasPlaylistChanged(withID: id, etag: etag) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    
    // MARK: - Request Objects
    
    public enum SearchType: String {
        case album
        case artist
        case playlist
        case track
    }
    
    
    // MARK: - Response Objects
    
    struct SpotifyTopTracks: Decodable {
        let tracks: [SpotifyTrack]
    }
    
    struct SpotifyRelatedArtists: Decodable {
        let artists: [SpotifyArtist]
    }
}
