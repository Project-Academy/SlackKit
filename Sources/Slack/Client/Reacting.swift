//
//  Reactions.swift
//  SlackKit
//
//  Created by Sarfraz Basha on 1/12/2025.
//

import Foundation

extension MessageResponse {

    /**
     URLError codes that indicate a transient connection issue rather
     than a genuine "no internet" or server failure. `-1005` (network
     connection lost) is misleadingly named — it almost always means a
     specific keep-alive socket was reset by the peer and a retry on a
     fresh connection succeeds. The others are similar URLSession
     edges worth one shot.
     */
    private static let retryableURLErrorCodes: Set<URLError.Code> = [
        .networkConnectionLost,   // -1005
        .timedOut,                // -1001
        .cannotConnectToHost,     // -1004
        .cannotFindHost,          // -1003
        .dnsLookupFailed,         // -1006
    ]

    /**
     Wraps an idempotent Slack call (reactions.add / .remove — Slack
     reports "already_reacted"/"no_reaction" for repeats, so a retry
     is safe even if the server processed the original request before
     the connection dropped) with up to `maxAttempts` total tries on
     transient URLErrors. A short fixed backoff lets URLSession pick
     up a fresh connection rather than reusing the broken one.
     */
    private static func withTransientRetry<T>(
        maxAttempts: Int = 3,
        _ block: () async throws -> T
    ) async throws -> T {
        var attempt = 1
        while true {
            do {
                return try await block()
            } catch let error as URLError where retryableURLErrorCodes.contains(error.code) {
                guard attempt < maxAttempts else {
                    print("⚠️ Slack transient retry exhausted (\(error.code.rawValue)) after \(attempt) attempts")
                    throw error
                }
                print("⏳ Slack transient \(error.code.rawValue) — retrying (\(attempt + 1)/\(maxAttempts))")
                try? await Task.sleep(for: .seconds(1))
                attempt += 1
            }
        }
    }

    public func addReaction(_ reaction: String) async throws {

        try await MessageResponse.withTransientRetry {
            let resp = try await Reactions.add.POST
                .params([
                    "channel": channel.id,
                    "name": reaction,
                    "timestamp": ts
                ])
                .response()

            guard let response = try? resp.asType(Response.self)
            else { throw SlackError.Reactions(resp.json?.description) }

            guard let error = response.error,
                  error != "already_reacted"
            else { return }
            throw SlackError.Reactions(resp.json?.description)

            struct Response: Decodable {
                let ok: Bool
                let error: String?
            }
        }
    }

    public func removeReaction(_ reaction: String) async throws {

        try await MessageResponse.withTransientRetry {
            let resp = try await Reactions.remove.POST
                .params([
                    "channel": channel.id,
                    "name": reaction,
                    "timestamp": ts
                ])
                .response()

            guard let response = try? resp.asType(Response.self)
            else { throw SlackError.Reactions(resp.json?.description) }

            guard let error = response.error,
                  error != "no_reaction"
            else { return }
            throw SlackError.Reactions(resp.json?.description)

            struct Response: Decodable {
                let ok: Bool
                let error: String?
            }
        }
    }

    public func getReactions() async throws -> [Message.Reaction] {

        let resp = try await Reactions.get.GET
            .params([
                "channel": channel.id,
                "full": true, // If true always return the complete reaction list.
                "timestamp": ts
            ])
            .response()

        guard let response = try? resp.asType(Response.self),
              let reactions = response.message?.reactions
        else { throw SlackError.Reactions(resp.json?.description) }
        return reactions

        struct Response: Decodable {
            let ok: Bool
            let error: String?
            let type: String?
            let message: Message?
            let channel: String?
        }

    }
}
