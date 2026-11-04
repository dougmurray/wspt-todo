import Foundation
import CryptoKit
import Security

/// Read-only Google Calendar access via the REST API (v3), using the OAuth
/// 2.0 "installed app" flow with PKCE — no Google SDK dependency.
///
/// Setup (one-time, by the developer): create an OAuth client of type
/// **iOS** in Google Cloud Console with bundle ID
/// `com.douglassmurray.wspttodo`, enable the Google Calendar API, and put
/// the client ID either in `project.yml`'s `GoogleOAuthClientID` Info.plist
/// key or in the Calendar tab's connect screen. iOS-type clients need no
/// client secret and redirect to the reversed client ID scheme, which
/// `ASWebAuthenticationSession` intercepts directly — so no URL-scheme
/// registration is needed either.
///
/// Tokens (including the long-lived refresh token) live in the Keychain,
/// never in UserDefaults.
actor GoogleCalendarClient {
    enum ClientError: LocalizedError {
        case notConfigured
        case notSignedIn
        case authorizationFailed(String)
        case http(status: Int, message: String)

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                "No Google OAuth client ID is configured."
            case .notSignedIn:
                "Not signed in to Google."
            case .authorizationFailed(let detail):
                "Google sign-in failed: \(detail)"
            case .http(let status, let message):
                "Google Calendar returned \(status): \(message)"
            }
        }
    }

    static let scope = "https://www.googleapis.com/auth/calendar.readonly"

    /// What a sign-in attempt needs to carry between building the auth URL
    /// and handling the redirect.
    struct PendingAuthorization: Sendable {
        let url: URL
        let callbackScheme: String
        let redirectURI: String
        let verifier: String
        let state: String
        let clientID: String
    }

    private struct StoredTokens: Codable {
        var clientID: String
        var accessToken: String
        var refreshToken: String
        var expiry: Date
    }

    private var tokens: StoredTokens?
    private var refreshTask: Task<String, Error>?
    private let session = URLSession(configuration: .ephemeral)

    init() {
        tokens = Keychain.load().flatMap { try? JSONDecoder().decode(StoredTokens.self, from: $0) }
    }

    var isSignedIn: Bool { tokens != nil }

    // MARK: - Sign in / out

    /// "123-abc.apps.googleusercontent.com" → "com.googleusercontent.apps.123-abc"
    static func reversedClientID(_ clientID: String) -> String {
        clientID.split(separator: ".").reversed().joined(separator: ".")
    }

    nonisolated static func makeAuthorization(clientID: String) -> PendingAuthorization {
        let verifier = randomURLSafeString(byteCount: 48)
        let challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncoded
        let state = randomURLSafeString(byteCount: 16)
        let scheme = reversedClientID(clientID)
        let redirectURI = "\(scheme):/oauth2redirect"

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "prompt", value: "consent"),
        ]
        return PendingAuthorization(
            url: components.url!,
            callbackScheme: scheme,
            redirectURI: redirectURI,
            verifier: verifier,
            state: state,
            clientID: clientID
        )
    }

    /// Exchanges the redirect's authorization code for tokens and persists them.
    func completeAuthorization(_ pending: PendingAuthorization, callbackURL: URL) async throws {
        let items = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? { items.first(where: { $0.name == name })?.value }

        if let error = value("error") { throw ClientError.authorizationFailed(error) }
        guard value("state") == pending.state else {
            throw ClientError.authorizationFailed("state mismatch")
        }
        guard let code = value("code") else {
            throw ClientError.authorizationFailed("no authorization code returned")
        }

        let response = try await tokenRequest([
            "client_id": pending.clientID,
            "code": code,
            "code_verifier": pending.verifier,
            "redirect_uri": pending.redirectURI,
            "grant_type": "authorization_code",
        ])
        guard let refreshToken = response.refresh_token else {
            throw ClientError.authorizationFailed("no refresh token returned")
        }
        let stored = StoredTokens(
            clientID: pending.clientID,
            accessToken: response.access_token,
            refreshToken: refreshToken,
            expiry: Date.now.addingTimeInterval(TimeInterval(response.expires_in ?? 3600))
        )
        save(stored)
    }

    /// Revokes the refresh token (best effort) and forgets all tokens.
    func signOut() async {
        if let refreshToken = tokens?.refreshToken {
            var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/revoke")!)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = Self.formBody(["token": refreshToken])
            _ = try? await session.data(for: request)
        }
        tokens = nil
        refreshTask = nil
        Keychain.delete()
    }

    // MARK: - Calendar API

    func calendars() async throws -> [CalendarInfo] {
        var result: [CalendarInfo] = []
        var pageToken: String?
        repeat {
            var query = [URLQueryItem(name: "minAccessRole", value: "reader")]
            if let pageToken { query.append(URLQueryItem(name: "pageToken", value: pageToken)) }
            let page: CalendarListResponse = try await get(path: "users/me/calendarList", query: query)
            result += page.items.map {
                CalendarInfo(
                    id: $0.id,
                    title: $0.summaryOverride ?? $0.summary ?? $0.id,
                    color: RGBColor(hex: $0.backgroundColor) ?? .fallback
                )
            }
            pageToken = page.nextPageToken
        } while pageToken != nil
        return result
    }

    func events(in calendar: CalendarInfo, from start: Date, to end: Date) async throws -> [CalendarEvent] {
        let iso = ISO8601DateFormatter()
        var result: [CalendarEvent] = []
        var pageToken: String?
        repeat {
            var query = [
                URLQueryItem(name: "timeMin", value: iso.string(from: start)),
                URLQueryItem(name: "timeMax", value: iso.string(from: end)),
                URLQueryItem(name: "singleEvents", value: "true"),
                URLQueryItem(name: "orderBy", value: "startTime"),
                URLQueryItem(name: "maxResults", value: "2500"),
            ]
            if let pageToken { query.append(URLQueryItem(name: "pageToken", value: pageToken)) }
            let path = "calendars/\(Self.pathEscaped(calendar.id))/events"
            let page: EventsResponse = try await get(path: path, query: query)
            result += page.items.compactMap { $0.asEvent(in: calendar) }
            pageToken = page.nextPageToken
        } while pageToken != nil
        return result
    }

    // MARK: - Plumbing

    private func get<T: Decodable>(path: String, query: [URLQueryItem]) async throws -> T {
        var components = URLComponents(string: "https://www.googleapis.com/calendar/v3/")!
        components.percentEncodedPath += path
        components.queryItems = query
        let url = components.url!

        for attempt in 0..<2 {
            let token = try await validAccessToken(forceRefresh: attempt > 0)
            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let (data, response) = try await session.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status == 401, attempt == 0 { continue }
            guard (200..<300).contains(status) else {
                throw ClientError.http(status: status, message: Self.errorMessage(from: data))
            }
            return try JSONDecoder().decode(T.self, from: data)
        }
        throw ClientError.notSignedIn
    }

    private func validAccessToken(forceRefresh: Bool) async throws -> String {
        guard let current = tokens else { throw ClientError.notSignedIn }
        if !forceRefresh, current.expiry > Date.now.addingTimeInterval(60) {
            return current.accessToken
        }
        // Coalesce concurrent refreshes (events for several calendars are
        // fetched in parallel) into a single token request.
        if let refreshTask { return try await refreshTask.value }

        let task = Task<String, Error> {
            let response = try await tokenRequest([
                "client_id": current.clientID,
                "refresh_token": current.refreshToken,
                "grant_type": "refresh_token",
            ])
            var updated = current
            updated.accessToken = response.access_token
            updated.expiry = Date.now.addingTimeInterval(TimeInterval(response.expires_in ?? 3600))
            if let rotated = response.refresh_token { updated.refreshToken = rotated }
            save(updated)
            return response.access_token
        }
        refreshTask = task
        defer { refreshTask = nil }
        do {
            return try await task.value
        } catch ClientError.http(let status, _) where status == 400 || status == 401 {
            // invalid_grant: the refresh token was revoked or expired.
            tokens = nil
            Keychain.delete()
            throw ClientError.notSignedIn
        }
    }

    private struct TokenResponse: Decodable {
        let access_token: String
        let expires_in: Int?
        let refresh_token: String?
    }

    private func tokenRequest(_ fields: [String: String]) async throws -> TokenResponse {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formBody(fields)
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw ClientError.http(status: status, message: Self.errorMessage(from: data))
        }
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    private func save(_ stored: StoredTokens) {
        tokens = stored
        if let data = try? JSONEncoder().encode(stored) { Keychain.save(data) }
    }

    private static func formBody(_ fields: [String: String]) -> Data {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return fields
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: allowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)!
    }

    /// Calendar IDs contain "@" and "#", which must be escaped in a path segment.
    private static func pathEscaped(_ segment: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return segment.addingPercentEncoding(withAllowedCharacters: allowed) ?? segment
    }

    private static func errorMessage(from data: Data) -> String {
        struct Envelope: Decodable {
            struct Inner: Decodable { let message: String? }
            let error: Inner?
            let error_description: String?
        }
        // Google uses `{"error": {...}}` for API errors and
        // `{"error": "invalid_grant", "error_description": ...}` for OAuth.
        if let envelope = try? JSONDecoder().decode(Envelope.self, from: data) {
            if let message = envelope.error?.message ?? envelope.error_description { return message }
        }
        return String(data: data, encoding: .utf8)?.prefix(200).description ?? "unknown error"
    }

    private nonisolated static func randomURLSafeString(byteCount: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        _ = SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes)
        return Data(bytes).base64URLEncoded
    }
}

// MARK: - API response shapes

private struct CalendarListResponse: Decodable {
    struct Entry: Decodable {
        let id: String
        let summary: String?
        let summaryOverride: String?
        let backgroundColor: String?
    }
    let items: [Entry]
    let nextPageToken: String?
}

private struct EventsResponse: Decodable {
    struct EventTime: Decodable {
        let dateTime: String?
        let date: String?
    }
    struct Item: Decodable {
        let id: String
        let status: String?
        let summary: String?
        let location: String?
        let htmlLink: String?
        let start: EventTime?
        let end: EventTime?

        func asEvent(in calendar: CalendarInfo) -> CalendarEvent? {
            guard status != "cancelled", let start, let end else { return nil }
            let isAllDay = start.date != nil
            guard
                let startDate = Self.parse(start),
                let endDate = Self.parse(end)
            else { return nil }
            return CalendarEvent(
                id: "\(calendar.id)/\(id)",
                calendarID: calendar.id,
                calendarTitle: calendar.title,
                title: summary?.isEmpty == false ? summary! : "(No title)",
                start: startDate,
                end: max(endDate, startDate),
                isAllDay: isAllDay,
                location: location,
                color: calendar.color,
                url: htmlLink.flatMap(URL.init(string:))
            )
        }

        private static func parse(_ time: EventTime) -> Date? {
            if let dateTime = time.dateTime {
                let formatter = ISO8601DateFormatter()
                if let date = formatter.date(from: dateTime) { return date }
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                return formatter.date(from: dateTime)
            }
            if let date = time.date {
                // All-day dates are floating calendar days: interpret in the
                // user's local time zone.
                let formatter = DateFormatter()
                formatter.calendar = Calendar(identifier: .gregorian)
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = .current
                formatter.dateFormat = "yyyy-MM-dd"
                return formatter.date(from: date)
            }
            return nil
        }
    }
    let items: [Item]
    let nextPageToken: String?
}

// MARK: - Helpers

private extension Data {
    var base64URLEncoded: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

/// Minimal generic-password Keychain wrapper for the one stored token blob.
private enum Keychain {
    private static let service = "com.douglassmurray.wspttodo.google-oauth"
    private static let account = "default"

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    static func save(_ data: Data) {
        let status = SecItemUpdate(baseQuery as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var query = baseQuery
            query[kSecValueData as String] = data
            SecItemAdd(query as CFDictionary, nil)
        }
    }

    static func load() -> Data? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    static func delete() {
        SecItemDelete(baseQuery as CFDictionary)
    }
}
