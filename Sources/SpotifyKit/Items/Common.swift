//
//  File.swift
//  
//
//  Created by Alexander Eichhorn on 25.04.20.
//

import Foundation

extension SpotifyClient {
    
    public enum Market: String {
        case ch
        case de
        case us
    }
    
}


public struct SpotifyImage: Codable {
    public let height: Int?
    public let width: Int?
    public let url: String
}


public enum SpotifyExternalID: String, Codable {
    case isrc
    case ean
    case upc
}


public struct SpotifyPublicUser: Codable {
    public let id: String
    public let display_name: String
    public let images: [SpotifyImage]?
    public let followers: SpotifyFollowers?
    public let uri: String
}


public struct SpotifyFollowers: Codable {
    public let total: Int
}
