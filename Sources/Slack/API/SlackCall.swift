//
//  SlackCall.swift
//  SlackKit
//
//  The single choke point every Slack call goes through.
//
//  Slack answers *failures* with HTTP 200 and `{"ok": false, "error": …}`, so
//  the status code proves nothing and `ok` is the only reliable verdict. Before
//  this existed, each call site decoded its own response type and inferred
//  failure from whether the decode happened to fail — which meant correctness
//  rode on which fields a given `Decodable` declared non-optional, and `ok` was
//  decoded in a dozen places and read in none.
//
//  Now there is one path: `perform` checks `ok`, classifies the failure, and
//  only then decodes the payload. A call site cannot forget, because there is
//  no other way to fire a request.
//

import Foundation
import Tapioca

//--------------------------------------
// MARK: - ENVELOPE -
//--------------------------------------

/**
 The fields Slack puts on *every* response, regardless of method.

 `ok` is non-optional on purpose: a body without it isn't a Slack API response
 at all (a proxy error page, an HTML interstitial), and that is a materially
 different failure from Slack saying no.
 */
package struct SlackEnvelope: Decodable, Sendable {

    package let ok: Bool
    package let error: String?
    package let warning: String?
    package let response_metadata: Metadata?

    package struct Metadata: Decodable, Sendable {
        package let next_cursor: String?
        package let warnings: [String]?
        package let messages: [String]?
    }

    /// Slack's cursor for the next page, normalised — Slack signals "no more
    /// pages" with an *empty string*, not by omitting the field.
    package var nextCursor: String? {
        guard let cursor = response_metadata?.next_cursor, !cursor.isEmpty else { return nil }
        return cursor
    }
}

/**
 A paged Slack response. Conformers declare where their items live and inherit
 cursor-following for free.
 */
package protocol SlackPage: Decodable, Sendable {
    associatedtype Item
    var items: [Item]? { get }
    var response_metadata: SlackEnvelope.Metadata? { get }
}

extension SlackPage {
    package var nextCursor: String? {
        guard let cursor = response_metadata?.next_cursor, !cursor.isEmpty else { return nil }
        return cursor
    }
}

//--------------------------------------
// MARK: - RETRY POLICY -
//--------------------------------------

/**
 What a call is allowed to re-issue after a failure.

 The distinction that matters is whether Slack *processed* the request. A 429
 or a 5xx means it did not, so re-issuing is safe even for a write. A dropped
 connection mid-flight means we don't know — safe only when the operation is
 idempotent (Slack reports `already_reacted` rather than double-reacting).
 */
package struct RetryPolicy: Sendable {

    package let maxAttempts: Int
    package let retriesTransientConnections: Bool

    /// Retries only what Slack certainly never processed. Safe for writes.
    package static let rateLimitOnly = RetryPolicy(maxAttempts: 3, retriesTransientConnections: false)

    /// Also retries dropped connections. Only for calls that are idempotent
    /// server-side.
    package static let idempotent = RetryPolicy(maxAttempts: 3, retriesTransientConnections: true)

    /// One shot.
    package static let none = RetryPolicy(maxAttempts: 1, retriesTransientConnections: false)

    /**
     URLError codes that indicate a transient connection issue rather than a
     genuine "no internet" or server failure. `-1005` (network connection lost)
     is misleadingly named — it almost always means a specific keep-alive socket
     was reset by the peer and a retry on a fresh connection succeeds.
     */
    private static let retryableURLErrorCodes: Set<URLError.Code> = [
        .networkConnectionLost,   // -1005
        .timedOut,                // -1001
        .cannotConnectToHost,     // -1004
        .cannotFindHost,          // -1003
        .dnsLookupFailed,         // -1006
    ]

    /// How long to wait before attempt `attempt + 1`, or `nil` to give up.
    package func delay(after error: any Error, attempt: Int) -> Duration? {
        guard attempt < maxAttempts else { return nil }

        if let slack = error as? SlackError {
            switch slack {
            case let .transport(_, _, retryAfter):
                // Slack's own Retry-After is authoritative when it sends one.
                return .seconds(min(retryAfter ?? backoff(attempt), 30))
            case .refused(_, .rateLimited):
                return .seconds(backoff(attempt))
            default:
                return nil
            }
        }

        if retriesTransientConnections,
           let url = error as? URLError,
           Self.retryableURLErrorCodes.contains(url.code) {
            return .seconds(backoff(attempt))
        }

        return nil
    }

    private func backoff(_ attempt: Int) -> Double { Double(attempt) }
}

//--------------------------------------
// MARK: - ENDPOINT -
//--------------------------------------

/**
 A Slack API endpoint.

 `method` is the fully-qualified Slack method name (`"chat.postMessage"`) and is
 the single source of both the request URL and the diagnostics attached to any
 error, so the two can't drift.
 */
package protocol SlackEndpoint: Endpoints, Sendable where API == Slack {
    var method: String { get }
}

extension SlackEndpoint {
    package static var base: URL { Slack.baseURL }
    package var path: URL { Slack.baseURL.appending(component: method) }
}

extension SlackEndpoint {

    /**
     Fires this endpoint as a GET and returns the decoded payload — but only
     once Slack has said `ok`.
     */
    package func read<T: Decodable>(
        _ type: T.Type = T.self,
        retry: RetryPolicy = .idempotent,
        _ build: (Request) -> Request = { $0 }
    ) async throws -> T {
        try await perform(type, build(GET), retry: retry)
    }

    /**
     Fires this endpoint as a POST and returns the decoded payload — but only
     once Slack has said `ok`.

     Defaults to ``RetryPolicy/rateLimitOnly`` because a POST is usually a
     write: a 429 is safe to re-issue (Slack never ran it), a dropped connection
     is not (it may have).
     */
    package func write<T: Decodable>(
        _ type: T.Type = T.self,
        retry: RetryPolicy = .rateLimitOnly,
        _ build: (Request) -> Request = { $0 }
    ) async throws -> T {
        try await perform(type, build(POST), retry: retry)
    }

    /**
     Follows `response_metadata.next_cursor` until Slack stops handing one out,
     concatenating every page.

     - Parameter maxItems: A hard ceiling on how many items to accumulate. When
       the ceiling truncates the result, ``Slack/diagnostics`` is told — a
       bounded read must never look like a complete one.
     */
    package func readPages<Page: SlackPage>(
        _ type: Page.Type = Page.self,
        pageSize: Int = 200,
        maxItems: Int? = nil,
        retry: RetryPolicy = .idempotent,
        _ build: (Request) -> Request = { $0 }
    ) async throws -> [Page.Item] {

        var collected: [Page.Item] = []
        var cursor: String?

        while true {
            let page: Page = try await perform(
                Page.self,
                build(GET).params(pageParams(pageSize: pageSize, cursor: cursor)),
                retry: retry
            )

            collected.append(contentsOf: page.items ?? [])

            if let maxItems, collected.count >= maxItems {
                let kept = Array(collected.prefix(maxItems))
                if page.nextCursor != nil || collected.count > maxItems {
                    Slack.report(
                        "\(method): stopped at the \(maxItems)-item ceiling; more pages remain"
                    )
                }
                return kept
            }

            guard let next = page.nextCursor else { return collected }
            cursor = next
        }
    }

    private func pageParams(pageSize: Int, cursor: String?) -> [String: any Sendable] {
        var params: [String: any Sendable] = ["limit": pageSize]
        if let cursor { params["cursor"] = cursor }
        return params
    }

    //--------------------------------------
    // MARK: - THE CHOKE POINT -
    //--------------------------------------

    private func perform<T: Decodable>(
        _ type: T.Type,
        _ request: Request,
        retry: RetryPolicy
    ) async throws -> T {

        var attempt = 1
        while true {
            do {
                let response = try await request.response()
                return try decode(type, from: response)
            } catch {
                guard let delay = retry.delay(after: error, attempt: attempt) else { throw error }
                try? await Task.sleep(for: delay)
                attempt += 1
            }
        }
    }

    /**
     Reads Slack's verdict before reading its payload.

     Order matters. `ok` is checked first, so a refusal is reported as a
     refusal — not as whatever decoding error the payload type happens to throw
     when the fields it wanted are absent.
     */
    package func decode<T: Decodable>(_ type: T.Type = T.self, from response: Response) throws -> T {

        guard let envelope = try? response.asType(SlackEnvelope.self) else {
            throw SlackError.unreadable(
                method: method,
                detail: "body was not a Slack envelope (no `ok` field)"
            )
        }

        guard envelope.ok else {
            throw SlackError.refused(
                method: method,
                code: SlackError.Code(rawValue: envelope.error ?? "unknown")
            )
        }

        // `SlackEnvelope` is a valid `T` when the caller only wanted the
        // verdict, so this covers ok-only endpoints too.
        do {
            return try response.asType(T.self)
        } catch {
            throw SlackError.unreadable(method: method, detail: String(describing: error))
        }
    }
}
