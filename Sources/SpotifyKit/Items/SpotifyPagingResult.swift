//
//  File.swift
//  
//
//  Created by Alexander Eichhorn on 25.04.20.
//

import Foundation

public struct SpotifyPagingResult<Item: Codable>: Codable {
    public let items: [Item]
    public let limit: Int
    public let offset: Int
    public let total: Int
}
