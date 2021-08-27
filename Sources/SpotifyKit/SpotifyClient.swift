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
    
    private func get(path: String, query: [URLQueryItem], completion: @escaping (Result<Data, Error>) -> Void) {
        
        authenticationHeader { result in
            switch result {
            case .success(let header):
                let url = self.url(forPath: path, query: query)
                var request = URLRequest(url: url)
                request.allHTTPHeaderFields = header
                
                URLSession.shared.dataTask(with: request) { data, response, error in
                    if let error = error {
                        completion(.failure(error))
                        return
                    }
                    
                    if let data = data {
                        completion(.success(data))
                        return
                    }
                    
                    completion(.failure(RequestError.unknown))
                    
                }.resume()
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
        
    }
    
    private func getDecodable<T: Decodable>(_ type: T.Type, path: String, query: [URLQueryItem], completion: @escaping (Result<T, Error>) -> Void) {
        
        get(path: path, query: query) { result in
            switch result {
            case .success(let data):
                do {
                    let decoded = try JSONDecoder().decode(T.self, from: data)
                    completion(.success(decoded))
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
    
    
    // MARK: - Track
    
    public func getTrack(with id: String, completion: @escaping Completion<SpotifyTrack>) {
        getDecodable(SpotifyTrack.self, path: "/tracks/\(id)", query: [], completion: completion)
    }
    
    public func getTrackDetails(for track: SpotifyTrack, completion: @escaping Completion<SpotifyTrack>) {
        getTrack(with: track.id, completion: completion)
    }
    
    /// - parameter ids: maximum 50 ids accepted
    public func getTracks(with ids: [String], completion: @escaping Completion<[SpotifyTrack]>) {
        getDecodable(SpotifyTopTracks.self, path: "/tracks", query: [
            URLQueryItem(name: "ids", value: ids.joined(separator: ","))
        ]) { result in
            completion(result.map { $0.tracks })
        }
    }
    
    /// - parameter tracks: maximum 50 tracks accepted
    public func getMultipleTrackDetails(for tracks: [SpotifyTrack], completion: @escaping Completion<[SpotifyTrack]>) {
        getTracks(with: tracks.map { $0.id }, completion: completion)
    }
    
    
    // MARK: - Album
    
    public func getAlbum(withID id: String, completion: @escaping (Result<SpotifyAlbum, Error>) -> Void) {
        getDecodable(SpotifyAlbum.self, path: "/albums/\(id)", query: [], completion: completion)
    }
    
    /// load missing values
    public func getAlbumDetails(for album: SpotifyAlbum, completion: @escaping (Result<SpotifyAlbum, Error>) -> Void) {
        getAlbum(withID: album.id, completion: completion)
    }
    
    
    // MARK: - Artist
    
    public func getArtist(withID id: String, completion: @escaping (Result<SpotifyArtist, Error>) -> Void) {
        getDecodable(SpotifyArtist.self, path: "/artists/\(id)", query: [], completion: completion)
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
    
    /// - parameter completion: returns array of **full** track objects
    public func getTopTracks(for artist: SpotifyArtist, completion: @escaping Completion<[SpotifyTrack]>) {
        getDecodable(SpotifyTopTracks.self, path: "/artists/\(artist.id)/top-tracks", query: []) { result in
            let tracks = result.map { $0.tracks }
            completion(tracks)
        }
    }
    
    /// - parameter completion: returns array of **full** artist objects
    public func getRelatedArtists(for artist: SpotifyArtist, completion: @escaping Completion<[SpotifyArtist]>) {
        getDecodable(SpotifyRelatedArtists.self, path: "/artists/\(artist.id)/related-artists", query: []) { result in
            let artists = result.map { $0.artists }
            completion(artists)
        }
    }
    
    
    // MARK: - Playlist
    
    public func getPlaylist(withID id: String, completion: @escaping Completion<SpotifyPlaylist>) {
        getDecodable(SpotifyPlaylist.self, path: "/playlists/\(id)", query: [], completion: completion)
    }
    
    public func getPlaylistTracks(forID id: String, limit: Int = 100, offset: Int = 0, completion: @escaping Completion<SpotifyPagingResult<SpotifyPlaylist.Track>>) {
        getDecodable(SpotifyPagingResult<SpotifyPlaylist.Track>.self, path: "/playlists/\(id)/tracks", query: [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ], completion: completion)
    }
    
    public func getPlaylistTracks(for playlist: SpotifyPlaylist, limit: Int = 100, offset: Int = 0, completion: @escaping Completion<SpotifyPagingResult<SpotifyPlaylist.Track>>) {
        getPlaylistTracks(forID: playlist.id, limit: limit, offset: offset, completion: completion)
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
