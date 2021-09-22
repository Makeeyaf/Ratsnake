//
//  ViewController.swift
//  Ratsnake
//
//  Created by Makeeyaf on 2021/09/22.
//

import UIKit
import AVKit

final class ViewController: UIViewController {
    let loader = VideoLoader()
    var url: String = ""
    var sampleURL: String = ""
    var totalLength: Float = 0

    lazy var playButton: UIButton = {
        let view = UIButton(type: .system)
        view.setTitle("Play", for: .normal)
        view.addTarget(self, action: #selector(play), for: .touchUpInside)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    lazy var playerView = AVPlayerView()

    override func viewDidLoad() {
        super.viewDidLoad()
        request()
        view.addSubview(playerView)
        playerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            playerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            playerView.topAnchor.constraint(equalTo: view.topAnchor),
            playerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        view.addSubview(playButton)
        NSLayoutConstraint.activate([
            playButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            playButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
    }

    private func request() {
        loader.get { [weak self] in
            self?.url = $0.url
            self?.sampleURL = $0.sampleUrl
            self?.totalLength = $0.totalLength
        }
    }

    @objc private func play() {
        guard let url = URL(string: VideoLoader.Router.base + sampleURL) else { return }

        let playItem = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: playItem)
        playerView.setPlayer(player: player)
        player.play()
    }
}

final class AVPlayerView : UIView {
    override public class var layerClass: Swift.AnyClass {
        get {
            return AVPlayerLayer.self
        }
    }

    private var playerLayer: AVPlayerLayer {
        return self.layer as! AVPlayerLayer
    }

    func player() -> AVPlayer {
        return playerLayer.player!
    }

    func setPlayer(player: AVPlayer) {
        playerLayer.player = player
    }

    func setVideoFillMode(mode: AVLayerVideoGravity) {
        playerLayer.videoGravity = mode
    }

    func videoFillMode() -> AVLayerVideoGravity {
        return playerLayer.videoGravity
    }
}

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

struct VideoResponse: Codable {
    let url: String
    let sampleUrl: String
    let totalLength: Float
}

enum VideoError: Error {
    case invalidURL
}
