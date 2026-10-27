// Licensed under GPL-3.0. See LICENSE.
//
//  HistoryTextIndex.swift
//  Nook
//
//  Visited pages' text in an SQLite FTS5 file beside the history store, one row per profile
//  and URL. Kept out of SwiftData so the shared store's schema stays put.
//

import Foundation
import OSLog
import SQLite3

public struct PageTextMatch: Sendable, Equatable {
    public let url: String
    public let title: String
    public let snippet: String
}

public actor HistoryTextIndex {
    /// A row's identity. Two profiles signed in to the same URL see different pages, so the
    /// profile is part of it. Nil is a visit no profile owned, which history shows in every space.
    public struct Key: Hashable, Sendable {
        public let profile: UUID?
        public let url: String

        public init(profile: UUID?, url: String) {
            self.profile = profile
            self.url = url
        }
    }


    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Nook", category: "HistoryTextIndex")
    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    public let fileURL: URL
    private var db: OpaquePointer?
    /// Set when FTS5 is missing or the file cannot be opened; the feature stays off this launch.
    private var unavailable = false

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    // MARK: - Writes

    public func record(_ key: Key, title: String, body: String, visitedAt: Date) {
        guard let db = open(create: true) else { return }
        let sql = """
            INSERT INTO pages(profile, url, title, body, visitedAt) VALUES(?, ?, ?, ?, ?)
            ON CONFLICT(profile, url) DO UPDATE SET title = excluded.title, body = excluded.body, visitedAt = excluded.visitedAt
            """
        run(db, sql) { stmt in
            sqlite3_bind_text(stmt, 1, Self.column(key.profile), -1, Self.transient)
            sqlite3_bind_text(stmt, 2, key.url, -1, Self.transient)
            sqlite3_bind_text(stmt, 3, title, -1, Self.transient)
            sqlite3_bind_text(stmt, 4, body, -1, Self.transient)
            sqlite3_bind_double(stmt, 5, visitedAt.timeIntervalSince1970)
        }
    }

    public func delete(_ key: Key) {
        guard let db = open(create: false) else { return }
        delete(key, in: db)
    }

    /// Drops every row no history row in `keys` can show, so text never outlives its history
    /// row. A history row with no profile shows in every space, so it keeps its URL's text.
    public func retain(only keys: Set<Key>) {
        guard let db = open(create: false) else { return }
        let stale = allKeys(db).filter { !keys.contains($0) && !keys.contains(Key(profile: nil, url: $0.url)) }
        guard !stale.isEmpty else { return }
        sqlite3_exec(db, "BEGIN", nil, nil, nil)
        for key in stale { delete(key, in: db) }
        sqlite3_exec(db, "COMMIT", nil, nil, nil)
    }

    /// Closes and removes the file.
    public func erase() {
        if let db { sqlite3_close_v2(db) }
        db = nil
        for suffix in ["", "-journal", "-wal", "-shm"] {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: fileURL.path + suffix))
        }
    }

    // MARK: - Search

    /// Pages whose title or text holds every word of `query` as a prefix, best bm25 first, then
    /// newest. Only `profile`'s rows and rows no profile owned count; nil searches every profile.
    public func search(_ query: String, profile: UUID?, limit: Int) -> [PageTextMatch] {
        guard limit > 0, let match = Self.matchExpression(for: query), let db = open(create: false) else { return [] }
        let sql = """
            SELECT p.url, p.title, snippet(page_fts, -1, '', '', '…', 12)
            FROM page_fts JOIN pages p ON p.rowid = page_fts.rowid
            WHERE page_fts MATCH ?1 AND (?2 = '' OR p.profile = ?2 OR p.profile = '')
            ORDER BY bm25(page_fts), p.visitedAt DESC LIMIT ?3
            """
        var results: [PageTextMatch] = []
        run(db, sql, bind: { stmt in
            sqlite3_bind_text(stmt, 1, match, -1, Self.transient)
            sqlite3_bind_text(stmt, 2, Self.column(profile), -1, Self.transient)
            sqlite3_bind_int(stmt, 3, Int32(limit))
        }, row: { stmt in
            results.append(PageTextMatch(url: Self.text(stmt, 0), title: Self.text(stmt, 1), snippet: Self.text(stmt, 2)))
        })
        return results
    }

    /// Each word as a quoted prefix term, so no FTS5 operator or quote in the query can reach the parser.
    nonisolated static func matchExpression(for query: String) -> String? {
        let terms = query.split(whereSeparator: \.isWhitespace)
            .filter { $0.contains { $0.isLetter || $0.isNumber } }
            .map { "\"" + $0.replacingOccurrences(of: "\"", with: "\"\"") + "\"*" }
        return terms.isEmpty ? nil : terms.joined(separator: " ")
    }

    // MARK: - SQLite

    private func open(create: Bool) -> OpaquePointer? {
        if let db { return db }
        guard !unavailable else { return nil }
        let fm = FileManager.default
        if !create, !fm.fileExists(atPath: fileURL.path) { return nil }
        try? fm.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        var handle: OpaquePointer?
        guard sqlite3_open_v2(fileURL.path, &handle, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK else {
            Self.logger.error("Page text index open failed: \(String(cString: sqlite3_errmsg(handle)), privacy: .public)")
            sqlite3_close_v2(handle)
            unavailable = true
            return nil
        }
        // Version 0 keyed rows by URL alone, so one profile's text overwrote another's. Its rows
        // name no profile and cannot be split, so they go; each page is read again on its next visit.
        let migrate = """
            PRAGMA secure_delete = ON;
            DROP TRIGGER IF EXISTS pages_ai;
            DROP TRIGGER IF EXISTS pages_ad;
            DROP TRIGGER IF EXISTS pages_au;
            DROP TABLE IF EXISTS page_fts;
            DROP TABLE IF EXISTS pages;
            """
        if Self.userVersion(handle) < Self.schemaVersion {
            guard sqlite3_exec(handle, migrate, nil, nil, nil) == SQLITE_OK else {
                Self.logger.error("Page text index migration failed: \(String(cString: sqlite3_errmsg(handle)), privacy: .public)")
                sqlite3_close_v2(handle)
                unavailable = true
                return nil
            }
        }
        // External-content FTS5 over a (profile, URL)-keyed table; the triggers keep the two in step.
        // A row no profile owned stores '' so the key stays unique (SQLite treats NULLs as distinct).
        let schema = """
            PRAGMA secure_delete = ON;
            CREATE TABLE IF NOT EXISTS pages(profile TEXT NOT NULL, url TEXT NOT NULL, title TEXT, body TEXT,
                visitedAt REAL, PRIMARY KEY(profile, url));
            CREATE VIRTUAL TABLE IF NOT EXISTS page_fts USING fts5(title, body, content='pages', content_rowid='rowid',
                tokenize='unicode61 remove_diacritics 2');
            CREATE TRIGGER IF NOT EXISTS pages_ai AFTER INSERT ON pages BEGIN
                INSERT INTO page_fts(rowid, title, body) VALUES (new.rowid, new.title, new.body);
            END;
            CREATE TRIGGER IF NOT EXISTS pages_ad AFTER DELETE ON pages BEGIN
                INSERT INTO page_fts(page_fts, rowid, title, body) VALUES ('delete', old.rowid, old.title, old.body);
            END;
            CREATE TRIGGER IF NOT EXISTS pages_au AFTER UPDATE ON pages BEGIN
                INSERT INTO page_fts(page_fts, rowid, title, body) VALUES ('delete', old.rowid, old.title, old.body);
                INSERT INTO page_fts(rowid, title, body) VALUES (new.rowid, new.title, new.body);
            END;
            PRAGMA user_version = \(Self.schemaVersion);
            """
        guard sqlite3_exec(handle, schema, nil, nil, nil) == SQLITE_OK else {
            Self.logger.error("Page text index unavailable (FTS5): \(String(cString: sqlite3_errmsg(handle)), privacy: .public)")
            sqlite3_close_v2(handle)
            unavailable = true
            return nil
        }
        db = handle
        return handle
    }

    private static let schemaVersion: Int32 = 1

    private static func userVersion(_ db: OpaquePointer?) -> Int32 {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "PRAGMA user_version", -1, &stmt, nil) == SQLITE_OK, let stmt else { return 0 }
        defer { sqlite3_finalize(stmt) }
        return sqlite3_step(stmt) == SQLITE_ROW ? sqlite3_column_int(stmt, 0) : 0
    }

    private static func column(_ profile: UUID?) -> String { profile?.uuidString ?? "" }

    private func delete(_ key: Key, in db: OpaquePointer) {
        run(db, "DELETE FROM pages WHERE profile = ? AND url = ?") { stmt in
            sqlite3_bind_text(stmt, 1, Self.column(key.profile), -1, Self.transient)
            sqlite3_bind_text(stmt, 2, key.url, -1, Self.transient)
        }
    }

    private func allKeys(_ db: OpaquePointer) -> Set<Key> {
        var keys = Set<Key>()
        run(db, "SELECT profile, url FROM pages", bind: { _ in }, row: { stmt in
            let profile = Self.text(stmt, 0)
            keys.insert(Key(profile: profile.isEmpty ? nil : UUID(uuidString: profile), url: Self.text(stmt, 1)))
        })
        return keys
    }

    private func run(_ db: OpaquePointer, _ sql: String, bind: (OpaquePointer) -> Void) {
        run(db, sql, bind: bind, row: { _ in })
    }

    private func run(_ db: OpaquePointer, _ sql: String, bind: (OpaquePointer) -> Void, row: (OpaquePointer) -> Void) {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            Self.logger.error("Page text index prepare failed: \(String(cString: sqlite3_errmsg(db)), privacy: .public)")
            return
        }
        defer { sqlite3_finalize(stmt) }
        bind(stmt)
        while true {
            let rc = sqlite3_step(stmt)
            if rc == SQLITE_ROW { row(stmt); continue }
            if rc != SQLITE_DONE {
                Self.logger.error("Page text index step failed: \(String(cString: sqlite3_errmsg(db)), privacy: .public)")
            }
            return
        }
    }

    private static func text(_ stmt: OpaquePointer, _ column: Int32) -> String {
        sqlite3_column_text(stmt, column).map { String(cString: $0) } ?? ""
    }
}
