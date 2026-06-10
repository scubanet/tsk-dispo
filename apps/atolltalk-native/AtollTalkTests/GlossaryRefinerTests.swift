import Testing
@testable import AtollTalk

/// Records calls so a test can assert whether refinement ran and with what input.
private actor RefineSpy {
  private(set) var calls: [(mt: String, target: AppLanguage, glossary: String)] = []
  func record(_ mt: String, _ target: AppLanguage, _ glossary: String) {
    calls.append((mt, target, glossary))
  }
  var count: Int { calls.count }
}

private struct EchoTranslator: Translator {
  func translate(_ text: String, from: AppLanguage, to: AppLanguage,
                 context: String, glossary: String) async throws -> String { "mt:\(text)" }
}

@Suite struct GlossaryRefinerTests {
  @Test func emptyGlossarySkipsRefine() async throws {
    let spy = RefineSpy()
    let refiner = GlossaryRefiner(base: EchoTranslator()) { mt, target, glossary in
      await spy.record(mt, target, glossary); return "refined:\(mt)"
    }
    let out = try await refiner.translate("hi", from: .de, to: .uk, context: "", glossary: "   ")
    #expect(out == "mt:hi")
    #expect(await spy.count == 0)
  }

  @Test func nonEmptyGlossaryRunsRefineOnMTOutput() async throws {
    let spy = RefineSpy()
    let refiner = GlossaryRefiner(base: EchoTranslator()) { mt, target, glossary in
      await spy.record(mt, target, glossary); return "refined:\(mt)"
    }
    let out = try await refiner.translate("hi", from: .de, to: .es,
                                          context: "", glossary: "Pfanne = sartén")
    #expect(out == "refined:mt:hi")
    let calls = await spy.calls
    #expect(calls.count == 1)
    #expect(calls.first?.mt == "mt:hi")
    #expect(calls.first?.target == .es)
  }
}
