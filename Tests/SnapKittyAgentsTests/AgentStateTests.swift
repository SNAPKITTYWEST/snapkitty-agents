import XCTest
@testable import SnapKittyAgents

final class AgentStateTests: XCTestCase {

    func testTerminalStates() {
        XCTAssertTrue(AgentState.completed.isTerminal)
        XCTAssertTrue(AgentState.failed.isTerminal)
        XCTAssertTrue(AgentState.terminated.isTerminal)
        XCTAssertFalse(AgentState.ready.isTerminal)
        XCTAssertFalse(AgentState.executing.isTerminal)
    }

    func testActiveStates() {
        XCTAssertTrue(AgentState.ready.isActive)
        XCTAssertTrue(AgentState.planning.isActive)
        XCTAssertTrue(AgentState.executing.isActive)
        XCTAssertTrue(AgentState.waiting.isActive)
        XCTAssertFalse(AgentState.created.isActive)
        XCTAssertFalse(AgentState.completed.isActive)
        XCTAssertFalse(AgentState.failed.isActive)
    }

    func testRoundTripCodable() throws {
        for state in AgentState.allCases {
            let encoded = try JSONEncoder().encode(state)
            let decoded = try JSONDecoder().decode(AgentState.self, from: encoded)
            XCTAssertEqual(state, decoded)
        }
    }

    func testSearchStageProgress() {
        XCTAssertEqual(SearchStage.user_query.index, 0)
        XCTAssertEqual(SearchStage.done.index, SearchStage.allCases.count - 2)
        XCTAssertGreaterThan(SearchStage.done.progress, SearchStage.user_query.progress)
    }
}

final class CommandValidationTests: XCTestCase {

    func testNavigateAcceptsHTTP() throws {
        let cmd = try AgentCommand.navigate(url: "https://example.com")
        XCTAssertEqual(cmd.op, "navigate")
    }

    func testNavigateRejectsInvalidScheme() {
        XCTAssertThrowsError(try AgentCommand.navigate(url: "ftp://example.com"))
    }

    func testSelectorTooLong() {
        let longSel = String(repeating: "a", count: 2048)
        XCTAssertThrowsError(try AgentCommand.click(selector: longSel))
    }

    func testScrollInRange() throws {
        let cmd = try AgentCommand.scroll(deltaY: 500)
        XCTAssertEqual(cmd.op, "scroll")
    }

    func testScrollOutOfRange() {
        XCTAssertThrowsError(try AgentCommand.scroll(deltaY: 200_000))
        XCTAssertThrowsError(try AgentCommand.scroll(deltaY: -200_000))
    }

    func testTypeTextTooLong() {
        let longText = String(repeating: "x", count: 10_001)
        XCTAssertThrowsError(try AgentCommand.type_(selector: "input", text: longText))
    }

    func testCommandToRequestBody() throws {
        let cmd = try AgentCommand.navigate(url: "https://example.com")
        let body = cmd.toRequestBody()
        XCTAssertEqual(body["tool"] as? String, "browser")
        XCTAssertEqual(body["op"] as? String, "navigate")
        let args = body["args"] as? [String: Any]
        XCTAssertEqual(args?["url"] as? String, "https://example.com")
    }
}

final class EventDecodingTests: XCTestCase {

    let sampleEventJSON = """
    {
      "event_id": "evt_abc123",
      "category": "agent.action.completed",
      "subject": {"type": "agent", "id": "agent_xyz"},
      "operation_id": "op_001",
      "data": {"agent_id": "agent_xyz", "action_count": 5, "tool": "browser", "op": "navigate"},
      "emitted_at_ms": 1720000000000
    }
    """.data(using: .utf8)!

    func testDecodeKnownEvent() throws {
        let event = try JSONDecoder.hk.decode(BrowserEvent.self, from: sampleEventJSON)
        XCTAssertEqual(event.event_id, "evt_abc123")
        XCTAssertEqual(event.eventType, .agentActionCompleted)
        XCTAssertEqual(event.agentId, "agent_xyz")
        XCTAssertEqual(event.actionCount, 5)
    }

    func testUnknownCategoryDoesNotCrash() throws {
        let unknownJSON = """
        {
          "event_id": "evt_unk",
          "category": "future.event.type.not.yet.known",
          "subject": null,
          "operation_id": null,
          "data": {},
          "emitted_at_ms": 1720000000000
        }
        """.data(using: .utf8)!
        let event = try JSONDecoder.hk.decode(BrowserEvent.self, from: unknownJSON)
        XCTAssertEqual(event.eventType, .unknown)
    }

    func testTelemetryAccumulation() {
        var t = AgentTelemetry.empty(agentId: "a1", model: "K1")
        XCTAssertEqual(t.eventCount, 0)
        XCTAssertEqual(t.errorCount, 0)

        let event = try! JSONDecoder.hk.decode(BrowserEvent.self, from: sampleEventJSON)
        t.record(event: event)
        XCTAssertEqual(t.eventCount, 1)
        XCTAssertEqual(t.errorCount, 0)
        XCTAssertEqual(t.actionCount, 5)
    }
}
