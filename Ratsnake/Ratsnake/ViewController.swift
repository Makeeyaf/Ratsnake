//
//  ViewController.swift
//  Ratsnake
//
//  Created by Makeeyaf on 2021/09/22.
//

import UIKit
import AVKit

protocol PurchaseDelegate: AnyObject {
    func didPurchased()
}

final class ViewController: UIViewController {

    // MARK: - Views

    lazy var playerView: AVPlayerView = {
        let view = AVPlayerView()
        view.backgroundColor = .black
        view.translatesAutoresizingMaskIntoConstraints = false

        let leftSwipeGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(playerViewDidSwiped(_:)))
        leftSwipeGestureRecognizer.direction = .left
        view.addGestureRecognizer(leftSwipeGestureRecognizer)

        let rightSwipeGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(playerViewDidSwiped(_:)))
        rightSwipeGestureRecognizer.direction = .right
        view.addGestureRecognizer(rightSwipeGestureRecognizer)

        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(overlayDidTapped(_:)))
        tapGestureRecognizer.requiresExclusiveTouchType = true
        view.addGestureRecognizer(tapGestureRecognizer)

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

    lazy var purchaseView: PurchaseView = {
        let view = PurchaseView()
        view.delegate = self
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
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
                guard let sampleURL = self?.sampleURL, let url = URL(string: VideoLoader.Router.base + sampleURL) else { return }

                self?.play(url: url)

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

    lazy var seekBarView: SeekBarView = {
        let view = SeekBarView()
        view.thumbColor = .white
        view.barColor = .gray
        view.elapsedBarColor = .systemGray5
        view.translatesAutoresizingMaskIntoConstraints = false

        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(seekBarDidPanned(_:)))
        view.addGestureRecognizer(panGestureRecognizer)
        return view
    }()

    lazy var overlayContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    // MARK: - Properties

    private let loader = VideoLoader()
    private let timeFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()

    private var player: AVPlayer?
    private var playerStatusObservation: NSKeyValueObservation?
    private var playerItemDidPlayToEndTimeObserver: NSObjectProtocol?
    private var hideOverlayWorkItem: DispatchWorkItem?
    private var url: String?
    private var sampleURL: String?
    private var totalLength: Double = 0
    private var timeObserverToken: Any?
    private var isSeekBarEditing: Bool = false
    private var isPurchased: Bool = false {
        didSet {
            if isPurchased {
                UIView.animate(withDuration: 0.3) {
                    self.purchaseView.alpha = 0
                } completion: { _ in
                    self.purchaseView.isHidden = true
                }
            } else {
                purchaseView.alpha = 0
                purchaseView.isHidden = false

                UIView.animate(withDuration: 0.3) {
                    self.purchaseView.alpha = 1
                }
            }

        }
    }

    // MARK: - Lifecyles

    deinit {
        playerStatusObservation?.invalidate()

        if let playerItemDidPlayToEndTimeObserver = playerItemDidPlayToEndTimeObserver {
            NotificationCenter.default.removeObserver(playerItemDidPlayToEndTimeObserver)
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        coordinator.animate { _ in
            self.seekBarView.layoutIfNeeded()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setViews()
        setConstraints()

        request()

        playerItemDidPlayToEndTimeObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: .main) { [weak self] _ in
            guard let self = self, !self.isPurchased, self.purchaseView.isHidden else { return }

            self.purchaseView.alpha = 0
            self.purchaseView.isHidden = false

            UIView.animate(withDuration: 0.3) {
                self.purchaseView.alpha = 1
            }
        }
    }

    // MARK: - methods

    private func setViews() {
        view.addSubview(playerView)
        playerView.addSubview(overlayContainer)
        overlayContainer.addSubview(controlButton)
        overlayContainer.addSubview(seekBarView)
        overlayContainer.addSubview(timeLabelStack)
        playerView.addSubview(purchaseView)
    }

    private func setConstraints() {
        NSLayoutConstraint.activate([
            playerView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            playerView.topAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.topAnchor),
            playerView.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor),
            playerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            playerView.heightAnchor.constraint(equalTo: playerView.widthAnchor, multiplier: 9/16),
        ])

        NSLayoutConstraint.activate([
            overlayContainer.leadingAnchor.constraint(equalTo: playerView.leadingAnchor),
            overlayContainer.trailingAnchor.constraint(equalTo: playerView.trailingAnchor),
            overlayContainer.topAnchor.constraint(equalTo: playerView.topAnchor),
            overlayContainer.bottomAnchor.constraint(equalTo: playerView.bottomAnchor),
        ])

        NSLayoutConstraint.activate([
            controlButton.centerXAnchor.constraint(equalTo: overlayContainer.centerXAnchor),
            controlButton.centerYAnchor.constraint(equalTo: overlayContainer.centerYAnchor),
            controlButton.widthAnchor.constraint(equalToConstant: 45),
            controlButton.heightAnchor.constraint(equalTo: controlButton.widthAnchor),
        ])

        NSLayoutConstraint.activate([
            seekBarView.leadingAnchor.constraint(equalTo: overlayContainer.leadingAnchor, constant: 15),
            seekBarView.trailingAnchor.constraint(equalTo: overlayContainer.trailingAnchor, constant: -15),
            seekBarView.bottomAnchor.constraint(equalTo: overlayContainer.bottomAnchor, constant: -15),
        ])

        NSLayoutConstraint.activate([
            timeLabelStack.leadingAnchor.constraint(equalTo: seekBarView.leadingAnchor),
            timeLabelStack.bottomAnchor.constraint(equalTo: seekBarView.topAnchor, constant: -4),
        ])

        NSLayoutConstraint.activate([
            purchaseView.leadingAnchor.constraint(equalTo: playerView.leadingAnchor),
            purchaseView.trailingAnchor.constraint(equalTo: playerView.trailingAnchor),
            purchaseView.topAnchor.constraint(equalTo: playerView.topAnchor),
            purchaseView.bottomAnchor.constraint(equalTo: playerView.bottomAnchor),
        ])
    }

    private func cancelHideOverlayWork() {
        guard hideOverlayWorkItem?.isCancelled == false else { return }

        hideOverlayWorkItem?.cancel()
    }

    private func delayHideOverlayWork(isRenewable: Bool) {
        if isRenewable {
            cancelHideOverlayWork()
        } else {
            guard hideOverlayWorkItem?.isCancelled == false else { return }

            hideOverlayWorkItem?.cancel()
        }

        hideOverlayWorkItem = DispatchWorkItem {
            guard !self.overlayContainer.isHidden else { return }

            self.hideOverlay()
        }

        guard let hideOverlayWorkItem = hideOverlayWorkItem else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3), execute: hideOverlayWorkItem)
    }

    private func showOverlay() {
        overlayContainer.alpha = 0
        overlayContainer.isHidden = false

        UIView.animate(withDuration: 0.25) {
            self.overlayContainer.alpha = 1
        }
    }

    private func hideOverlay() {
        UIView.animate(withDuration: 0.25) {
            self.overlayContainer.alpha = 0
        } completion: { _ in
            self.overlayContainer.isHidden = true
        }
    }

    private func request() {
        loader.get { [weak self] in
            self?.url = $0.url
            self?.sampleURL = $0.sampleUrl
            self?.totalLength = $0.totalLength
        }
    }

    private func play(url: URL) {
        let playItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playItem)

        playerStatusObservation?.invalidate()
        // KVO에서 NSKeyValueObservedChange<Value>가 제대로 새 값을 가져오지 못하는 버그
        // <https://stackoverflow.com/q/51737607/12353435>
        playerStatusObservation = player?.observe(\.timeControlStatus, options: [.new], changeHandler: { [weak self] player, _ in
            switch player.timeControlStatus {
            case .paused:
                self?.controlButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
                self?.cancelHideOverlayWork()
                if self?.overlayContainer.isHidden == true {
                    self?.showOverlay()
                }

            case .playing:
                self?.controlButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
                self?.delayHideOverlayWork(isRenewable: true)

            default:
                break
            }
        })

        guard let player = player else { return }

        playerView.setPlayer(player: player)
        player.play()

        totalTimeLabel.text = "/" + (timeFormatter.string(from: totalLength) ?? "")

        let updateInterval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: updateInterval, queue: .main) { [weak self] time in
            guard player.currentItem?.status == .readyToPlay else { return }

            guard let currentTime = player.currentItem?.currentTime().seconds,
                  let totalLength = self?.totalLength
            else { return }

            if self?.isSeekBarEditing == false {
                self?.seekBarView.progress = max(0, currentTime / totalLength)
            }

            self?.currentTimeLabel.text = self?.timeFormatter.string(from: currentTime)
        }
    }

    private func pause() {
        player?.pause()
    }

    private func resume() {
        player?.play()
    }

    // MARK: - Actions

    @objc private func overlayDidTapped(_ sender: UITapGestureRecognizer) {
        guard let status = player?.timeControlStatus, status != .paused else { return }

        if overlayContainer.isHidden {
            showOverlay()
            delayHideOverlayWork(isRenewable: false)
        } else {
            hideOverlay()
            cancelHideOverlayWork()
        }
    }

    @objc private func playerViewDidSwiped(_ sender: UISwipeGestureRecognizer) {
        guard let player = player,
              let current = player.currentItem?.currentTime().seconds,
              let duration = player.currentItem?.duration
        else { return }

        let delta: Double = (sender.direction == .left) ? -5 : 5

        player.seek(to: CMTime(seconds: min(max(current + delta, 0), duration.seconds), preferredTimescale: duration.timescale))

        if overlayContainer.isHidden {
            showOverlay()
        }
        delayHideOverlayWork(isRenewable: false)
    }

    @objc private func seekBarDidPanned(_ sender: UIPanGestureRecognizer) {
        guard let player = player, let duration = player.currentItem?.duration else { return }

        let x: CGFloat = min(max(0, sender.location(in: seekBarView).x), seekBarView.bounds.width)
        let progress: CGFloat = x / seekBarView.bounds.width

        seekBarView.progress = progress

        switch sender.state {
        case .began:
            isSeekBarEditing = true
            cancelHideOverlayWork()

        case .ended:
            let seekTime = floor(min(duration.seconds, totalLength * progress))
            player.seek(to: CMTime(seconds: seekTime, preferredTimescale: duration.timescale))
            isSeekBarEditing = false
            delayHideOverlayWork(isRenewable: false)

        default:
            return
        }
    }
}

// MARK: - PurchaseDelegate

extension ViewController: PurchaseDelegate {
    func didPurchased() {
        guard let url = url, let url = URL(string: VideoLoader.Router.base + url) else { return }

        let currentTime: CMTime? = player?.currentTime()

        play(url: url)

        if let currentTime = currentTime {
            player?.seek(to: currentTime)
        }
        isPurchased = true
    }
}

// MARK: - Nested Classes

extension ViewController {

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

    final class SeekBarView: UIView {
        private lazy var barView: UIView = {
            let view = UIView()
            view.translatesAutoresizingMaskIntoConstraints = false
            return view
        }()

        private lazy var elapsedBarView: UIView = {
            let view = UIView()
            view.translatesAutoresizingMaskIntoConstraints = false
            return view
        }()

        private lazy var thumbView: UIView = {
            let view = UIView()
            view.translatesAutoresizingMaskIntoConstraints = false
            view.layer.cornerRadius = 0.5 * thumbDiameter
            return view
        }()

        var elapsedBarColor: UIColor? {
            get { elapsedBarView.backgroundColor }
            set { elapsedBarView.backgroundColor = newValue }
        }

        var barColor: UIColor? {
            get { barView.backgroundColor }
            set { barView.backgroundColor = newValue }
        }

        var barThickness: CGFloat = 4 {
            didSet {
                barThicknessConstraints?.constant = barThickness
            }
        }

        var thumbColor: UIColor? {
            get { thumbView.backgroundColor }
            set { thumbView.backgroundColor = newValue }
        }

        var thumbDiameter: CGFloat = 10 {
            didSet {
                thumbDiameterConstraints?.constant = thumbDiameter
                thumbView.layer.cornerRadius = 0.5 * thumbDiameter
            }
        }

        var progress: CGFloat {
            get { _progress }
            set {
                switch newValue {
                case ..<0:
                    _progress = 0

                case 1...:
                    _progress = 1

                default:
                    _progress = newValue
                }

                thumbPositionConstraints?.constant = _progress * barView.bounds.width
            }
        }

        private var _progress: CGFloat = 0

        private var barThicknessConstraints: NSLayoutConstraint?
        private var thumbDiameterConstraints: NSLayoutConstraint?
        private var thumbPositionConstraints: NSLayoutConstraint?

        override init(frame: CGRect) {
            super.init(frame: frame)
            setViews()
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
            setViews()
        }

        override func layoutIfNeeded() {
            super.layoutIfNeeded()

            if let constant = thumbPositionConstraints?.constant, constant != _progress * barView.bounds.width {
                thumbPositionConstraints?.constant = _progress * barView.bounds.width
            }
        }

        private func setViews() {
            addSubview(barView)
            addSubview(elapsedBarView)
            addSubview(thumbView)

            barThicknessConstraints = barView.heightAnchor.constraint(equalToConstant: barThickness)
            barThicknessConstraints?.isActive = true
            NSLayoutConstraint.activate([
                barView.leftAnchor.constraint(equalTo: leftAnchor),
                barView.rightAnchor.constraint(equalTo: rightAnchor),
                barView.centerYAnchor.constraint(equalTo: centerYAnchor),
            ])

            thumbPositionConstraints = thumbView.leftAnchor.constraint(equalTo: barView.leftAnchor)
            thumbPositionConstraints?.isActive = true
            thumbDiameterConstraints = thumbView.widthAnchor.constraint(equalToConstant: thumbDiameter)
            thumbDiameterConstraints?.isActive = true
            NSLayoutConstraint.activate([
                thumbView.topAnchor.constraint(equalTo: topAnchor),
                thumbView.bottomAnchor.constraint(equalTo: bottomAnchor),
                thumbView.centerYAnchor.constraint(equalTo: barView.centerYAnchor),
                thumbView.heightAnchor.constraint(equalTo: thumbView.widthAnchor),
            ])

            NSLayoutConstraint.activate([
                elapsedBarView.leftAnchor.constraint(equalTo: barView.leftAnchor),
                elapsedBarView.centerYAnchor.constraint(equalTo: barView.centerYAnchor),
                elapsedBarView.heightAnchor.constraint(equalTo: barView.heightAnchor),
                elapsedBarView.rightAnchor.constraint(equalTo: thumbView.centerXAnchor),
            ])
        }
    }

    final class PurchaseView: UIView {
        private lazy var titleLabel: UILabel = {
            let view = UILabel()
            view.translatesAutoresizingMaskIntoConstraints = false
            view.text = "Press button to unlock contents."
            view.font = .systemFont(ofSize: 24)
            view.textColor = .lightText
            return view
        }()

        private lazy var purchaseButton: UIButton = {
            let view = UIButton(type: .custom, primaryAction: UIAction(handler: { [weak self] _ in
                self?.delegate?.didPurchased()
            }))

            var configuration: UIButton.Configuration = .filled()
            configuration.title = "Unlock"
            configuration.baseForegroundColor = .lightText
            configuration.buttonSize = .large

            view.configuration = configuration
            view.translatesAutoresizingMaskIntoConstraints = false
            return view
        }()

        var delegate: PurchaseDelegate?

        override init(frame: CGRect) {
            super.init(frame: frame)
            setViews()
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
            setViews()
        }

        private func setViews() {
            backgroundColor = .black.withAlphaComponent(0.75)

            addSubview(titleLabel)
            addSubview(purchaseButton)

            NSLayoutConstraint.activate([
                titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 30),
                titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
                titleLabel.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor),
            ])

            NSLayoutConstraint.activate([
                purchaseButton.centerXAnchor.constraint(equalTo: centerXAnchor),
                purchaseButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            ])
        }
    }
}
