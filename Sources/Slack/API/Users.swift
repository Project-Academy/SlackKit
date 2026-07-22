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
package enum Users: String, Endpoints {
    package typealias API = Slack
    package static let base = API.baseURL

    case list
    case info
    case profileGet = "profile.get"

    package var path: URL { Self.base.appending(component: "users.\(rawValue)") }
}
