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
    var timeObserverToken: Any?

    lazy var playerView: AVPlayerView = {
        let view = AVPlayerView()
        view.backgroundColor = .black
        return view
    }()

    lazy var currentTimeLabel: UILabel = {
        let view = UILabel()
        view.textColor = .white
        view.font = .monospacedSystemFont(ofSize: 16, weight: .regular)
        return view
    }()

    lazy var totalTimeLabel: UILabel = {
        let view = UILabel()
        view.textColor = .white
        view.font = .monospacedSystemFont(ofSize: 16, weight: .regular)
        return view
    }()

    lazy var timeLabelStack: UIStackView = {
        let view = UIStackView(arrangedSubviews: [currentTimeLabel, totalTimeLabel])
        view.axis = .horizontal
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    lazy var controlButton: UIButton = {
        let view = UIButton(type: .custom, primaryAction: UIAction { [weak self] action in
            switch self?.player?.timeControlStatus {
            case .paused:
                self?.resume()

            case .playing:
                self?.pause()

            case .none:
                self?.play()

            default:
                break
            }
        })
        view.setImage(UIImage(systemName: "play.fill"), for: .normal)
        view.tintColor = .white
        view.contentHorizontalAlignment = .fill
        view.contentVerticalAlignment = .fill
        view.imageView?.contentMode = .scaleAspectFit
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private var player: AVPlayer?

    private let timeFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()

    private var playerStatusObservation: NSKeyValueObservation?

    deinit {
        playerStatusObservation?.invalidate()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        request()
        view.addSubview(playerView)
        playerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            playerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            playerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            playerView.heightAnchor.constraint(equalTo: playerView.widthAnchor, multiplier: 9/16),
        ])

        playerView.addSubview(timeLabelStack)
        NSLayoutConstraint.activate([
            timeLabelStack.leadingAnchor.constraint(equalTo: playerView.leadingAnchor, constant: 15),
            timeLabelStack.bottomAnchor.constraint(equalTo: playerView.bottomAnchor),
        ])

        playerView.addSubview(controlButton)
        NSLayoutConstraint.activate([
            controlButton.centerXAnchor.constraint(equalTo: playerView.centerXAnchor),
            controlButton.centerYAnchor.constraint(equalTo: playerView.centerYAnchor),
            controlButton.widthAnchor.constraint(equalToConstant: 45),
            controlButton.heightAnchor.constraint(equalTo: controlButton.widthAnchor),
        ])
    }

    private func request() {
        loader.get { [weak self] in
            self?.url = $0.url
            self?.sampleURL = $0.sampleUrl
            self?.totalLength = $0.totalLength
        }
    }

    private func play() {
        guard let url = URL(string: VideoLoader.Router.base + sampleURL) else { return }

        let playItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playItem)

        playerStatusObservation?.invalidate()
        // KVO에서 NSKeyValueObservedChange<Value>가 제대로 새 값을 가져오지 못하는 버그
        // <https://stackoverflow.com/q/51737607/12353435>
        playerStatusObservation = player?.observe(\.timeControlStatus, options: [.new], changeHandler: { [weak self] player, _ in
            switch player.timeControlStatus {
            case .paused:
                self?.controlButton.setImage(UIImage(systemName: "play.fill"), for: .normal)

            case .playing:
                self?.controlButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)

            default:
                break
            }
        })

        guard let player = player else { return }

        playerView.setPlayer(player: player)
        player.play()

//        if let timeObserverToken = timeObserverToken {
//            player.removeTimeObserver(timeObserverToken)
//        }

        let updateInterval = CMTime(seconds: 1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: updateInterval, queue: .main) { [weak self] time in
            guard player.currentItem?.status == .readyToPlay else { return }

            let currentTimeText: String? = {
                guard let currentTime = player.currentItem?.currentTime().seconds else { return nil }

                return self?.timeFormatter.string(from: currentTime)
            }()

            self?.currentTimeLabel.text = currentTimeText

            let totalTimeText: String? = {
                guard let totalTime = player.currentItem?.duration.seconds else { return nil }

                return self?.timeFormatter.string(from: totalTime)
            }()

            self?.totalTimeLabel.text = "/" + (totalTimeText ?? "")
        }
    }

    private func pause() {
        player?.pause()
    }

    private func resume() {
        player?.play()
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
