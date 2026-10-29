import Foundation
nonisolated(unsafe) var failures = 0
nonisolated(unsafe) var checks = 0
func check(_ ok: Bool, _ line: Int) {
    checks += 1
    if !ok { failures += 1; print("FAIL line \(line)") }
}
import Foundation

import PastlogCore

struct PasteboardTypesTests {
    func testClassification() {
        check(PasteboardTypes.classify(types: ["public.utf8-plain-text"], plainText: "hello") == .text, #line)
        check(PasteboardTypes.classify(types: ["public.utf8-plain-text"], plainText: "https://sviera91.github.io") == .link, #line)
        check(PasteboardTypes.classify(types: ["public.utf8-plain-text"], plainText: "see https://x.com now") == .text, #line)
        check(PasteboardTypes.classify(types: ["public.utf8-plain-text", "public.rtf"], plainText: "bold") == .richText, #line)
        check(PasteboardTypes.classify(types: ["public.png"], plainText: nil) == .image, #line)
        check(PasteboardTypes.classify(types: ["public.file-url", "public.utf8-plain-text"], plainText: "a.pdf") == .file, #line)
        check(PasteboardTypes.classify(types: ["com.example.custom"], plainText: nil) == .other, #line)
    }

    func testSensitiveMarkers() {
        check(PasteboardTypes.isSensitive(types: ["public.utf8-plain-text", "org.nspasteboard.ConcealedType"]), #line)
        check(PasteboardTypes.isSensitive(types: ["org.nspasteboard.TransientType"]), #line)
        check(!PasteboardTypes.isSensitive(types: ["public.utf8-plain-text"]), #line)
    }

    func testTitles() {
        check(PasteboardTypes.title(kind: .text, plainText: "\n  first line \nsecond", filePaths: [], imageWidth: nil, imageHeight: nil, types: []) == "first line", #line)
        check(PasteboardTypes.title(kind: .image, plainText: nil, filePaths: [], imageWidth: 10, imageHeight: 20, types: []) == "Image 10 × 20", #line)
        check(PasteboardTypes.title(kind: .file, plainText: nil, filePaths: ["/a/b.txt", "/c/d.png"], imageWidth: nil, imageHeight: nil, types: []) == "b.txt, d.png", #line)
    }
}

@MainActor
struct ClipStoreTests {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("pastlog-tests-\(UUID().uuidString)")

    private func text(_ s: String) -> Capture {
        Capture(items: [[RawFlavor(type: PasteboardTypes.plainText, data: Data(s.utf8))]], plainText: s, sourceAppName: "Notes")
    }

    func testAddDedupeAndOrder() {
        let store = ClipStore(directory: dir)
        let t0 = Date(timeIntervalSince1970: 0)
        store.add(text("one"), now: t0)
        store.add(text("two"), now: t0.addingTimeInterval(1))
        store.add(text("one"), now: t0.addingTimeInterval(2))
        check(store.clips.map(\.title) == ["one", "two"], #line)
        check(store.clips.first?.copyCount == 2, #line)
    }

    func testPinnedSurvivesTrimAndSortsFirst() {
        let store = ClipStore(directory: dir, maxItems: 2)
        let base = Date(timeIntervalSince1970: 0)
        let first = store.add(text("keep me"), now: base)!
        store.togglePin(first.id)
        for i in 0..<5 { store.add(text("n\(i)"), now: base.addingTimeInterval(Double(i + 1))) }
        check(store.clips.map(\.title) == ["keep me", "n4", "n3"], #line)
    }

    func testPersistenceAndBlobs() {
        let store = ClipStore(directory: dir)
        let png = Data([0x89, 0x50, 0x4E, 0x47])
        let clip = store.add(Capture(items: [[RawFlavor(type: "public.png", data: png)]], imageWidth: 4, imageHeight: 3))!
        check(clip.kind == .image, #line)
        check(store.firstData(of: clip, preferring: ["public.png"]) == png, #line)
        store.saveNow()

        let reloaded = ClipStore(directory: dir)
        reloaded.load()
        check(reloaded.clips.count == 1, #line)
        check(reloaded.clips.first?.title == "Image 4 × 3", #line)
        reloaded.delete(clip.id)
        check(reloaded.firstData(of: clip, preferring: ["public.png"]) == nil, #line)
    }

    func testSearchFilterEditAndClear() {
        let store = ClipStore(directory: dir)
        store.add(text("Quarterly partner review"))
        let link = store.add(text("https://github.com"))!
        check(store.search("partner REVIEW").count == 1, #line)
        check(store.search("", filter: .links).map(\.id) == [link.id], #line)
        check(store.search("notes").count == 2, #line)

        store.updateText(link.id, text: "edited text")
        check(store.clips.first { $0.id == link.id }?.kind == .text, #line)
        store.togglePin(link.id)
        store.clear(keepPinned: true)
        check(store.clips.map(\.title) == ["edited text"], #line)
    }
}


@MainActor func runAll() {
    let p = PasteboardTypesTests()
    p.testClassification(); p.testSensitiveMarkers(); p.testTitles()
    for t in [{ ClipStoreTests().testAddDedupeAndOrder() }, { ClipStoreTests().testPinnedSurvivesTrimAndSortsFirst() },
              { ClipStoreTests().testPersistenceAndBlobs() }, { ClipStoreTests().testSearchFilterEditAndClear() }] { t() }
    print("\(checks) checks, \(failures) failures")
    exit(failures == 0 ? 0 : 1)
}
MainActor.assumeIsolated { runAll() }
