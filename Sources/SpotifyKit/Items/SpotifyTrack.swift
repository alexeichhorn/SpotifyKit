//
//  File.swift
//  
//
//  Created by Alexander Eichhorn on 25.04.20.
//

import Foundation

public struct SpotifyTrack: Codable {
    public let id: String
    public let name: String
    public let popularity: Int?
    public let duration_ms: Int
    public let track_number: Int
    public let disc_number: Int
    public let explicit: Bool
    public let artists: [SpotifyArtist] // simple
    public let album: SpotifyAlbum?
    public let external_ids: [String: String]?
    public let uri: String
}
