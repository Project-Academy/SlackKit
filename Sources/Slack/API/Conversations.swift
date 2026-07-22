//
//  Conversations.swift
//  SlackKit
//
//  Created by Sarfraz Basha on 27/11/2025.
//

import Foundation

/**
 Wire mirror of Slack's `conversations.*` methods.

 Package-scoped: apps never call the wire layer directly — the facades in
 Client/ and the SlackOrg module are the public surface.
 */
package enum Conversations: String, Endpoints {
    package typealias API = Slack
    package static let base = API.baseURL

    case list
    case replies
    case history
    case info
    case open

    case join
    case invite
    case kick

    package var path: URL { Self.base.appending(component: "conversations.\(rawValue)") }
}
