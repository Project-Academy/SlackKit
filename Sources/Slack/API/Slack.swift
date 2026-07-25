//
//  Slack.swift
//  SlackKit
//
//  Created by Sarfraz Basha on 26/11/2025.
//

import Foundation
@_exported import Tapioca

@MainActor
public struct Slack: Tapioca {

    public typealias R = Request

    /// Slack's API root. Fixed — an API host is not a runtime setting, and a
    /// mutable one is a redirect waiting to happen.
    public static let baseURL: URL = URL(string: "https://slack.com/api")!

    //--------------------------------------
    // MARK: - VARIABLES -
    //--------------------------------------

    /**
     The credential used when a call site doesn't name one.

     Resolved **explicitly at the facade** (`Message.send`, `Channel.join`, …)
     rather than injected invisibly during pre-processing, so "which principal
     posted this?" is answerable by reading the call site. A call that reaches
     the wire with no author is sent unauthenticated and Slack will say
     `not_authed` — it will not quietly borrow whatever credential was set last.
     */
    public static var defaultAuthor: Author?

    /**
     Where the kit reports things worth knowing that aren't failures: Slack's
     `warning` fields, invite partial-failures, a paged read that hit its
     ceiling. Unset by default; point it at Scribe (or any logger) to see them.

     The kit itself never prints.
     */
    public static var diagnostics: (@Sendable (String) -> Void)?

    package static func report(_ message: String) {
        diagnostics?(message)
    }

    //--------------------------------------
    // MARK: - PRE- & POST-PROCESS -
    //--------------------------------------

    public static func preProcess(request: R) async throws -> R {
        request
            .content(type: request.content)
            .accepts(type: request.accepts)
    }

    /**
     Classifies the HTTP layer, and only the HTTP layer.

     A non-200 means the request never reached a Slack verdict, so it becomes a
     ``SlackError/transport(method:status:retryAfter:)`` — retryable by
     definition. Slack's *own* refusals arrive as HTTP 200 with `ok: false` and
     are classified in ``SlackEndpoint/decode(_:from:)``, which is the only
     place that reads a payload.
     */
    public static func postProcess(response: Response, from request: R) async throws -> Response {

        guard let statusCode = response.statusCode
        else { throw PrestoError.noStatusCode }

        guard statusCode != 200 else { return response }

        throw SlackError.transport(
            method: request.urlRequest.url?.lastPathComponent ?? "slack",
            status: statusCode,
            retryAfter: response.retryAfter
        )
    }
}

extension Response {

    /// Slack's `Retry-After`, in seconds, when it asked us to back off.
    package var retryAfter: TimeInterval? {
        guard let raw = http?.value(forHTTPHeaderField: "Retry-After") else { return nil }
        return TimeInterval(raw)
    }
}
