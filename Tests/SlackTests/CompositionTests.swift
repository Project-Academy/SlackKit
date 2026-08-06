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

@Suite("Buttons")
struct ButtonTests {

    /// Full-fat decode: every documented button field survives the round trip.
    @Test("a button with style, confirm and accessibility_label round-trips")
    func fullFatButtonRoundTrips() throws {
        let json = """
        {
          "type": "actions",
          "elements": [
            { "type": "button",
              "text": { "type": "plain_text", "text": "Book Out" },
              "action_id": "book_out",
              "value": "tute_42",
              "style": "danger",
              "accessibility_label": "Book out of this tutorial",
              "confirm": {
                "title": { "type": "plain_text", "text": "Book out?" },
                "text": { "type": "mrkdwn", "text": "You'll lose your spot." },
                "confirm": { "type": "plain_text", "text": "Book Out" },
                "deny": { "type": "plain_text", "text": "Stay" }
              } }
          ]
        }
        """
        let block = try decoder.decode(Block.self, from: Data(json.utf8))
        guard case let .button(button)? = block.actions?.first else {
            Issue.record("expected a button"); return
        }
        #expect(button.style == .danger)
        #expect(button.confirm?.title.text == "Book out?")
        #expect(button.accessibility_label == "Book out of this tutorial")

        let encoded = try encodeToObject(block)
        let element = try #require((encoded["elements"] as? [[String: Any]])?.first)
        #expect(element["type"] as? String == "button")
        #expect(element["style"] as? String == "danger")
        #expect((element["confirm"] as? [String: Any])?["deny"] != nil)
        #expect(try decoder.decode(Block.self, from: encoder.encode(block)) == block)
    }

    @Test("a workflow_button writes its type and carries its trigger")
    func workflowButtonRoundTrips() throws {
        let element = Block.ActionElement.workflowButton(.init(
            text: Block.Text(plain: "Run report"),
            workflow: .init(trigger: .init(url: "https://slack.com/shortcuts/Ft1/x")),
            action_id: "run_report"
        ))
        let block = Block(type: "actions", actions: [element])

        let encoded = try encodeToObject(block)
        let wire = try #require((encoded["elements"] as? [[String: Any]])?.first)
        #expect(wire["type"] as? String == "workflow_button")
        let workflow = try #require(wire["workflow"] as? [String: Any])
        #expect((workflow["trigger"] as? [String: Any])?["url"] as? String == "https://slack.com/shortcuts/Ft1/x")

        #expect(try decoder.decode(Block.self, from: encoder.encode(block)) == block)
    }
}

@Suite("Element wave 1")
struct ElementWave1Tests {

    /// Spec-derived fixture per element type: decoding must land in the
    /// matching typed case (not `.unknown`), and the round trip must be
    /// value-equal with the `type` back on the wire.
    @Test("each element type decodes to its case and round-trips", arguments: [
        ("static_select", #"{"type": "static_select", "placeholder": {"type": "plain_text", "text": "Pick"}, "options": [{"text": {"type": "plain_text", "text": "A"}, "value": "a"}], "initial_option": {"text": {"type": "plain_text", "text": "A"}, "value": "a"}, "action_id": "s1"}"#),
        ("external_select", #"{"type": "external_select", "min_query_length": 2, "action_id": "s2"}"#),
        ("users_select", #"{"type": "users_select", "initial_user": "U123", "focus_on_load": true}"#),
        ("conversations_select", #"{"type": "conversations_select", "default_to_current_conversation": true, "filter": {"include": ["im", "public"], "exclude_bot_users": true}}"#),
        ("channels_select", #"{"type": "channels_select", "initial_channel": "C123", "response_url_enabled": true}"#),
        ("multi_static_select", #"{"type": "multi_static_select", "option_groups": [{"label": {"type": "plain_text", "text": "G"}, "options": [{"text": {"type": "plain_text", "text": "A"}, "value": "a"}]}], "max_selected_items": 3}"#),
        ("multi_external_select", #"{"type": "multi_external_select", "min_query_length": 1, "initial_options": [{"text": {"type": "plain_text", "text": "A"}, "value": "a"}]}"#),
        ("multi_users_select", #"{"type": "multi_users_select", "initial_users": ["U1", "U2"], "max_selected_items": 5}"#),
        ("multi_conversations_select", #"{"type": "multi_conversations_select", "initial_conversations": ["C1"], "filter": {"exclude_external_shared_channels": true}}"#),
        ("multi_channels_select", #"{"type": "multi_channels_select", "initial_channels": ["C1", "C2"]}"#),
        ("overflow", #"{"type": "overflow", "options": [{"text": {"type": "plain_text", "text": "Edit"}, "value": "e", "url": "https://example.com"}], "action_id": "o1"}"#),
        ("datepicker", #"{"type": "datepicker", "initial_date": "2026-08-06", "placeholder": {"type": "plain_text", "text": "Date"}}"#),
        ("timepicker", #"{"type": "timepicker", "initial_time": "13:30", "timezone": "Australia/Sydney"}"#),
        ("datetimepicker", #"{"type": "datetimepicker", "initial_date_time": 1754452800}"#),
        ("checkboxes", #"{"type": "checkboxes", "options": [{"text": {"type": "mrkdwn", "text": "*A*"}, "value": "a", "description": {"type": "plain_text", "text": "d"}}], "initial_options": [{"text": {"type": "mrkdwn", "text": "*A*"}, "value": "a", "description": {"type": "plain_text", "text": "d"}}]}"#),
        ("radio_buttons", #"{"type": "radio_buttons", "options": [{"text": {"type": "plain_text", "text": "A"}, "value": "a"}], "initial_option": {"text": {"type": "plain_text", "text": "A"}, "value": "a"}}"#),
        ("image", #"{"type": "image", "image_url": "https://example.com/x.png", "alt_text": "an image"}"#),
    ])
    func elementRoundTrips(type: String, fixture: String) throws {
        let element = try decoder.decode(Block.ActionElement.self, from: Data(fixture.utf8))

        if case let .unknown(unknownType, _) = element {
            Issue.record("\(type) decoded as .unknown(\(unknownType))")
            return
        }

        let encoded = try encodeToObject(element)
        #expect(encoded["type"] as? String == type)

        // Value-equal round trip through the single pipeline.
        let again = try decoder.decode(Block.ActionElement.self, from: encoder.encode(element))
        #expect(again == element)

        // And the original fixture's keys all survive the round trip.
        let original = try #require(JSONSerialization.jsonObject(with: Data(fixture.utf8)) as? [String: Any])
        #expect(Set(encoded.keys) == Set(original.keys))
    }

    @Test("a slack_file image element keeps its file reference")
    func slackFileImageElement() throws {
        let element = Block.ActionElement.image(.init(slackFile: .init(id: "F42"), altText: "chart"))
        let encoded = try encodeToObject(element)
        #expect((encoded["slack_file"] as? [String: Any])?["id"] as? String == "F42")
        #expect(encoded["image_url"] == nil)
        #expect(try decoder.decode(Block.ActionElement.self, from: encoder.encode(element)) == element)
    }

    @Test("the actions builder produces a well-formed block")
    func actionsBuilder() throws {
        let block = Block.actions([
            .button(.init(text: .init(plain: "Book Out"), action_id: "book_out", style: .danger)),
            .usersSelect(.init(placeholder: "Who?")),
        ])
        let encoded = try encodeToObject(block)
        #expect(encoded["type"] as? String == "actions")
        #expect((encoded["elements"] as? [[String: Any]])?.count == 2)
        #expect(try decoder.decode(Block.self, from: encoder.encode(block)) == block)
    }
}
