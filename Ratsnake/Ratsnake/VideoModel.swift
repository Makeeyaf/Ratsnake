//
//  VideoModel.swift
//  Ratsnake
//
//  Created by Makeeyaf on 2021/10/11.
//

import Foundation

enum VideoError: Error {
    case invalidURL
}

struct VideoResponse: Codable {
    let url: String
    let sampleUrl: String
    let totalLength: Double
}
