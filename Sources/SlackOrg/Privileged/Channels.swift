//
//  Channels.swift
//  SlackKit — SlackOrg
//
//  Created by Sarfraz Basha on 27/11/2025.
//
//  Workspace-structure enumeration and conversation history. Bulk-read
//  capability: becomes server-internal, then gets deleted here.
//

import Foundation
import Slack

extension Channel {

    @available(*, deprecated, message: "Org-principal capability — moving server-side; do not add call sites.")
    public static func list() async throws -> [Channel] {

        let resp = try await Conversations.list.GET
            .params([
                "exclude_archived": true,
                "types": "public_channel, private_channel, mpim, im"
            ])
            .response()

        guard let response = try? resp.asType(Response.self),
              let channels = response.channels
        else { throw SlackError.Conversations(resp.json?.description)  }
        return channels

        struct Response: Decodable {
            let ok: Bool
            let channels: [Channel]?
        }
    }



    @available(*, deprecated, message: "Org-principal capability — moving server-side; do not add call sites.")
    public func history() async throws -> [MessageResponse] {

        let resp = try await Conversations.history.GET
            .params(["channel": id, "include_all_metadata": true])
            .response()

        guard let response = try? resp.asType(Response.self),
              let messages = response.messages
        else { throw SlackError.Conversations(resp.json?.description)  }
        return messages.compactMap { MessageResponse($0, channel: self) }

        struct Response: Decodable {
            let ok: Bool
            let messages: [Message]?
            let is_limited: Bool?
            let pin_count: Int?
            let has_more: Bool?
        }
    }

    @available(*, deprecated, message: "Org-principal capability — moving server-side; do not add call sites.")
    public func getReplies(to ts: String) async throws -> [MessageResponse] {

        let resp = try await Conversations.replies.GET
            .params([
                "channel": id,
                "ts": ts
            ])
            .response()

        guard let response = try? resp.asType(Response.self),
              let messages = response.messages
        else { throw SlackError.Conversations(resp.json?.description)  }
        return messages.compactMap { MessageResponse($0, channel: self) }
        struct Response: Decodable {
            let ok: Bool
            let messages: [Message]?
            let is_limited: Bool?
            let pin_count: Int?
            let has_more: Bool?
        }
    }

    @available(*, deprecated, message: "Org-principal capability — moving server-side; do not add call sites.")
    public func info() async throws -> Channel {

        let resp = try await Conversations.info.GET
            .params([
                "channel": id,
                "include_num_members": true,
                "include_locale": true,
            ])
            .response()

        guard let response = try? resp.asType(Response.self),
              let channel = response.channel
        else { throw SlackError.Conversations(resp.json?.description)  }
        return channel
    }

    struct Response: Decodable {
        let ok: Bool
        let channel: Channel?
        let warning: String?
    }
}
