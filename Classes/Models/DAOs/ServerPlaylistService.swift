//
//  ServerPlaylistService.swift
//  iSub
//
//  Created by François ND on 2026-03-23.
//  Copyright © 2026 François ND. All rights reserved.
//

import Foundation

/// Async/await wrapper around the Subsonic playlist API endpoints.
///
/// All network calls go through the same `NSMutableURLRequest(susAction:parameters:)` helper
/// used by the existing Objective-C loaders, so auth and URL construction are centralised.
/// XML parsing uses Foundation's `XMLParser` to avoid the ObjC `RXMLElement` dependency here.
actor ServerPlaylistService {

    // MARK: - Error

    enum ServiceError: Error, LocalizedError {
        case invalidResponse
        case serverError(code: Int, message: String)

        var errorDescription: String? {
            switch self {
            case .invalidResponse:             return "Invalid server response"
            case .serverError(_, let message): return message
            }
        }
    }

    // MARK: - Request builder

    /// Wraps the nullable ObjC factory and force-unwraps — fails only if server settings
    /// are missing, which is a programmer error caught during development.
    private func request(action: String, parameters: [String: Any] = [:]) -> URLRequest {
        NSMutableURLRequest(susAction: action, parameters: parameters)! as URLRequest
    }

    // MARK: - Shared session

    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest  = 60
        config.timeoutIntervalForResource = 240
        let delegate = SelfSignedCertURLSessionDelegate()
        return URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
    }()

    // MARK: - Read

    /// Fetches all playlists visible to the authenticated user.
    func fetchAll() async throws -> [ServerPlaylist] {
        let (data, _) = try await session.data(for: request(action: "getPlaylists"))
        return try parsePlaylistList(from: data)
    }

    /// Fetches the songs in a given server playlist.
    func fetchSongs(in playlist: ServerPlaylist) async throws -> [Song] {
        let (data, _) = try await session.data(for: request(action: "getPlaylist",
                                                             parameters: ["id": playlist.playlistId]))
        return try parsePlaylistSongs(from: data)
    }

    // MARK: - Write

    /// Creates a new server playlist containing the given songs.
    ///
    /// - Returns: The freshly created `ServerPlaylist` as reported by the server.
    @discardableResult
    func create(named name: String, songs: [Song] = []) async throws -> ServerPlaylist {
        // Subsonic's createPlaylist accepts repeated songId params; build the base request
        // then append them manually so the URL-construction helper stays simple.
        let base = request(action: "createPlaylist", parameters: ["name": name])
        let songIds = songs.compactMap(\.songId)
        let req = songIds.isEmpty ? base : appendRepeatedParam("songId", values: songIds, to: base)
        let (data, _) = try await session.data(for: req)
        return try parseCreatedPlaylist(from: data)
    }

    /// Appends songs to an existing server playlist.
    func addSongs(_ songs: [Song], to playlist: ServerPlaylist) async throws {
        guard !songs.isEmpty else { return }
        let songIds = songs.compactMap(\.songId)
        guard !songIds.isEmpty else { return }
        let base = request(action: "updatePlaylist", parameters: ["playlistId": playlist.playlistId])
        let req  = appendRepeatedParam("songIdToAdd", values: songIds, to: base)
        let (data, _) = try await session.data(for: req)
        try checkForServerError(in: data)
    }

    /// Removes songs at the specified 0-based indices from a server playlist.
    func removeSongs(at indices: [Int], from playlist: ServerPlaylist) async throws {
        guard !indices.isEmpty else { return }
        let base = request(action: "updatePlaylist", parameters: ["playlistId": playlist.playlistId])
        let req  = appendRepeatedParam("songIndexToRemove", values: indices.map(String.init), to: base)
        let (data, _) = try await session.data(for: req)
        try checkForServerError(in: data)
    }

    /// Renames a server playlist.
    func rename(_ playlist: ServerPlaylist, to name: String) async throws {
        let (data, _) = try await session.data(for: request(action: "updatePlaylist",
                                                             parameters: ["playlistId": playlist.playlistId,
                                                                          "name": name]))
        try checkForServerError(in: data)
    }

    /// Permanently deletes a server playlist.
    func delete(_ playlist: ServerPlaylist) async throws {
        let (data, _) = try await session.data(for: request(action: "deletePlaylist",
                                                             parameters: ["id": playlist.playlistId]))
        try checkForServerError(in: data)
    }

    // MARK: - Clone operations

    /// Copies a local playlist up to the server, filtering out songs with no server song ID.
    @discardableResult
    func cloneLocalToServer(_ local: ISMSLocalPlaylist) async throws -> ServerPlaylist {
        let songs = LocalPlaylistDAO().fetchSongs(in: local)
        return try await create(named: local.name, songs: songs)
    }

    /// Downloads a server playlist into local storage.
    @discardableResult
    func cloneServerToLocal(_ server: ServerPlaylist) async throws -> ISMSLocalPlaylist {
        let songs = try await fetchSongs(in: server)
        let dao = LocalPlaylistDAO()
        // create(named:) returns nil on duplicate; use existing playlist in that case.
        let local = dao.create(named: server.playlistName)
            ?? dao.fetchAll().first(where: { $0.name == server.playlistName })
        guard let local else { throw ServiceError.invalidResponse }
        dao.addSongs(songs, to: local)
        return local
    }

    // MARK: - URL helpers

    /// Appends repeated query-string parameters (e.g. `songId=1&songId=2`) to a request.
    private func appendRepeatedParam(_ key: String, values: [String], to base: URLRequest) -> URLRequest {
        guard let original = base.url?.absoluteString else { return base }
        let suffix = values.map { "\(key)=\($0.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0)" }
                           .joined(separator: "&")
        var req = base
        req.url = URL(string: original + "&" + suffix)
        return req
    }

    // MARK: - XML parsing

    private func parsePlaylistList(from data: Data) throws -> [ServerPlaylist] {
        let doc = SubsonicXMLDocument(data: data)
        try doc.throwIfError()
        return doc.elements(atPath: "subsonic-response.playlists.playlist")
            .map { ServerPlaylist(rxml: $0) }
    }

    private func parsePlaylistSongs(from data: Data) throws -> [Song] {
        let doc = SubsonicXMLDocument(data: data)
        try doc.throwIfError()
        return doc.elements(atPath: "subsonic-response.playlist.entry")
            .compactMap { Song(subsonicAttributes: $0.attributes) }
    }

    private func parseCreatedPlaylist(from data: Data) throws -> ServerPlaylist {
        let doc = SubsonicXMLDocument(data: data)
        try doc.throwIfError()
        // createPlaylist returns the playlist element directly in some server versions.
        if let el = doc.elements(atPath: "subsonic-response.playlist").first {
            return ServerPlaylist(rxml: el)
        }
        throw ServiceError.invalidResponse
    }

    private func checkForServerError(in data: Data) throws {
        let doc = SubsonicXMLDocument(data: data)
        try doc.throwIfError()
    }
}

// MARK: - Minimal XML document wrapper

/// Lightweight SAX-based parser for Subsonic XML responses.
/// Avoids importing the ObjC RaptureXML framework from Swift.
private final class SubsonicXMLDocument: NSObject, XMLParserDelegate {

    struct Element {
        let name: String
        let attributes: [String: String]
    }

    private var elements: [Element] = []
    private var pathStack: [String] = []
    private var errorCode: Int?
    private var errorMessage: String?

    init(data: Data) {
        super.init()
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
    }

    func throwIfError() throws {
        if let code = errorCode, let message = errorMessage {
            throw ServerPlaylistService.ServiceError.serverError(code: code, message: message)
        }
    }

    func elements(atPath path: String) -> [Element] {
        elements.filter { $0.name == path }
    }

    // MARK: XMLParserDelegate

    func parser(_ parser: XMLParser,
                didStartElement elementName: String,
                namespaceURI: String?,
                qualifiedName: String?,
                attributes: [String: String]) {
        pathStack.append(elementName)
        let path = pathStack.joined(separator: ".")
        elements.append(Element(name: path, attributes: attributes))
        if elementName == "error" {
            errorCode    = Int(attributes["code"] ?? "")
            errorMessage = attributes["message"]
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName: String?) {
        pathStack.removeLast()
    }
}

// MARK: - ServerPlaylist convenience init

private extension ServerPlaylist {
    /// Initialises a `ServerPlaylist` from the attributes of an XML element
    /// (as parsed by `SubsonicXMLDocument`).
    convenience init(rxml element: SubsonicXMLDocument.Element) {
        self.init()
        playlistId   = element.attributes["id"]   ?? ""
        playlistName = element.attributes["name"] ?? ""
    }
}

// MARK: - Song XML initialisation (Subsonic API)

private extension Song {
    /// Creates a Song from the XML attributes of a Subsonic `<song>` / `<entry>` element.
    /// Foundation's XMLParser already unescapes XML entities; `decoded` additionally applies
    /// percent-decoding to match the ObjC `cleanString` helper.
    convenience init?(subsonicAttributes a: [String: String]) {
        guard let id = a["id"]?.nonEmpty else { return nil }
        self.init()
        songId           = id
        title            = a["title"]?.decoded
        parentId         = a["parent"]?.decoded
        artist           = a["artist"]?.decoded
        album            = a["album"]?.decoded
        genre            = a["genre"]?.decoded
        coverArtId       = a["coverArt"]?.decoded
        path             = a["path"]?.decoded
        suffix           = a["suffix"]?.decoded
        transcodedSuffix = a["transcodedSuffix"]?.decoded
        isVideo          = a["isVideo"] == "true"
        if let s = a["duration"],   let v = Int(s)   { duration    = NSNumber(value: v) }
        if let s = a["bitRate"],    let v = Int(s)    { bitRate     = NSNumber(value: v) }
        if let s = a["track"],      let v = Int(s)    { track       = NSNumber(value: v) }
        if let s = a["year"],       let v = Int(s)    { year        = NSNumber(value: v) }
        if let s = a["size"],       let v = Int64(s)  { size        = NSNumber(value: v) }
        if let s = a["discNumber"], let v = Int64(s)  { discNumber  = NSNumber(value: v) }
    }
}

private extension String {
    /// Percent-decodes the string; returns `nil` for empty results.
    var decoded: String? {
        let s = removingPercentEncoding ?? self
        return s.isEmpty ? nil : s
    }
    /// Returns `nil` if the string is empty.
    var nonEmpty: String? { isEmpty ? nil : self }
}
