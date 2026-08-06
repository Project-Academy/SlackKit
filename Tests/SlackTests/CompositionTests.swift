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

@Suite("Element wave 2 — inputs")
struct ElementWave2Tests {

    @Test("each input element type decodes to its case and round-trips", arguments: [
        ("plain_text_input", #"{"type": "plain_text_input", "multiline": true, "min_length": 1, "max_length": 500, "placeholder": {"type": "plain_text", "text": "Notes"}, "dispatch_action_config": {"trigger_actions_on": ["on_enter_pressed"]}}"#),
        ("rich_text_input", #"{"type": "rich_text_input", "action_id": "r1", "min_lines": 2, "max_lines": 10, "initial_value": {"type": "rich_text", "elements": [{"type": "rich_text_section", "elements": [{"type": "text", "text": "hi"}]}]}}"#),
        ("email_text_input", #"{"type": "email_text_input", "initial_value": "x@y.z", "focus_on_load": true}"#),
        ("url_text_input", #"{"type": "url_text_input", "placeholder": {"type": "plain_text", "text": "Link"}}"#),
        ("number_input", #"{"type": "number_input", "is_decimal_allowed": false, "min_value": "1", "max_value": "10", "initial_value": "5"}"#),
        ("file_input", #"{"type": "file_input", "filetypes": ["pdf", "png"], "max_files": 3, "action_id": "f1"}"#),
    ])
    func inputElementRoundTrips(type: String, fixture: String) throws {
        let element = try decoder.decode(Block.ActionElement.self, from: Data(fixture.utf8))

        if case let .unknown(unknownType, _) = element {
            Issue.record("\(type) decoded as .unknown(\(unknownType))")
            return
        }

        let encoded = try encodeToObject(element)
        #expect(encoded["type"] as? String == type)

        let again = try decoder.decode(Block.ActionElement.self, from: encoder.encode(element))
        #expect(again == element)

        let original = try #require(JSONSerialization.jsonObject(with: Data(fixture.utf8)) as? [String: Any])
        #expect(Set(encoded.keys) == Set(original.keys))
    }
}

@Suite("Input block and section accessory")
struct InputBlockTests {

    @Test("an input block round-trips label, element, hint and flags")
    func inputBlockRoundTrips() throws {
        let json = """
        {
          "type": "input",
          "block_id": "i1",
          "label": { "type": "plain_text", "text": "Pick a course" },
          "element": { "type": "static_select",
                       "action_id": "course",
                       "options": [ { "text": { "type": "plain_text", "text": "Chem" }, "value": "c" } ] },
          "hint": { "type": "plain_text", "text": "One only" },
          "optional": true,
          "dispatch_action": false
        }
        """
        let block = try decoder.decode(Block.self, from: Data(json.utf8))
        let input = try #require(block.input)
        #expect(input.label.text == "Pick a course")
        #expect(input.optional == true)
        guard case .staticSelect = input.element else {
            Issue.record("expected static_select element"); return
        }

        let encoded = try encodeToObject(block)
        #expect(encoded["type"] as? String == "input")
        #expect(encoded["block_id"] as? String == "i1")
        #expect((encoded["label"] as? [String: Any])?["text"] as? String == "Pick a course")
        #expect((encoded["element"] as? [String: Any])?["type"] as? String == "static_select")

        #expect(try decoder.decode(Block.self, from: encoder.encode(block)) == block)
    }

    @Test("the input builder produces a well-formed block")
    func inputBuilder() throws {
        let block = Block.input(
            label: "Email",
            element: .emailTextInput(.init(placeholder: "you@example.com")),
            hint: "School address",
            optional: true
        )
        let encoded = try encodeToObject(block)
        #expect(encoded["type"] as? String == "input")
        #expect((encoded["element"] as? [String: Any])?["type"] as? String == "email_text_input")
        #expect(try decoder.decode(Block.self, from: encoder.encode(block)) == block)
    }

    @Test("a section with an image accessory round-trips — the Backpack shape")
    func sectionImageAccessory() throws {
        let block = Block.section("*Zoom tute* with your leader", accessory: .image(.init(url: "https://example.com/leader.png", altText: "Leader")))

        let encoded = try encodeToObject(block)
        let accessory = try #require(encoded["accessory"] as? [String: Any])
        #expect(accessory["type"] as? String == "image")
        #expect(accessory["alt_text"] as? String == "Leader")

        #expect(try decoder.decode(Block.self, from: encoder.encode(block)) == block)
    }

    @Test("a section with a button accessory decodes from the wire")
    func sectionButtonAccessory() throws {
        let block = try decoder.decode(Block.self, from: Data("""
        {
          "type": "section",
          "text": { "type": "mrkdwn", "text": "Upcoming tute" },
          "accessory": { "type": "button",
                         "text": { "type": "plain_text", "text": "Book Out" },
                         "action_id": "book_out" },
          "expand": true
        }
        """.utf8))
        guard case .button = block.accessory else {
            Issue.record("expected button accessory"); return
        }
        #expect(block.expand == true)
        #expect(try decoder.decode(Block.self, from: encoder.encode(block)) == block)
    }

    @Test("existing plain sections are unaffected")
    func plainSectionUnchanged() throws {
        let block = Block.section("hello")
        let encoded = try encodeToObject(block)
        #expect(encoded["accessory"] == nil)
        #expect(encoded["expand"] == nil)
        #expect(Set(encoded.keys) == ["type", "text"])
    }
}

@Suite("Display blocks")
struct DisplayBlockTests {

    @Test("an image block round-trips with url, alt_text and title")
    func imageBlockRoundTrips() throws {
        let block = Block.image(url: "https://example.com/x.png", altText: "a chart", title: "Results")
        let encoded = try encodeToObject(block)
        #expect(encoded["type"] as? String == "image")
        #expect(encoded["image_url"] as? String == "https://example.com/x.png")
        #expect(encoded["alt_text"] as? String == "a chart")
        #expect((encoded["title"] as? [String: Any])?["type"] as? String == "plain_text")
        #expect(try decoder.decode(Block.self, from: encoder.encode(block)) == block)
    }

    @Test("a video block round-trips its full field set")
    func videoBlockRoundTrips() throws {
        let block = Block.video(.init(
            title: "Tute recording",
            videoURL: "https://example.com/embed/1",
            thumbnailURL: "https://example.com/thumb.png",
            altText: "Recording of the tute",
            titleURL: "https://example.com/watch/1",
            description: "Week 3",
            authorName: "Project Academy",
            providerName: "Example"
        ))
        let encoded = try encodeToObject(block)
        #expect(encoded["type"] as? String == "video")
        #expect(encoded["video_url"] as? String == "https://example.com/embed/1")
        #expect((encoded["description"] as? [String: Any])?["text"] as? String == "Week 3")
        #expect(try decoder.decode(Block.self, from: encoder.encode(block)) == block)
    }

    @Test("a file block decodes from the wire shape Slack sends")
    func fileBlockDecodes() throws {
        let block = try decoder.decode(Block.self, from: Data(#"{"type": "file", "external_id": "ABCD1", "source": "remote", "block_id": "f1"}"#.utf8))
        #expect(block.file?.external_id == "ABCD1")
        #expect(block.file?.source == "remote")

        let encoded = try encodeToObject(block)
        #expect(encoded["external_id"] as? String == "ABCD1")
        #expect(encoded["block_id"] as? String == "f1")
        #expect(try decoder.decode(Block.self, from: encoder.encode(block)) == block)
    }

    @Test("a markdown block's text is a raw string on the wire")
    func markdownBlockRoundTrips() throws {
        let block = Block.markdown("**Lots of information here!!**")
        let encoded = try encodeToObject(block)
        #expect(encoded["type"] as? String == "markdown")
        #expect(encoded["text"] as? String == "**Lots of information here!!**")

        let decoded = try decoder.decode(Block.self, from: Data(#"{"type": "markdown", "text": "*Hi* there"}"#.utf8))
        #expect(decoded.markdown?.text == "*Hi* there")
        #expect(decoded.text == nil)
        #expect(try decoder.decode(Block.self, from: encoder.encode(block)) == block)
    }

    @Test("an alert block matches Slack's example shape: text object + string level")
    func alertBlockRoundTrips() throws {
        let block = Block.alert("Heads up — LEAP week", level: .warning)
        let encoded = try encodeToObject(block)
        #expect(encoded["type"] as? String == "alert")
        #expect(encoded["level"] as? String == "warning")
        #expect((encoded["text"] as? [String: Any])?["type"] as? String == "mrkdwn")

        // Slack's own documented example decodes.
        let decoded = try decoder.decode(Block.self, from: Data(#"{"type": "alert", "text": {"type": "mrkdwn", "text": "hi", "verbatim": false}, "level": "info"}"#.utf8))
        #expect(decoded.alert?.level == .info)
        #expect(try decoder.decode(Block.self, from: encoder.encode(block)) == block)
    }

    @Test("a header with a level round-trips; plain headers are unchanged")
    func headerLevel() throws {
        let levelled = Block.header("Results", level: 2)
        let encoded = try encodeToObject(levelled)
        #expect(encoded["level"] as? Int == 2)
        #expect(try decoder.decode(Block.self, from: encoder.encode(levelled)) == levelled)

        let plain = try encodeToObject(Block.header("Results"))
        #expect(plain["level"] == nil)
    }

    @Test("the mixed context builder carries images and text — the Backpack shape")
    func mixedContextBuilder() throws {
        let block = Block.context([
            .image(url: "https://example.com/leader.png", altText: "Leader"),
            .text(.init("*Alex* is hosting")),
        ])
        let encoded = try encodeToObject(block)
        let elements = try #require(encoded["elements"] as? [[String: Any]])
        #expect(elements[0]["type"] as? String == "image")
        #expect(elements[1]["type"] as? String == "mrkdwn")
        #expect(try decoder.decode(Block.self, from: encoder.encode(block)) == block)
    }
}

@Suite("Data visualization")
struct DataVisualizationTests {

    @Test("a pie chart round-trips segments")
    func pieRoundTrips() throws {
        let block = Block.dataVisualization(title: "Marks by course", chart: .pie(segments: [
            .init("Chemistry", value: 60),
            .init("Physics", value: 40),
        ]))
        let encoded = try encodeToObject(block)
        #expect(encoded["type"] as? String == "data_visualization")
        #expect(encoded["title"] as? String == "Marks by course")
        let chart = try #require(encoded["chart"] as? [String: Any])
        #expect(chart["type"] as? String == "pie")
        #expect((chart["segments"] as? [[String: Any]])?.count == 2)
        #expect(try decoder.decode(Block.self, from: encoder.encode(block)) == block)
    }

    @Test("bar, area and line charts carry series and axis_config", arguments: ["bar", "area", "line"])
    func seriesChartsRoundTrip(kind: String) throws {
        let axis = Block.Chart.AxisConfig(categories: ["Mon", "Tue"], xLabel: "Day", yLabel: "Marks")
        let series = [Block.Chart.Series("2026", data: [.init("Mon", value: 4), .init("Tue", value: -1)])]
        let chart: Block.Chart = switch kind {
        case "bar":  .bar(series: series, axis: axis)
        case "area": .area(series: series, axis: axis)
        default:     .line(series: series, axis: axis)
        }
        let block = Block.dataVisualization(title: "Weekly", chart: chart)

        let encoded = try encodeToObject(block)
        let wire = try #require(encoded["chart"] as? [String: Any])
        #expect(wire["type"] as? String == kind)
        #expect((wire["axis_config"] as? [String: Any])?["categories"] as? [String] == ["Mon", "Tue"])
        #expect(try decoder.decode(Block.self, from: encoder.encode(block)) == block)
    }

    @Test("an unknown chart kind round-trips verbatim")
    func unknownChartTolerated() throws {
        let json = #"{"type": "data_visualization", "title": "X", "chart": {"type": "scatter", "points": [1, 2]}}"#
        let block = try decoder.decode(Block.self, from: Data(json.utf8))
        guard case let .unknown(type, raw)? = block.dataVisualization?.chart else {
            Issue.record("expected unknown chart"); return
        }
        #expect(type == "scatter")
        #expect(raw["points"] == .array([.number(1), .number(2)]))

        let encoded = try encodeToObject(block)
        #expect(((encoded["chart"] as? [String: Any])?["type"]) as? String == "scatter")
        #expect(try decoder.decode(Block.self, from: encoder.encode(block)) == block)
    }
}

@Suite("Tables")
struct TableTests {

    @Test("a table round-trips cells and positional column settings with a null gap")
    func tableRoundTrips() throws {
        let block = Block.table(
            rows: [
                [.rawText("Course"), .rawText("Marks")],
                [.rawText("Chemistry"), .rawNumber(value: 42, text: "42")],
            ],
            columnSettings: [nil, .init(align: .right, isWrapped: false)]
        )
        let encoded = try encodeToObject(block)
        #expect(encoded["type"] as? String == "table")
        let rows = try #require(encoded["rows"] as? [[[String: Any]]])
        #expect(rows[1][1]["type"] as? String == "raw_number")
        #expect(rows[1][1]["value"] as? Double == 42)
        let settings = try #require(encoded["column_settings"] as? [Any])
        #expect(settings[0] is NSNull)
        #expect((settings[1] as? [String: Any])?["align"] as? String == "right")
        #expect(try decoder.decode(Block.self, from: encoder.encode(block)) == block)
    }

    @Test("a data_table round-trips caption, paging and rich_text cells")
    func dataTableRoundTrips() throws {
        let json = """
        {
          "type": "data_table",
          "caption": "Marks by course",
          "page_size": 10,
          "row_header_column_index": 0,
          "rows": [
            [ { "type": "raw_text", "text": "Course" }, { "type": "raw_text", "text": "Notes" } ],
            [ { "type": "raw_text", "text": "Chem" },
              { "type": "rich_text",
                "elements": [ { "type": "rich_text_section",
                                "elements": [ { "type": "text", "text": "solid" } ] } ] } ]
          ]
        }
        """
        let block = try decoder.decode(Block.self, from: Data(json.utf8))
        let table = try #require(block.dataTable)
        #expect(table.caption == "Marks by course")
        #expect(table.page_size == 10)
        guard case .richText = table.rows[1][1] else {
            Issue.record("expected rich_text cell"); return
        }
        #expect(try decoder.decode(Block.self, from: encoder.encode(block)) == block)
    }

    @Test("an unknown cell kind round-trips verbatim")
    func unknownCellTolerated() throws {
        let json = #"{"type": "table", "rows": [[{"type": "sparkline", "points": [1]}]]}"#
        let block = try decoder.decode(Block.self, from: Data(json.utf8))
        guard case let .unknown(type, _)? = block.table?.rows.first?.first else {
            Issue.record("expected unknown cell"); return
        }
        #expect(type == "sparkline")
        #expect(try decoder.decode(Block.self, from: encoder.encode(block)) == block)
    }
}

@Suite("Cards")
struct CardTests {

    @Test("a full card round-trips: hero image, slack icon, texts and buttons")
    func fullCardRoundTrips() throws {
        let block = Block.card(.init(
            title: "*Upcoming tute*",
            subtitle: "Thursday 4pm",
            body: "Chemistry with your leader",
            subtext: "Room 2",
            heroImage: .init(url: "https://example.com/hero.png", altText: "Tute"),
            slackIcon: .init("calendar"),
            actions: [
                .button(.init(text: .init(plain: "Book Out"), action_id: "book_out", value: "tute_42", style: .danger)),
            ]
        ))
        let encoded = try encodeToObject(block)
        #expect(encoded["type"] as? String == "card")
        #expect((encoded["title"] as? [String: Any])?["type"] as? String == "mrkdwn")
        #expect((encoded["hero_image"] as? [String: Any])?["alt_text"] as? String == "Tute")
        #expect((encoded["slack_icon"] as? [String: Any])?["name"] as? String == "calendar")
        let actions = try #require(encoded["actions"] as? [[String: Any]])
        #expect(actions.count == 1)
        #expect(actions[0]["type"] as? String == "button")
        #expect(try decoder.decode(Block.self, from: encoder.encode(block)) == block)
    }

    @Test("Slack's documented card example decodes with typed fields")
    func slackExampleDecodes() throws {
        let json = """
        {
          "type": "card",
          "title": { "type": "mrkdwn", "text": "Project kickoff" },
          "subtitle": { "type": "plain_text", "text": "Starts Monday" },
          "body": { "type": "mrkdwn", "text": "All hands on deck" },
          "icon": { "type": "image", "image_url": "https://example.com/i.png", "alt_text": "icon" },
          "actions": [
            { "type": "button", "text": { "type": "plain_text", "text": "Open" }, "action_id": "a" }
          ]
        }
        """
        let block = try decoder.decode(Block.self, from: Data(json.utf8))
        let card = try #require(block.card)
        #expect(card.title?.text == "Project kickoff")
        #expect(card.icon?.alt_text == "icon")
        guard case .button = card.actions?.first else {
            Issue.record("expected button in card actions"); return
        }
        #expect(try decoder.decode(Block.self, from: encoder.encode(block)) == block)
    }

    /// The exact block Slack echoed back from a real chat.postMessage on
    /// 2026-08-06 (ok: true) — the empirical resolution of the doc-vs-example
    /// mismatch on card text fields and `actions`.
    @Test("the card block Slack actually returned round-trips")
    func slackProductionEchoRoundTrips() throws {
        let json = """
        {"body":{"text":"Chemistry with your leader","type":"mrkdwn","verbatim":false},"type":"card","title":{"text":"*Upcoming tute*","type":"mrkdwn","verbatim":false},"actions":[{"text":{"text":"Book Out","type":"plain_text","emoji":true},"type":"button","style":"danger","value":"tute_42","action_id":"book_out"}],"subtext":{"text":"Room 2","type":"mrkdwn","verbatim":false},"block_id":"znazO","subtitle":{"text":"Thursday 4pm","type":"plain_text","emoji":true},"slack_icon":{"name":"calendar","type":"icon"}}
        """
        let block = try decoder.decode(Block.self, from: Data(json.utf8))
        let card = try #require(block.card)
        #expect(card.title?.text == "*Upcoming tute*")
        #expect(card.slack_icon?.name == "calendar")
        #expect(block.block_id == "znazO")
        guard case let .button(button)? = card.actions?.first else {
            Issue.record("expected button"); return
        }
        #expect(button.style == .danger)
        #expect(try decoder.decode(Block.self, from: encoder.encode(block)) == block)
    }
}

@Suite("Carousel and container")
struct NestingBlockTests {

    @Test("a carousel's cards ride the elements wire key")
    func carouselRoundTrips() throws {
        let block = Block.carousel([
            .init(title: "Tute A", body: "Thursday", actions: [.button(.init(text: .init(plain: "Book Out"), action_id: "a"))]),
            .init(title: "Tute B", body: "Friday"),
        ])
        let encoded = try encodeToObject(block)
        #expect(encoded["type"] as? String == "carousel")
        #expect(encoded["cards"] == nil)
        let elements = try #require(encoded["elements"] as? [[String: Any]])
        #expect(elements.count == 2)
        #expect((elements[0]["title"] as? [String: Any])?["text"] as? String == "Tute A")
        #expect(try decoder.decode(Block.self, from: encoder.encode(block)) == block)
    }

    @Test("a carousel decodes from wire JSON with card elements")
    func carouselDecodes() throws {
        let json = """
        { "type": "carousel", "block_id": "car1",
          "elements": [ { "type": "card", "title": { "type": "mrkdwn", "text": "Hi" } } ] }
        """
        let block = try decoder.decode(Block.self, from: Data(json.utf8))
        #expect(block.cards?.count == 1)
        #expect(block.cards?.first?.title?.text == "Hi")
        #expect(try decoder.decode(Block.self, from: encoder.encode(block)) == block)
    }

    @Test("a container nests child blocks under child_blocks with its header fields")
    func containerRoundTrips() throws {
        let block = Block.container(.init(
            title: "This week",
            subtitle: "LEAP",
            blocks: [
                .header("Thursday"),
                .section("Chemistry tute at 4pm"),
                .actions([.button(.init(text: .init(plain: "Book Out"), action_id: "b"))]),
            ],
            width: .wide,
            isCollapsible: true,
            defaultCollapsed: false
        ))
        let encoded = try encodeToObject(block)
        #expect(encoded["type"] as? String == "container")
        #expect(encoded["title"] as? String == "This week")
        #expect(encoded["width"] as? String == "wide")
        let children = try #require(encoded["child_blocks"] as? [[String: Any]])
        #expect(children.count == 3)
        #expect(children[2]["type"] as? String == "actions")
        #expect(try decoder.decode(Block.self, from: encoder.encode(block)) == block)
    }

    @Test("a container with a rich_text_title round-trips")
    func containerRichTitle() throws {
        let json = """
        { "type": "container",
          "rich_text_title": { "type": "rich_text",
            "elements": [ { "type": "rich_text_section",
                            "elements": [ { "type": "text", "text": "Week 3" } ] } ] },
          "child_blocks": [ { "type": "divider" } ] }
        """
        let block = try decoder.decode(Block.self, from: Data(json.utf8))
        #expect(block.container?.rich_text_title?.count == 1)
        #expect(block.container?.child_blocks.count == 1)
        // The envelope comes back on the wire.
        let encoded = try encodeToObject(block)
        #expect(((encoded["rich_text_title"] as? [String: Any])?["type"]) as? String == "rich_text")
        #expect(try decoder.decode(Block.self, from: encoder.encode(block)) == block)
    }
}

@Suite("Plan, task card and context actions")
struct PlanBlockTests {

    @Test("a task_card round-trips id, status, rich text and sources")
    func taskCardRoundTrips() throws {
        let json = """
        {
          "type": "task_card",
          "task_id": "t-42",
          "title": "Mark the Chemistry essays",
          "status": "in_progress",
          "details": { "type": "rich_text",
            "elements": [ { "type": "rich_text_section",
                            "elements": [ { "type": "text", "text": "12 remaining" } ] } ] },
          "sources": [ { "type": "url", "url": "https://example.com/essays", "text": "Essay queue" } ]
        }
        """
        let block = try decoder.decode(Block.self, from: Data(json.utf8))
        let card = try #require(block.taskCard)
        #expect(card.task_id == "t-42")
        #expect(card.status == .inProgress)
        #expect(card.details?.count == 1)
        #expect(card.sources?.first?.text == "Essay queue")

        let encoded = try encodeToObject(block)
        #expect(((encoded["details"] as? [String: Any])?["type"]) as? String == "rich_text")
        #expect(((encoded["sources"] as? [[String: Any]])?.first?["type"]) as? String == "url")
        #expect(try decoder.decode(Block.self, from: encoder.encode(block)) == block)
    }

    @Test("a plan block nests task_card blocks with a bare-string title")
    func planRoundTrips() throws {
        let block = Block.plan(title: "Marking sweep", tasks: [
            .taskCard(.init(taskID: "t-1", title: "Chemistry", status: .complete)),
            .taskCard(.init(taskID: "t-2", title: "Physics", status: .pending)),
        ])
        let encoded = try encodeToObject(block)
        #expect(encoded["type"] as? String == "plan")
        #expect(encoded["title"] as? String == "Marking sweep")
        let tasks = try #require(encoded["tasks"] as? [[String: Any]])
        #expect(tasks.count == 2)
        #expect(tasks[0]["type"] as? String == "task_card")
        #expect(try decoder.decode(Block.self, from: encoder.encode(block)) == block)
    }

    @Test("context_actions carries feedback and icon buttons on the elements key")
    func contextActionsRoundTrips() throws {
        let block = Block.contextActions([
            .feedbackButtons(.init(
                positive: .init("Helpful", value: "yes"),
                negative: .init("Not helpful", value: "no"),
                action_id: "fb"
            )),
            .iconButton(.init(text: "Delete", action_id: "del", value: "msg_1")),
        ])
        let encoded = try encodeToObject(block)
        #expect(encoded["type"] as? String == "context_actions")
        let elements = try #require(encoded["elements"] as? [[String: Any]])
        #expect(elements[0]["type"] as? String == "feedback_buttons")
        #expect((elements[0]["positive_button"] as? [String: Any])?["value"] as? String == "yes")
        #expect(elements[1]["type"] as? String == "icon_button")
        #expect(elements[1]["icon"] as? String == "trash")
        #expect(try decoder.decode(Block.self, from: encoder.encode(block)) == block)
    }
}

@Suite("plainText coverage")
struct PlainTextCoverageTests {

    @Test("every block type with readable content yields non-empty plainText")
    func allReadableBlocksRender() throws {
        let axis = Block.Chart.AxisConfig(categories: ["Mon"])
        let blocks: [(String, Block)] = [
            ("header", .header("Results")),
            ("section", .section("Chemistry tute at 4pm")),
            ("context", .context(["Posted by StaffBOT"])),
            ("actions", .actions([.button(.init(text: .init(plain: "Book Out")))])),
            ("input", .input(label: "Email", element: .emailTextInput(.init()), hint: "School address")),
            ("image", .image(url: "https://x.com/i.png", altText: "A chart")),
            ("video", .video(.init(title: "Recording", videoURL: "https://x.com/v", thumbnailURL: "https://x.com/t.png", altText: "vid", description: "Week 3"))),
            ("markdown", .markdown("**Info**")),
            ("alert", .alert("Heads up", level: .info)),
            ("data_visualization", .dataVisualization(title: "Marks", chart: .pie(segments: [.init("A", value: 1)]))),
            ("table", .table(rows: [[.rawText("Course")], [.rawNumber(value: 1, text: "1")]])),
            ("data_table", .dataTable(caption: "Marks by course", rows: [[.rawText("Course")]])),
            ("card", .card(.init(title: "Upcoming tute", body: "Thursday"))),
            ("carousel", .carousel([.init(title: "Tute A")])),
            ("container", .container(.init(title: "This week", blocks: [.section("Chem")]))),
            ("plan", .plan(title: "Marking sweep", tasks: [.taskCard(.init(taskID: "t", title: "Chemistry"))])),
            ("task_card", .taskCard(.init(taskID: "t", title: "Chemistry"))),
        ]
        for (name, block) in blocks {
            #expect(!block.plainText.isEmpty, "plainText empty for \(name)")
        }
    }

    @Test("nested content reaches the flat text")
    func nestedContentRenders() throws {
        let container = Block.container(.init(title: "Week", blocks: [.section("Chemistry at 4pm")]))
        #expect(container.plainText.contains("Chemistry at 4pm"))

        let plan = Block.plan(title: "Sweep", tasks: [.taskCard(.init(taskID: "t", title: "Mark Physics"))])
        #expect(plan.plainText.contains("Mark Physics"))

        let table = Block.table(rows: [[.richText([.section([.text("cell words", style: nil)])])]])
        #expect(table.plainText.contains("cell words"))
    }
}
