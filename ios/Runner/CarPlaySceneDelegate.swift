import CarPlay
import Flutter
import UIKit

@available(iOS 14.0, *)
class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    var interfaceController: CPInterfaceController?

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        setupCarPlayTemplates()
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        self.interfaceController = nil
    }

    private func setupCarPlayTemplates() {
        let exploreTemplate = CPListTemplate(title: "Explore", sections: [])
        exploreTemplate.tabImage = UIImage(systemName: "flame.fill")

        let libraryTemplate = CPListTemplate(title: "Library", sections: [])
        libraryTemplate.tabImage = UIImage(systemName: "music.note.list")

        let tabBar = CPTabBarTemplate(templates: [exploreTemplate, libraryTemplate])
        interfaceController?.setRootTemplate(tabBar, animated: true, completion: nil)

        attachChannelWithRetry(
            exploreTemplate: exploreTemplate,
            libraryTemplate: libraryTemplate,
            attemptsLeft: 8
        )
    }

    private func attachChannelWithRetry(
        exploreTemplate: CPListTemplate,
        libraryTemplate: CPListTemplate,
        attemptsLeft: Int
    ) {
        if let channel = resolveFlutterChannel() {
            populateExplore(channel: channel, template: exploreTemplate)
            populateLibrary(channel: channel, template: libraryTemplate)
            return
        }
        guard attemptsLeft > 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.attachChannelWithRetry(
                exploreTemplate: exploreTemplate,
                libraryTemplate: libraryTemplate,
                attemptsLeft: attemptsLeft - 1
            )
        }
    }

    private func resolveFlutterChannel() -> FlutterMethodChannel? {
        let appDelegate = UIApplication.shared.delegate as? FlutterAppDelegate
        let delegateController = appDelegate?.window?.rootViewController as? FlutterViewController
        let sceneController = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .compactMap { $0.rootViewController as? FlutterViewController }
            .first

        guard let rootController = delegateController ?? sceneController else {
            return nil
        }
        return FlutterMethodChannel(
            name: "com.soniclane.app/carplay",
            binaryMessenger: rootController.binaryMessenger
        )
    }

    private func makeTrackItem(
        from track: [String: Any],
        onSelect: @escaping () -> Void
    ) -> CPListItem {
        let title = track["title"] as? String ?? "Track"
        let artist = track["artist"] as? String ?? "Soniclane"
        let item = CPListItem(text: title, detailText: artist)
        item.handler = { [weak self] _, completion in
            onSelect()
            self?.interfaceController?.pushTemplate(
                CPNowPlayingTemplate.shared,
                animated: true,
                completion: nil
            )
            completion()
        }
        return item
    }

    private func populateExplore(channel: FlutterMethodChannel, template: CPListTemplate) {
        channel.invokeMethod("getTrending", arguments: nil) { [weak self] result in
            guard let self = self, let items = result as? [[String: Any]] else { return }
            let listItems = items.map { track in
                let videoId = track["id"] as? String ?? ""
                return self.makeTrackItem(from: track) {
                    channel.invokeMethod("playTrackById", arguments: videoId)
                }
            }
            DispatchQueue.main.async {
                template.updateSections([CPListSection(items: listItems)])
            }
        }
    }

    private func populateLibrary(channel: FlutterMethodChannel, template: CPListTemplate) {
        let likedItem = CPListItem(text: "Liked Songs", detailText: "Favorites & Offline")
        likedItem.handler = { [weak self] _, completion in
            channel.invokeMethod("getLikedTracks", arguments: nil) { result in
                guard let self = self else { return }
                let tracks = result as? [[String: Any]] ?? []
                let subItems = tracks.map { track in
                    let vid = track["id"] as? String ?? ""
                    return self.makeTrackItem(from: track) {
                        channel.invokeMethod("playTrackById", arguments: vid)
                    }
                }
                DispatchQueue.main.async {
                    let likedList = CPListTemplate(
                        title: "Liked Songs",
                        sections: [CPListSection(items: subItems)]
                    )
                    self.interfaceController?.pushTemplate(likedList, animated: true, completion: nil)
                }
            }
            completion()
        }

        channel.invokeMethod("getPlaylists", arguments: nil) { [weak self] result in
            let playlists = result as? [[String: Any]] ?? []
            let plItems = playlists.map { pl -> CPListItem in
                let plId = pl["id"] as? String ?? ""
                let name = pl["name"] as? String ?? "Hybrid Playlist"
                let count = pl["count"] as? Int ?? 0
                let cpPl = CPListItem(text: name, detailText: "\(count) Hybrid Tracks")
                cpPl.handler = { _, completion in
                    channel.invokeMethod("getPlaylistTracks", arguments: plId) { tracksRes in
                        guard let self = self else { return }
                        let tracks = tracksRes as? [[String: Any]] ?? []
                        let trackItems = tracks.map { track in
                            let vid = track["id"] as? String ?? ""
                            return self.makeTrackItem(from: track) {
                                channel.invokeMethod("playPlaylistTrack", arguments: [
                                    "playlistId": plId,
                                    "trackId": vid
                                ])
                            }
                        }
                        DispatchQueue.main.async {
                            let detail = CPListTemplate(
                                title: name,
                                sections: [CPListSection(items: trackItems)]
                            )
                            self.interfaceController?.pushTemplate(detail, animated: true, completion: nil)
                        }
                    }
                    completion()
                }
                return cpPl
            }
            DispatchQueue.main.async {
                template.updateSections([
                    CPListSection(items: [likedItem], header: "Quick Access", sectionIndexTitle: nil),
                    CPListSection(items: plItems, header: "Hybrid Playlists", sectionIndexTitle: nil)
                ])
            }
        }
    }
}
