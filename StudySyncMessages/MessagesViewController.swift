import UIKit
import Messages
import SwiftData

/// iMessage Extension - Generates countdown stickers from user events.
/// To use: Create a Messages Extension target in Xcode, add App Group,
/// and share CountdownEvent model files with this target.
class MessagesViewController: MSMessagesAppViewController {

    private var stickerBrowserVC: StickerBrowserViewController?

    override func viewDidLoad() {
        super.viewDidLoad()

        let browserVC = StickerBrowserViewController()
        addChild(browserVC)
        view.addSubview(browserVC.view)
        browserVC.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            browserVC.view.topAnchor.constraint(equalTo: view.topAnchor),
            browserVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            browserVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            browserVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        browserVC.didMove(toParent: self)
        stickerBrowserVC = browserVC
    }
}

// MARK: - Sticker Browser

class StickerBrowserViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    private var collectionView: UICollectionView!
    private var stickers: [(title: String, emoji: String, days: Int, unit: String, colorHex: String)] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        loadEvents()
        setupCollectionView()
    }

    private func loadEvents() {
        // Load events from App Group shared SwiftData
        // This requires the same App Group as the main app
        let container = SharedModelContainer.create()
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<CountdownEvent>()

        if let events = try? context.fetch(descriptor) {
            stickers = events
                .filter { !$0.isExpired }
                .sorted { $0.primaryCount < $1.primaryCount }
                .map { (title: $0.title, emoji: $0.emoji, days: $0.primaryCount, unit: $0.unitLabel, colorHex: $0.colorHex) }
        }
    }

    private func setupCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 150, height: 80)
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        layout.sectionInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(StickerCell.self, forCellWithReuseIdentifier: "StickerCell")

        view.addSubview(collectionView)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        stickers.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "StickerCell", for: indexPath) as? StickerCell else {
            return collectionView.dequeueReusableCell(withReuseIdentifier: "StickerCell", for: indexPath)
        }
        let sticker = stickers[indexPath.item]
        cell.configure(emoji: sticker.emoji, title: sticker.title, days: sticker.days, unit: sticker.unit, colorHex: sticker.colorHex)
        return cell
    }
}

// MARK: - Sticker Cell

class StickerCell: UICollectionViewCell {
    private let emojiLabel = UILabel()
    private let titleLabel = UILabel()
    private let daysLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        contentView.layer.cornerRadius = 12
        contentView.clipsToBounds = true

        emojiLabel.font = .systemFont(ofSize: 24)
        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = .white
        daysLabel.font = .systemFont(ofSize: 11, weight: .medium)
        daysLabel.textColor = .white.withAlphaComponent(0.8)

        let stack = UIStackView(arrangedSubviews: [emojiLabel, titleLabel, daysLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 2

        contentView.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    func configure(emoji: String, title: String, days: Int, unit: String, colorHex: String) {
        emojiLabel.text = emoji
        titleLabel.text = title
        daysLabel.text = "\(days) \(unit)"

        // Parse hex color
        let hex = colorHex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        contentView.backgroundColor = UIColor(
            red: CGFloat((int >> 16) & 0xFF) / 255,
            green: CGFloat((int >> 8) & 0xFF) / 255,
            blue: CGFloat(int & 0xFF) / 255,
            alpha: 1
        )
    }
}
