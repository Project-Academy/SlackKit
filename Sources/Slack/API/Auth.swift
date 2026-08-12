//
//  Auth.swift
//  SlackKit
//
//  The `auth.*` methods — what a credential is, rather than what it can do.
//

import Foundation

/**
 Wire mirror of Slack's `auth.*` methods.

 Package-scoped: apps never call the wire layer directly — they go through
 ``Slack/Slack/whoAmI(as:)``.
 */
package enum Auth: String, SlackEndpoint {
    package typealias API = Slack
    case test

    package var method: String { "auth.\(rawValue)" }
}
