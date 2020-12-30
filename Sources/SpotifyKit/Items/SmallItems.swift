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


public struct SpotifyImage: Decodable {
    public let height: Int
    public let width: Int
    public let url: String
}


public enum SpotifyExternalID: String, Decodable {
    case isrc
    case ean
    case upc
}
