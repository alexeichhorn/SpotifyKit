//
//  File.swift
//  
//
//  Created by Alexander Eichhorn on 25.04.20.
//

import Foundation

public struct SpotifyAlbum: Decodable {
    public let id: String
    public let name: String
    public let album_type: AlbumType
    public let artists: [SpotifyArtist] // simple version
    public let images: [SpotifyImage]
    public let release_date: String?
    public let release_date_precision: String?
    public let uri: String
    
    // extended object
    public let external_ids: [String: String]?
    public let genres: [String]?
    public let label: String?
    public let popularity: Int?
    public let tracks: SpotifyPagingResult<SpotifyTrack>?
}

extension SpotifyAlbum {
    
    public enum AlbumType: String, Decodable {
        case album
        case single
        case compilation
    }
    
    public var releaseYear: String? {
        release_date?.components(separatedBy: "-").first
    }
}
