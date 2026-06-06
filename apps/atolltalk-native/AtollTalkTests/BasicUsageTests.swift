import Testing
import Foundation
@testable import AtollTalk

@MainActor @Suite struct BasicUsageTests {
  @Test func countsAndPersistsPerDay() {
    let d = UserDefaults(suiteName: "atolltalk.test.\(UUID())")!
    let s = SettingsStore(defaults: d)
    #expect(s.basicUsageToday() == 0)
    s.bumpBasicUsage()
    s.bumpBasicUsage()
    #expect(s.basicUsageToday() == 2)
    // Persisted across reopen.
    let s2 = SettingsStore(defaults: d)
    #expect(s2.basicUsageToday() == 2)
  }
}
