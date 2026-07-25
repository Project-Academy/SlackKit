//
//  Reactions.swift
//  SlackKit
//
//  Created by Sarfraz Basha on 1/12/2025.
//

import Foundation

/**
 Wire mirror of Slack's `reactions.*` methods.

 Package-scoped: apps never call the wire layer directly — the facades in
 Client/ are the public surface.
 */
package enum Reactions: String, SlackEndpoint {
    package typealias API = Slack
    case add
    case get
    case list
    case remove

    package var method: String { "reactions.\(rawValue)" }
}
