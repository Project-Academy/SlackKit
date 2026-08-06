//
//  CompositionTests.swift
//  SlackKit
//
//  Round-trip cover for the Block Kit composition objects, with fixtures
//  derived from docs/systems/comms/blockkit-spec-2026-08.md §5. If one of
//  these fails, the wire format has drifted from what Slack accepts.
//

import Foundation
import Testing
@testable import Slack

private let decoder = JSONDecoder()
private let encoder = JSONEncoder()

private func roundTrip<T: Codable & Equatable>(_ value: T) throws -> T {
    try decoder.decode(T.self, from: encoder.encode(value))
}

private func encodeToObject(_ value: some Encodable) throws -> [String: Any] {
    let data = try encoder.encode(value)
    return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
}

@Suite("Composition objects")
struct CompositionTests {

    @Test("confirmation dialog round-trips with plain_text fields")
    func confirmRoundTrips() throws {
        let confirm = Block.Confirm(
            title: "Book out?",
            text: "You'll be removed from this tute.",
            confirm: "Book Out",
            deny: "Stay",
            style: .danger
        )
        #expect(try roundTrip(confirm) == confirm)

        let encoded = try encodeToObject(confirm)
        let title = try #require(encoded["title"] as? [String: Any])
        #expect(title["type"] as? String == "plain_text")
        #expect(encoded["style"] as? String == "danger")
    }

    @Test("an undocumented style value decodes rather than throws")
    func unknownStyleTolerated() throws {
        let style = try decoder.decode(Block.Style.self, from: Data(#""subtle""#.utf8))
        #expect(style.rawValue == "subtle")
    }

    @Test("option carries value and optional description/url")
    func optionRoundTrips() throws {
        let option = Block.Option("Chemistry", value: "chem", description: "HSC course", url: "https://example.com")
        #expect(try roundTrip(option) == option)

        let encoded = try encodeToObject(option)
        #expect(encoded["value"] as? String == "chem")
        #expect((encoded["text"] as? [String: Any])?["text"] as? String == "Chemistry")
    }

    @Test("option group nests its options")
    func optionGroupRoundTrips() throws {
        let group = Block.OptionGroup(label: "Sciences", options: [
            .init("Chemistry", value: "chem"),
            .init("Physics", value: "phys"),
        ])
        #expect(try roundTrip(group) == group)

        let encoded = try encodeToObject(group)
        #expect((encoded["options"] as? [[String: Any]])?.count == 2)
    }

    @Test("conversation filter uses Slack's field names")
    func filterRoundTrips() throws {
        let filter = Block.Filter(include: [.im, .publicChannels], excludeBotUsers: true)
        #expect(try roundTrip(filter) == filter)

        let encoded = try encodeToObject(filter)
        #expect(encoded["include"] as? [String] == ["im", "public"])
        #expect(encoded["exclude_bot_users"] as? Bool == true)
        #expect(encoded["exclude_external_shared_channels"] == nil)
    }

    @Test("dispatch action config round-trips its trigger list")
    func dispatchConfigRoundTrips() throws {
        let config = Block.DispatchActionConfig(triggerActionsOn: [.onEnterPressed, .onCharacterEntered])
        #expect(try roundTrip(config) == config)

        let encoded = try encodeToObject(config)
        #expect(encoded["trigger_actions_on"] as? [String] == ["on_enter_pressed", "on_character_entered"])
    }

    @Test("slack file initialisers keep url and id mutually exclusive")
    func slackFileExclusive() throws {
        let byURL = Block.SlackFile(url: "https://files.slack.com/x")
        let byID = Block.SlackFile(id: "F1234")

        let encodedURL = try encodeToObject(byURL)
        #expect(encodedURL["url"] as? String == "https://files.slack.com/x")
        #expect(encodedURL["id"] == nil)

        let encodedID = try encodeToObject(byID)
        #expect(encodedID["id"] as? String == "F1234")
        #expect(encodedID["url"] == nil)
    }

    @Test("workflow trigger carries typed name/value parameters")
    func workflowRoundTrips() throws {
        let workflow = Block.Workflow(trigger: .init(
            url: "https://slack.com/shortcuts/Ft123/abc",
            customizableInputParameters: [
                .init(name: "tute_id", value: .string("T42")),
                .init(name: "attempt", value: .number(2)),
            ]
        ))
        #expect(try roundTrip(workflow) == workflow)

        let encoded = try encodeToObject(workflow)
        let trigger = try #require(encoded["trigger"] as? [String: Any])
        let params = try #require(trigger["customizable_input_parameters"] as? [[String: Any]])
        #expect(params[0]["name"] as? String == "tute_id")
        #expect(params[1]["value"] as? Double == 2)
    }

    @Test("slack icon writes its fixed type and tolerates unknown names")
    func slackIconRoundTrips() throws {
        let icon = Block.SlackIcon("calendar")
        #expect(try roundTrip(icon) == icon)

        let encoded = try encodeToObject(icon)
        #expect(encoded["type"] as? String == "icon")
        #expect(encoded["name"] as? String == "calendar")

        // A name Slack ships after this kit was written must still decode.
        let future = try decoder.decode(Block.SlackIcon.self, from: Data(#"{"type": "icon", "name": "hologram"}"#.utf8))
        #expect(future.name == "hologram")
    }
}
