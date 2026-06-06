import Testing
@testable import DiveLog_Pro

@Suite("SkillStatus")
struct SkillStatusTests {
    @Test("cycleNext progresses notStarted → introduced → practiced → mastered")
    func cycleNextProgression() {
        #expect(SkillStatus.notStarted.cycleNext == .introduced)
        #expect(SkillStatus.introduced.cycleNext == .practiced)
        #expect(SkillStatus.practiced.cycleNext == .mastered)
    }

    @Test("cycleNext from mastered resets to notStarted")
    func cycleFromMasteredResets() {
        #expect(SkillStatus.mastered.cycleNext == .notStarted)
    }

    @Test("cycleNext from needsReview resolves to practiced")
    func cycleFromNeedsReviewResolves() {
        #expect(SkillStatus.needsReview.cycleNext == .practiced)
    }

    @Test("raw values round-trip")
    func rawValueRoundTrip() {
        for status in SkillStatus.allCases {
            #expect(SkillStatus(rawValue: status.rawValue) == status)
        }
    }
}
