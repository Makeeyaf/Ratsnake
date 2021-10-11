//
//  VideoLoader.swift
//  Ratsnake
//
//  Created by Makeeyaf on 2021/10/11.
//

import Foundation

struct VideoLoader {
    enum Router: String {
        static let base: String = "http://localhost:8000"
        case video = "/api/get_video"

        var url: URL? {
            URL(string: Self.base + rawValue)
        }
    }

    var session = URLSession.shared

    func get(_ completionHandler: @escaping (VideoResponse) -> Void) {
        guard let url = Router.video.url else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                print(error)
                return
            }

            guard let data = data else {
                print("data is empty")
                return
            }

            do {

                let decodedData = try JSONDecoder().decode(VideoResponse.self, from: data)
                completionHandler(decodedData)
            } catch {
                print(error)
            }
        }

        task.resume()
    }
}
