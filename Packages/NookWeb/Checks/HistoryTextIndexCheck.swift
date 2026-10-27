// Licensed under GPL-3.0. See LICENSE.
//
//  HistoryTextIndexCheck.swift
//  Nook
//
//  Page text index check. NookWeb has no test target, so this compiles the shipped source directly:
//
//    swiftc -parse-as-library Packages/NookWeb/Sources/NookWeb/HistoryTextIndex.swift \
//           Packages/NookWeb/Checks/HistoryTextIndexCheck.swift -o /tmp/text-index-check && /tmp/text-index-check
//

import Foundation
import SQLite3

@main
struct HistoryTextIndexCheck {
    static func main() async {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let index = HistoryTextIndex(fileURL: dir.appendingPathComponent("History/page-text.sqlite"))
        let work = UUID(), home = UUID()
        func key(_ url: String, _ profile: UUID? = work) -> HistoryTextIndex.Key { .init(profile: profile, url: url) }

        // Nothing is created by a read or a delete.
        do { let r = await index.search("anything", profile: work, limit: 3); precondition(r.isEmpty) }
        await index.delete(key("https://a.example/"))
        precondition(!FileManager.default.fileExists(atPath: index.fileURL.path))

        let old = Date(timeIntervalSince1970: 1_700_000_000)
        await index.record(key("https://a.example/"), title: "Kettle review", body: "The thermostat holds water at eighty degrees. Café crème.", visitedAt: old)
        await index.record(key("https://b.example/"), title: "Bikes", body: "Gear ratios and the thermostat of nothing.", visitedAt: old.addingTimeInterval(60))

        // Every word is a prefix term, in any order, diacritics folded.
        do { let r = await index.search("thermo", profile: work, limit: 5); precondition(r.count == 2) }
        do { let r = await index.search("eigh therm", profile: work, limit: 5); precondition(r.map(\.url) == ["https://a.example/"]) }
        do { let r = await index.search("cafe creme", profile: work, limit: 5); precondition(r.map(\.url) == ["https://a.example/"]) }
        do { let r = await index.search("kett", profile: work, limit: 5); precondition(r.first?.snippet.contains("Kettle") == true) }
        do { let r = await index.search("thermostat", profile: work, limit: 1); precondition(r.count == 1) }

        // FTS syntax in the query is literal text, never an error.
        for hostile in ["foo\" OR", "\"", "* NEAR(", "AND OR NOT", "a:b", "(-^)", "thermo\""] {
            _ = await index.search(hostile, profile: work, limit: 5)
        }
        do { let r = await index.search("thermo\"", profile: work, limit: 5); precondition(r.count == 2) }
        precondition(HistoryTextIndex.matchExpression(for: "  \" * ") == nil)

        // A revisit replaces the row.
        await index.record(key("https://a.example/"), title: "Kettle review", body: "Now about teapots.", visitedAt: old.addingTimeInterval(120))
        do { let r = await index.search("eighty", profile: work, limit: 5); precondition(r.isEmpty) }
        do { let r = await index.search("teapot", profile: work, limit: 5); precondition(r.map(\.url) == ["https://a.example/"]) }
        do { let r = await index.search("thermo", profile: work, limit: 5); precondition(r.map(\.url) == ["https://b.example/"]) }

        // The same URL in two profiles is two rows: neither overwrites the other, neither searches the other's.
        await index.record(key("https://mail.example/inbox", home), title: "Inbox", body: "Birthday dinner reservation for Saturday.", visitedAt: old)
        await index.record(key("https://mail.example/inbox", work), title: "Inbox", body: "Quarterly payroll export attached.", visitedAt: old.addingTimeInterval(1))
        do { let r = await index.search("birthday", profile: home, limit: 5); precondition(r.map(\.url) == ["https://mail.example/inbox"]) }
        do { let r = await index.search("birthday", profile: work, limit: 5); precondition(r.isEmpty) }
        do { let r = await index.search("payroll", profile: home, limit: 5); precondition(r.isEmpty) }
        do { let r = await index.search("payroll", profile: work, limit: 5); precondition(r.count == 1) }
        // Nil searches every profile.
        do { let r = await index.search("birthday", profile: nil, limit: 5); precondition(r.count == 1) }
        // A row no profile owned shows in every profile.
        await index.record(key("https://legacy.example/", nil), title: "Legacy", body: "Unowned marmalade notes.", visitedAt: old)
        do { let r = await index.search("marmalade", profile: home, limit: 5); precondition(r.count == 1) }

        // Clearing one profile's history keeps the other profile's text for the same URL.
        await index.retain(only: [key("https://a.example/"), key("https://b.example/"), key("https://mail.example/inbox", work)])
        do { let r = await index.search("birthday", profile: home, limit: 5); precondition(r.isEmpty) }
        do { let r = await index.search("payroll", profile: work, limit: 5); precondition(r.count == 1) }
        do { let r = await index.search("marmalade", profile: work, limit: 5); precondition(r.isEmpty) }
        // A history row no profile owned keeps every profile's text for its URL.
        await index.record(key("https://shared.example/", home), title: "S", body: "Shared pumpkin page.", visitedAt: old)
        await index.retain(only: [key("https://a.example/"), key("https://b.example/"), key("https://mail.example/inbox", work), key("https://shared.example/", nil)])
        do { let r = await index.search("pumpkin", profile: home, limit: 5); precondition(r.count == 1) }

        // Deletion, by key and by what history still holds.
        await index.delete(key("https://b.example/"))
        do { let r = await index.search("gear", profile: work, limit: 5); precondition(r.isEmpty) }
        await index.delete(key("https://mail.example/inbox", home))
        do { let r = await index.search("payroll", profile: work, limit: 5); precondition(r.count == 1) }
        await index.record(key("https://c.example/"), title: "C", body: "Gear again", visitedAt: old)
        await index.retain(only: [key("https://c.example/")])
        do { let r = await index.search("teapot", profile: work, limit: 5); precondition(r.isEmpty) }
        do { let r = await index.search("gear", profile: work, limit: 5); precondition(r.map(\.url) == ["https://c.example/"]) }

        await index.erase()
        precondition(!FileManager.default.fileExists(atPath: index.fileURL.path))
        do { let r = await index.search("gear", profile: work, limit: 5); precondition(r.isEmpty) }
        // A write after erase starts a fresh file.
        await index.record(key("https://d.example/"), title: "D", body: "fresh", visitedAt: old)
        do { let r = await index.search("fresh", profile: work, limit: 5); precondition(r.count == 1) }

        // A file from before profiles were part of the key is dropped, not misattributed.
        let legacyURL = dir.appendingPathComponent("Legacy/page-text.sqlite")
        try? FileManager.default.createDirectory(at: legacyURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        var legacy: OpaquePointer?
        precondition(sqlite3_open(legacyURL.path, &legacy) == SQLITE_OK)
        precondition(sqlite3_exec(legacy, """
            CREATE TABLE pages(url TEXT PRIMARY KEY, title TEXT, body TEXT, visitedAt REAL);
            CREATE VIRTUAL TABLE page_fts USING fts5(title, body, content='pages', content_rowid='rowid');
            CREATE TRIGGER pages_ai AFTER INSERT ON pages BEGIN
                INSERT INTO page_fts(rowid, title, body) VALUES (new.rowid, new.title, new.body);
            END;
            INSERT INTO pages VALUES('https://mail.example/inbox', 'Inbox', 'Mixed profile secret text', 0);
            """, nil, nil, nil) == SQLITE_OK)
        sqlite3_close(legacy)
        let migrated = HistoryTextIndex(fileURL: legacyURL)
        do { let r = await migrated.search("secret", profile: nil, limit: 5); precondition(r.isEmpty) }
        await migrated.record(key("https://mail.example/inbox"), title: "Inbox", body: "Fresh after migration", visitedAt: old)
        do { let r = await migrated.search("fresh", profile: work, limit: 5); precondition(r.count == 1) }
        await migrated.erase()

        print("HistoryTextIndexCheck passed")
    }
}
