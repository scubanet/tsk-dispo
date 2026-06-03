import XCTest
@testable import AtollHub

final class KomboxFilterTests: XCTestCase {
  private func conv(_ id: String, name: String, kind: KomboxKind, preview: String) -> KomboxConversation {
    let e = KomboxEvent(id: id, contactId: id, contactName: name, kind: kind,
                        direction: .inbound, summary: preview, body: preview, subject: nil,
                        timestamp: Date(timeIntervalSince1970: 1), status: "open")
    return KomboxConversation(id: id, contactName: name, lastEvent: e)
  }

  func test_channelAllKeepsEverything() {
    let cs = [conv("1", name: "Anna", kind: .whatsapp, preview: "hi"),
              conv("2", name: "Ben", kind: .email, preview: "re"),
              conv("3", name: "C", kind: .system, preview: "note")]
    XCTAssertEqual(KomboxFilter.apply(cs, channel: .all, search: "").count, 3)
  }

  func test_channelWhatsappOnly() {
    let cs = [conv("1", name: "Anna", kind: .whatsapp, preview: "hi"),
              conv("2", name: "Ben", kind: .email, preview: "re")]
    let out = KomboxFilter.apply(cs, channel: .whatsapp, search: "")
    XCTAssertEqual(out.map(\.id), ["1"])
  }

  func test_searchMatchesNameOrPreviewCaseInsensitive() {
    let cs = [conv("1", name: "Anna Muster", kind: .whatsapp, preview: "Tauchgang"),
              conv("2", name: "Ben", kind: .whatsapp, preview: "hallo")]
    XCTAssertEqual(KomboxFilter.apply(cs, channel: .all, search: "muster").map(\.id), ["1"])
    XCTAssertEqual(KomboxFilter.apply(cs, channel: .all, search: "HALLO").map(\.id), ["2"])
  }
}
