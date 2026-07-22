//
//  Request.swift
//  SlackKit
//
//  Slack's request type is just `DefaultRequest<Slack>` from Tapioca,
//  exposed under the familiar `Slack.Request` / `Request` spelling so
//  no consumer of SlackKit has to change a callsite. The Slack-specific
//  chainable modifiers (`.message(...)`, `.from(...)`, `.to(...)`,
//  `.messageAt(...)`) live below as a constrained extension.
//
//  The modifiers are `package`-scoped: they are wire plumbing, usable by this
//  package's facades (Client/ and the SlackOrg module) but not by apps.
//

import Foundation
import Tapioca

public typealias Request = DefaultRequest<Slack>

extension DefaultRequest where API == Slack {

    //--------------------------------------
    // MARK: - MODIFIERS -
    //--------------------------------------
    package func message(_ msg: Message) -> Self {
        let request = self
            .params(msg.json)
        return request
    }

    package func from(_ author: Author?) -> Self {
        guard let author else { return self }

        var request = self
        if let name = author.username {
            request.params["username"] = name
        }
        if var emoji = author.icon_emoji {
            // Check for colons, else prepend and append to the string.
            if emoji.first == ":", emoji.last == ":" {}
            else { emoji = ":\(emoji):" }
            request.params["icon_emoji"] = emoji
        } else if let url = author.icon_url {
            request.params["icon_url"] = url
        }
        if let token = author.token {
            request = request.setHeader(key: "Authorization", value: "Bearer \(token)")
        }
        return request
    }

    package func to(_ channel: String) -> Self {
        var request = self
        request.params["channel"] = channel
        return request
    }

    package func messageAt(_ ts: String, in channel: String) -> Self {
        let request = self
            .params(["ts": ts, "channel": channel])
        return request
    }
}
