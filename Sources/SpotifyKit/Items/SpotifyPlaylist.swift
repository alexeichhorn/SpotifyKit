//
//  SpotifyPlaylist.swift
//  SpotifyPlaylist
//
//  Created by Alexander Eichhorn on 23.08.21.
//

import Foundation

public struct SpotifyPlaylist: Codable {
    public let id: String
    public let name: String
    public let owner: SpotifyPublicUser
    public let `public`: Bool?
    public let collaborative: Bool
    public let description: String
    public let followers: SpotifyFollowers?
    public let images: [SpotifyImage]
    public let snapshot_id: String
    public let tracks: TracksReference
    public let uri: String
}

extension SpotifyPlaylist {
    
    public struct TracksReference: Codable {
        public let href: String
        public let total: Int
    }
    
    public struct Track: Codable {
        public let added_at: String
        public let track: SpotifyTrack?
    }
    
}
