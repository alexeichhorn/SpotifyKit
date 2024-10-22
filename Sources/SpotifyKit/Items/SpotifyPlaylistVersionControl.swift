//
//  File.swift
//  File
//
//  Created by Alexander Eichhorn on 28.08.21.
//

import Foundation

extension SpotifyPlaylist {
    
    public struct VersionControl: Sendable {
        public let id: String
        public let etag: String?
        public let updates: MinimalPlaylist?
        
        
        public struct MinimalPlaylist: Decodable, Sendable {
            public let name: String
            public let description: String
            public let snapshot_id: String
        }
    }
    
}
