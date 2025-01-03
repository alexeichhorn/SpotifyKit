//
//  SpotifyArtist.swift
//  SpotifyKit
//
//  Created by Alexander Eichhorn on 25.04.20.
//

import Foundation

public struct SpotifyArtist: Codable, Sendable {
    public let id: String
    public let name: String
    public let popularity: Int?
    public let genres: [String]?
    public let images: [SpotifyImage]?
    public let uri: String
}
