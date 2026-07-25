//
//  Payloads.swift
//  SlackKit
//
//  The exact bodies Slack's `chat.*` methods accept.
//
//  Declaring them as types (rather than assembling dictionaries at each call
//  site) means the wire format is written down once, checked by the compiler,
//  and encoded by the same `Encodable` machinery the models use — so a block
//  can't serialise one way here and another way in a test.
//

import Foundation

/// Body of `chat.postMessage`.
package struct PostMessagePayload: Encodable, Sendable {

    package let channel: String

    package let text: String
    package let blocks: [Block]?
    package let thread_ts: String?
    package let mrkdwn: Bool?
    package let metadata: Message.Metadata?

    // Presentation overrides. Slack ignores these on a user token.
    package let username: String?
    package let icon_emoji: String?
    package let icon_url: String?

    package init(_ message: Message, to channel: String, as persona: Author.Persona?) {
        self.channel    = channel
        self.text       = message.text
        self.blocks     = message.blocks
        self.thread_ts  = message.thread_ts
        self.mrkdwn     = message.mrkdwn
        self.metadata   = message.metadata
        self.username   = persona?.username
        self.icon_emoji = persona?.icon_emoji
        self.icon_url   = persona?.icon_url
    }
}

/// Body of `chat.update`.
package struct UpdateMessagePayload: Encodable, Sendable {

    package let channel: String
    package let ts: String

    package let text: String
    package let blocks: [Block]?
    package let metadata: Message.Metadata?

    package init(_ message: Message, at ts: String, in channel: String) {
        self.channel  = channel
        self.ts       = ts
        self.text     = message.text
        self.blocks   = message.blocks
        self.metadata = message.metadata
    }
}

/// Body of `chat.delete`.
package struct DeleteMessagePayload: Encodable, Sendable {
    package let channel: String
    package let ts: String

    package init(at ts: String, in channel: String) {
        self.channel = channel
        self.ts = ts
    }
}

/// Body of `conversations.open`.
package struct OpenConversationPayload: Encodable, Sendable {
    package let users: String
    package let return_im: Bool
    package let prevent_creation: Bool

    package init(users: String, return_im: Bool, prevent_creation: Bool) {
        self.users = users
        self.return_im = return_im
        self.prevent_creation = prevent_creation
    }
}

/// Body of `conversations.join` / `.kick`.
package struct ChannelMembershipPayload: Encodable, Sendable {
    package let channel: String
    package let user: String?

    package init(channel: String, user: String? = nil) {
        self.channel = channel
        self.user = user
    }
}

/// Body of `conversations.invite`.
package struct InvitePayload: Encodable, Sendable {
    package let channel: String
    package let users: String
    /// Keep inviting the valid IDs rather than failing the whole batch on one
    /// bad ID.
    package let force: Bool = true

    package init(channel: String, users: String) {
        self.channel = channel
        self.users = users
    }
}

/// Body of `reactions.add` / `.remove`.
package struct ReactionPayload: Encodable, Sendable {
    package let channel: String
    package let name: String
    package let timestamp: String
}
