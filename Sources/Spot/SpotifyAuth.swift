import AppKit
import AuthenticationServices
import CryptoKit
import Foundation

struct PlaybackState {
    let trackName: String
    let artistName: String
    let artworkURL: URL?
    let isPlaying: Bool
    let volume: Int
    let trackID: String
}

protocol SpotifyAuthProviding: AnyObject {
    var isAuthenticated: Bool { get }
    func checkIfLiked(trackID: String) async -> Bool
    func saveTrack(trackID: String) async -> Bool
    func removeTrack(trackID: String) async -> Bool
    func getCurrentPlayback() async -> PlaybackState?
    func play() async
    func pause() async
    func nextTrack() async
    func previousTrack() async
    func setVolume(_ percent: Int) async
}

@Observable
final class SpotifyAuth: NSObject, ASWebAuthenticationPresentationContextProviding, SpotifyAuthProviding {
    // MARK: - Configuration
    private static let redirectURI = "spot-app://callback"
    private static let scopes = "user-read-playback-state user-modify-playback-state user-read-currently-playing user-library-read user-library-modify"
    private static let tokenURL = "https://accounts.spotify.com/api/token"
    private static let authorizeURL = "https://accounts.spotify.com/authorize"

    // MARK: - State
    private(set) var clientID: String?
    var hasClientID: Bool { !(clientID?.trimmingCharacters(in: .whitespaces).isEmpty ?? true) }
    var isAuthenticated: Bool { accessToken != nil }
    private var accessToken: String?
    private var refreshToken: String?
    private var tokenExpiry: Date?
    private var codeVerifier: String?
    private var authSession: ASWebAuthenticationSession?

    // MARK: - Keys
    // Bump this when scopes or auth requirements change to force re-authorization
    private static let authVersion = 5

    private enum StorageKey {
        static let clientID = "spotifyClientID"
        static let accessToken = "spotifyAccessToken"
        static let refreshToken = "spotifyRefreshToken"
        static let tokenExpiry = "spotifyTokenExpiry"
        static let authVersion = "spotifyAuthVersion"
    }

    override init() {
        super.init()
        clientID = UserDefaults.standard.string(forKey: StorageKey.clientID)
        if UserDefaults.standard.integer(forKey: StorageKey.authVersion) < Self.authVersion {
            // Auth version changed — clear stale tokens and force re-authorization
            UserDefaults.standard.removeObject(forKey: StorageKey.accessToken)
            UserDefaults.standard.removeObject(forKey: StorageKey.refreshToken)
            UserDefaults.standard.removeObject(forKey: StorageKey.tokenExpiry)
            UserDefaults.standard.set(Self.authVersion, forKey: StorageKey.authVersion)
        } else {
            accessToken = UserDefaults.standard.string(forKey: StorageKey.accessToken)
            refreshToken = UserDefaults.standard.string(forKey: StorageKey.refreshToken)
            if let expiry = UserDefaults.standard.object(forKey: StorageKey.tokenExpiry) as? Date {
                tokenExpiry = expiry
            }
        }
    }

    // MARK: - ASWebAuthenticationPresentationContextProviding

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first ?? ASPresentationAnchor()
    }

    // MARK: - Authorization

    func authorize() {
        guard let clientID, hasClientID else { return }

        let verifier = generateCodeVerifier()
        codeVerifier = verifier
        let challenge = generateCodeChallenge(from: verifier)

        var components = URLComponents(string: Self.authorizeURL)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: Self.redirectURI),
            URLQueryItem(name: "scope", value: Self.scopes),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "show_dialog", value: "true"),
        ]

        guard let url = components.url else { return }

        if Bundle.main.bundlePath.hasSuffix(".app") {
            // Running from .app bundle — URL scheme is registered via Info.plist
            NSWorkspace.shared.open(url)
        } else {
            // Running via swift run — use auth session to handle callback
            let session = ASWebAuthenticationSession(
                url: url, callbackURLScheme: "spot-app"
            ) { [weak self] callbackURL, error in
                guard let callbackURL, error == nil else { return }
                self?.handleCallback(url: callbackURL)
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            session.start()
            authSession = session
        }
    }

    func handleCallback(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
            let verifier = codeVerifier
        else {
            return
        }

        exchangeCode(code, verifier: verifier)
    }

    func disconnect() {
        accessToken = nil
        refreshToken = nil
        tokenExpiry = nil
        codeVerifier = nil
        authSession = nil
        clientID = nil
        UserDefaults.standard.removeObject(forKey: StorageKey.accessToken)
        UserDefaults.standard.removeObject(forKey: StorageKey.refreshToken)
        UserDefaults.standard.removeObject(forKey: StorageKey.tokenExpiry)
        UserDefaults.standard.removeObject(forKey: StorageKey.clientID)
    }

    func setClientID(_ newID: String) {
        let trimmed = newID.trimmingCharacters(in: .whitespaces)
        let oldID = clientID
        clientID = trimmed.isEmpty ? nil : trimmed
        UserDefaults.standard.set(clientID, forKey: StorageKey.clientID)
        if oldID != nil && oldID != clientID {
            disconnect()
        }
    }

    // MARK: - Playback API

    func getCurrentPlayback() async -> PlaybackState? {
        guard let token = await validToken() else { return nil }

        var request = URLRequest(
            url: URL(string: "https://api.spotify.com/v1/me/player/currently-playing")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1

            // 204 = no active playback
            guard status == 200 else { return nil }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                let isPlaying = json["is_playing"] as? Bool,
                let item = json["item"] as? [String: Any],
                let name = item["name"] as? String,
                let uri = item["uri"] as? String
            else {
                return nil
            }

            let artists = item["artists"] as? [[String: Any]]
            let artistName = artists?.first?["name"] as? String ?? ""

            var artworkURL: URL?
            if let album = item["album"] as? [String: Any],
                let images = album["images"] as? [[String: Any]],
                let first = images.first,
                let urlStr = first["url"] as? String
            {
                artworkURL = URL(string: urlStr)
            }

            // Extract track ID from URI (spotify:track:XXXX)
            let trackID = uri.replacingOccurrences(of: "spotify:track:", with: "")

            // Get volume from device info
            var volume = 50
            if let device = json["device"] as? [String: Any],
                let vol = device["volume_percent"] as? Int
            {
                volume = vol
            }

            return PlaybackState(
                trackName: name,
                artistName: artistName,
                artworkURL: artworkURL,
                isPlaying: isPlaying,
                volume: volume,
                trackID: trackID
            )
        } catch {
            return nil
        }
    }

    func play() async {
        await playerRequest(method: "PUT", path: "/v1/me/player/play")
    }

    func pause() async {
        await playerRequest(method: "PUT", path: "/v1/me/player/pause")
    }

    func nextTrack() async {
        await playerRequest(method: "POST", path: "/v1/me/player/next")
    }

    func previousTrack() async {
        await playerRequest(method: "POST", path: "/v1/me/player/previous")
    }

    func setVolume(_ percent: Int) async {
        let clamped = max(0, min(100, percent))
        await playerRequest(method: "PUT", path: "/v1/me/player/volume?volume_percent=\(clamped)")
    }

    private func playerRequest(method: String, path: String) async {
        guard let token = await validToken() else { return }

        var request = URLRequest(
            url: URL(string: "https://api.spotify.com\(path)")!)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        _ = try? await URLSession.shared.data(for: request)
    }

    // MARK: - Library API

    func checkIfLiked(trackID: String) async -> Bool {
        guard let token = await validToken() else { return false }

        let uri = "spotify:track:\(trackID)"
        var components = URLComponents(string: "https://api.spotify.com/v1/me/library/contains")!
        components.queryItems = [URLQueryItem(name: "uris", value: uri)]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            guard status == 200,
                let result = try? JSONDecoder().decode([Bool].self, from: data),
                let isLiked = result.first
            else {
                return false
            }
            return isLiked
        } catch {
            return false
        }
    }

    func saveTrack(trackID: String) async -> Bool {
        guard let token = await validToken() else { return false }

        let uri = "spotify:track:\(trackID)"
        var components = URLComponents(string: "https://api.spotify.com/v1/me/library")!
        components.queryItems = [URLQueryItem(name: "uris", value: uri)]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            return (200...299).contains(status)
        } catch {
            return false
        }
    }

    func removeTrack(trackID: String) async -> Bool {
        guard let token = await validToken() else { return false }

        let uri = "spotify:track:\(trackID)"
        var components = URLComponents(string: "https://api.spotify.com/v1/me/library")!
        components.queryItems = [URLQueryItem(name: "uris", value: uri)]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            return (200...299).contains(status)
        } catch {
            return false
        }
    }

    // MARK: - Token Management

    private func validToken() async -> String? {
        if let token = accessToken, let expiry = tokenExpiry, expiry > Date() {
            return token
        }
        if let refresh = refreshToken {
            await refreshAccessToken(refresh)
            return accessToken
        }
        return nil
    }

    private func exchangeCode(_ code: String, verifier: String) {
        guard let clientID, hasClientID else { return }

        var request = URLRequest(url: URL(string: Self.tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "grant_type=authorization_code",
            "code=\(code)",
            "redirect_uri=\(Self.redirectURI)",
            "client_id=\(clientID)",
            "code_verifier=\(verifier)",
        ].joined(separator: "&")
        request.httpBody = body.data(using: .utf8)

        Task { [weak self] in
            guard let (data, _) = try? await URLSession.shared.data(for: request) else { return }
            await self?.handleTokenResponse(data)
        }
    }

    private func refreshAccessToken(_ token: String) async {
        guard let clientID, hasClientID else { return }

        var request = URLRequest(url: URL(string: Self.tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "grant_type=refresh_token",
            "refresh_token=\(token)",
            "client_id=\(clientID)",
        ].joined(separator: "&")
        request.httpBody = body.data(using: .utf8)

        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return }
        await handleTokenResponse(data)
    }

    @MainActor
    private func handleTokenResponse(_ data: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let access = json["access_token"] as? String,
            let expiresIn = json["expires_in"] as? Int
        else {
            return
        }

        self.accessToken = access
        self.tokenExpiry = Date().addingTimeInterval(TimeInterval(expiresIn - 60))

        if let refresh = json["refresh_token"] as? String {
            self.refreshToken = refresh
            UserDefaults.standard.set(refresh, forKey: StorageKey.refreshToken)
        }

        UserDefaults.standard.set(access, forKey: StorageKey.accessToken)
        UserDefaults.standard.set(self.tokenExpiry, forKey: StorageKey.tokenExpiry)
    }

    // MARK: - PKCE Helpers

    private func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 64)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return Data(hash)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
