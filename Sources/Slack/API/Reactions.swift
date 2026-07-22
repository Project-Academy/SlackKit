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
package enum Reactions: String, Endpoints {
    package typealias API = Slack
    package static let base = API.baseURL

    case add
    case get
    case list
    case remove

    package var path: URL { Self.base.appending(component: "reactions.\(rawValue)") }
}
