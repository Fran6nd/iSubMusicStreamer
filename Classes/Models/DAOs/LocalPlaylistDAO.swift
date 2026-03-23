//
//  LocalPlaylistDAO.swift
//  iSub
//
//  Created by François ND on 2026-03-23.
//  Copyright © 2026 François ND. All rights reserved.
//

import CryptoKit

/// Pure data-access layer for the local playlists database.
///
/// All mutations run inside `inDatabase` blocks on `Database.shared().localPlaylistsDbQueue`,
/// which serialises them automatically. No UI logic lives here.
struct LocalPlaylistDAO {

    // MARK: - Private helpers

    private var queue: FMDatabaseQueue? {
        Database.shared().localPlaylistsDbQueue
    }

    static func md5(of string: String) -> String {
        Insecure.MD5.hash(data: Data(string.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    // MARK: - Read

    /// Returns every local playlist in the order they were inserted.
    func fetchAll() -> [ISMSLocalPlaylist] {
        var result: [ISMSLocalPlaylist] = []
        queue?.inDatabase { db in
            guard let rs = db.executeQuery(
                "SELECT playlist, md5 FROM localPlaylists",
                withArgumentsIn: []
            ) else { return }
            defer { rs.close() }
            while rs.next() {
                guard let name = rs.string(forColumn: "playlist"),
                      let md5  = rs.string(forColumn: "md5") else { continue }
                var count = 0
                if let countRs = db.executeQuery(
                    "SELECT COUNT(*) FROM playlist\(md5)",
                    withArgumentsIn: []
                ) {
                    if countRs.next() { count = Int(countRs.int(forColumnIndex: 0)) }
                    countRs.close()
                }
                result.append(ISMSLocalPlaylist(name: name, md5: md5, count: UInt(count)))
            }
        }
        return result
    }

    /// Returns all songs stored in the given playlist, in playback order.
    func fetchSongs(in playlist: ISMSLocalPlaylist) -> [Song] {
        var songs: [Song] = []
        queue?.inDatabase { db in
            guard let rs = db.executeQuery(
                "SELECT * FROM playlist\(playlist.md5) ORDER BY ROWID",
                withArgumentsIn: []
            ) else { return }
            defer { rs.close() }
            while rs.next() {
                if let song = Song(fromDbResult: rs) {
                    songs.append(song)
                }
            }
        }
        return songs
    }

    // MARK: - Write

    /// Creates a new local playlist with the given name.
    ///
    /// - Returns: The newly created playlist, or `nil` if a playlist with the same
    ///   name (same md5) already exists.
    @discardableResult
    func create(named name: String) -> ISMSLocalPlaylist? {
        let md5 = Self.md5(of: name)
        var created = false
        queue?.inDatabase { db in
            if let rs = db.executeQuery(
                "SELECT md5 FROM localPlaylists WHERE md5 = ?",
                withArgumentsIn: [md5]
            ) {
                let exists = rs.next()
                rs.close()
                guard !exists else { return }
            }
            db.executeUpdate(
                "INSERT INTO localPlaylists (playlist, md5) VALUES (?, ?)",
                withArgumentsIn: [name, md5]
            )
            db.executeUpdate(
                "CREATE TABLE IF NOT EXISTS playlist\(md5) (\(Song.standardSongColumnSchema()))",
                withArgumentsIn: []
            )
            created = true
        }
        guard created else { return nil }
        return ISMSLocalPlaylist(name: name, md5: md5, count: 0)
    }

    /// Renames an existing playlist.  The md5 key is left unchanged so the
    /// per-playlist song table keeps its stable name.
    func rename(_ playlist: ISMSLocalPlaylist, to name: String) {
        queue?.inDatabase { db in
            db.executeUpdate(
                "UPDATE localPlaylists SET playlist = ? WHERE md5 = ?",
                withArgumentsIn: [name, playlist.md5]
            )
        }
    }

    /// Removes the playlist row and drops its associated songs table.
    func delete(_ playlist: ISMSLocalPlaylist) {
        queue?.inDatabase { db in
            db.executeUpdate(
                "DELETE FROM localPlaylists WHERE md5 = ?",
                withArgumentsIn: [playlist.md5]
            )
            db.executeUpdate(
                "DROP TABLE IF EXISTS playlist\(playlist.md5)",
                withArgumentsIn: []
            )
        }
    }

    /// Appends a single song to the end of the playlist.
    func addSong(_ song: Song, to playlist: ISMSLocalPlaylist) {
        song.addToLocalPlaylist(withMd5: playlist.md5)
    }

    /// Appends multiple songs to the end of the playlist in order.
    func addSongs(_ songs: [Song], to playlist: ISMSLocalPlaylist) {
        for song in songs {
            song.addToLocalPlaylist(withMd5: playlist.md5)
        }
    }

    /// Removes the song at the given 0-based position from the playlist.
    ///
    /// Fetches the ROWID of the nth row (LIMIT 1 OFFSET index) then deletes
    /// by ROWID, which is safe even when ROWIDs are non-contiguous.
    func removeSong(at index: Int, from playlist: ISMSLocalPlaylist) {
        queue?.inDatabase { db in
            guard let rs = db.executeQuery(
                "SELECT ROWID FROM playlist\(playlist.md5) ORDER BY ROWID LIMIT 1 OFFSET ?",
                withArgumentsIn: [index]
            ) else { return }
            guard rs.next() else { rs.close(); return }
            let rowid = rs.longLongInt(forColumnIndex: 0)
            rs.close()
            db.executeUpdate(
                "DELETE FROM playlist\(playlist.md5) WHERE ROWID = ?",
                withArgumentsIn: [rowid]
            )
        }
    }

    /// Moves a song from one 0-based position to another within the same playlist.
    ///
    /// Correctness over cleverness: collects all ROWIDs, reorders the array,
    /// then rebuilds the table through a temporary scratch table.
    func moveSong(from source: Int, to destination: Int, in playlist: ISMSLocalPlaylist) {
        guard source != destination else { return }
        let table = "playlist\(playlist.md5)"
        queue?.inDatabase { db in
            guard let rs = db.executeQuery(
                "SELECT ROWID FROM \(table) ORDER BY ROWID",
                withArgumentsIn: []
            ) else { return }
            var rowids: [Int64] = []
            while rs.next() { rowids.append(rs.longLongInt(forColumnIndex: 0)) }
            rs.close()

            guard source >= 0, source < rowids.count,
                  destination >= 0, destination < rowids.count else { return }

            let movedRowid = rowids.remove(at: source)
            rowids.insert(movedRowid, at: destination)

            let scratch = "_localPlaylistMoveScratch"
            db.executeUpdate("DROP TABLE IF EXISTS \(scratch)", withArgumentsIn: [])
            db.executeUpdate(
                "CREATE TEMPORARY TABLE \(scratch) (\(Song.standardSongColumnSchema()))",
                withArgumentsIn: []
            )
            for rowid in rowids {
                db.executeUpdate(
                    "INSERT INTO \(scratch) SELECT \(Song.standardSongColumnNames()) FROM \(table) WHERE ROWID = ?",
                    withArgumentsIn: [rowid]
                )
            }
            db.executeUpdate("DELETE FROM \(table)", withArgumentsIn: [])
            db.executeUpdate(
                "INSERT INTO \(table) SELECT \(Song.standardSongColumnNames()) FROM \(scratch)",
                withArgumentsIn: []
            )
            db.executeUpdate("DROP TABLE \(scratch)", withArgumentsIn: [])
        }
    }
}
