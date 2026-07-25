//
//  Chat.swift
//  SlackKit
//
//  Created by Sarfraz Basha on 26/11/2025.
//

import Foundation

/**
 Wire mirror of Slack's `chat.*` methods.

 Package-scoped: apps never call the wire layer directly — they go through the
 public facades (`Message.send` in Client/, or the SlackOrg module's messaging
 surface). Only code inside this package can build requests against it.
 */
package enum Chat: String, SlackEndpoint {
    package typealias API = Slack
    case postMessage
    case update
    case delete

    package var method: String { "chat.\(rawValue)" }
}

/**
 What `chat.postMessage` / `chat.update` / `chat.delete` answer with.

 `channel` and `ts` are the receipt — the pair Slack needs to address this
 message again. `message` is absent on `chat.delete`, which is why it's optional
 here rather than being treated as proof the call worked; `ok` is what proves
 that, and it's checked before this type is ever decoded.
 */
package struct ChatResponse: Decodable, Sendable {

    package let ok: Bool
    package let channel: String
    package let ts: String

    package let text: String?
    package let message: ReceivedMessage?
}
