//
//  File.swift
//  File
//
//  Created by Alexander Eichhorn on 28.08.21.
//

import Foundation

extension SpotifyPlaylist {
    
    public struct VersionControl {
        public let id: String
        public let etag: String?
        public let updates: MinimalPlaylist?
        
        
        public struct MinimalPlaylist: Decodable {
            let name: String
            let description: String
            let snapshot_id: String
        }
    }
    
}
