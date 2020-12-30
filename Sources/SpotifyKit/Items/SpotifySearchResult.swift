//
//  File.swift
//  
//
//  Created by Alexander Eichhorn on 25.04.20.
//

import Foundation

public struct SpotifySearchResult: Decodable {
    public let tracks: SpotifyPagingResult<SpotifyTrack>?
    public let albums: SpotifyPagingResult<SpotifyAlbum>?
    public let artists: SpotifyPagingResult<SpotifyArtist>?
}
