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
package enum Chat: String, Endpoints {
    package typealias API = Slack
    package static let base = API.baseURL

    case postMessage
    case update
    case delete

    package var path: URL { Self.base.appending(component: "chat.\(rawValue)") }
}

package struct ChatResponse: Decodable {

    package let ok: Bool
    package let channel: String
    package let ts: String

    package let text: String?
    package let message: Message?
}
