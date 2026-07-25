//
//  Request.swift
//  SlackKit
//
//  Slack's request type is just `DefaultRequest<Slack>` from Tapioca,
//  exposed under the familiar `Slack.Request` / `Request` spelling so
//  no consumer of SlackKit has to change a callsite. The Slack-specific
//  chainable modifiers live below as a constrained extension.
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

    /**
     Sends `payload` as the JSON body, encoded by `JSONEncoder`.

     This is the only way a POST body is built. Everything Slack receives
     therefore goes through the models' own `Encodable` conformance — there is
     no second, hand-written dictionary path that can drift from it. (There used
     to be: `Block.json` silently omitted `rich_text` and `actions` content that
     `Block.encode(to:)` wrote correctly.)
     */
    package func body(_ payload: some Encodable & Sendable) -> Self {
        var request = self
        let encoder = JSONEncoder()
        request.paramTransformer = { _ in try encoder.encode(payload) }
        return request
    }

    /**
     Authenticates the request as `author`.

     Only the credential goes here. Presentation (`username`, `icon_emoji`) is
     part of the message payload, not the request envelope, and is folded in
     where the payload is built — so a persona can never be attached to a call
     that has no message to present.
     */
    package func from(_ author: Author?) -> Self {
        guard let token = author?.token else { return self }
        return setHeader(key: "Authorization", value: "Bearer \(token)")
    }
}
