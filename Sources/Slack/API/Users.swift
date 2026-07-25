//
//  Users.swift
//  SlackKit
//
//  Created by Sarfraz Basha on 1/12/2025.
//

import Foundation

/**
 Wire mirror of Slack's `users.*` methods.

 Package-scoped: apps never call the wire layer directly — the facades in
 Client/ and the SlackOrg module are the public surface.
 */
package enum Users: String, SlackEndpoint {
    package typealias API = Slack
    case list
    case info
    case profileGet = "profile.get"

    package var method: String { "users.\(rawValue)" }
}
