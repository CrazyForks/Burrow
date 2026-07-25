//
//  MCPAnalyzeTests.swift
//  BurrowTests
//
//  burrow_analyze pruning (issue #302). Mole reports one pretty-printed
//  level per run; real agent transcripts showed 35–60 KB responses and a
//  15-call drill-down loop. The pruner is a pure function over mole's
//  parsed JSON: sort largest-first, filter by min_size, cut to limit,
//  and count every drop — truncation must never be silent.
//

import XCTest
@testable import Burrow

final class MCPAnalyzeTests: XCTestCase {

    private func entry(_ name: String, size: Int, isDir: Bool = true) -> [String: Any] {
        ["name": name, "path": "/x/\(name)", "size": size, "is_dir": isDir]
    }

    func testPrune_sortsLargestFirst() throws {
        let level: [String: Any] = ["path": "/x", "entries": [
            entry("small", size: 10), entry("big", size: 1000), entry("mid", size: 100),
        ]]
        let out = ToolCatalog.prunedAnalyzeLevel(level, limit: 100, minSize: 0)
        let names = (out["entries"] as? [[String: Any]])?.compactMap { $0["name"] as? String }
        XCTAssertEqual(names, ["big", "mid", "small"])
        XCTAssertNil(out["entries_omitted"], "nothing dropped, no marker")
    }

    func testPrune_limitCutsAndCountsTheTail() throws {
        let level: [String: Any] = ["entries": (1...5).map { entry("e\($0)", size: $0 * 100) }]
        let out = ToolCatalog.prunedAnalyzeLevel(level, limit: 2, minSize: 0)
        XCTAssertEqual((out["entries"] as? [[String: Any]])?.count, 2)
        XCTAssertEqual(out["entries_omitted"] as? Int, 3)
        // dropped: 300 + 200 + 100
        XCTAssertEqual(out["omitted_bytes"] as? Int64, 600)
    }

    func testPrune_minSizeFiltersNoise() throws {
        let level: [String: Any] = ["entries": [
            entry("keep", size: 5000), entry("noise1", size: 10), entry("noise2", size: 20),
        ]]
        let out = ToolCatalog.prunedAnalyzeLevel(level, limit: 100, minSize: 1000)
        XCTAssertEqual((out["entries"] as? [[String: Any]])?.count, 1)
        XCTAssertEqual(out["entries_omitted"] as? Int, 2)
        XCTAssertEqual(out["omitted_bytes"] as? Int64, 30)
    }

    func testPrune_preservesUnknownLevelAndEntryFields() throws {
        // The contract tracks mole's — extra fields must survive the prune.
        let level: [String: Any] = ["path": "/x", "overview": false,
                                    "entries": [entry("a", size: 1)]]
        let out = ToolCatalog.prunedAnalyzeLevel(level, limit: 100, minSize: 0)
        XCTAssertEqual(out["overview"] as? Bool, false)
        XCTAssertEqual(out["path"] as? String, "/x")
        XCTAssertEqual((out["entries"] as? [[String: Any]])?.first?["path"] as? String, "/x/a")
    }

    func testPrune_toleratesMissingEntries() throws {
        let out = ToolCatalog.prunedAnalyzeLevel(["path": "/x"], limit: 10, minSize: 0)
        XCTAssertEqual((out["entries"] as? [[String: Any]])?.count, 0)
    }

    func testEntrySize_readsJSONSerializationNumbers() throws {
        // Round-trip through JSONSerialization so sizes arrive as NSNumber,
        // exactly as callAnalyze sees them.
        let data = Data(#"{"entries":[{"name":"a","size":5368709120}]}"#.utf8)
        let obj = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let e = try XCTUnwrap((obj["entries"] as? [[String: Any]])?.first)
        XCTAssertEqual(ToolCatalog.entrySize(e), 5_368_709_120)
        XCTAssertEqual(ToolCatalog.entrySize(["name": "x"]), 0, "sizeless entry ranks last, not crashes")
    }
}
