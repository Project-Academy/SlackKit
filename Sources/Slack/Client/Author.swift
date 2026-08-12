//
//  Author.swift
//  SlackKit
//
//  Created by Sarfraz Basha on 27/11/2025.
//

import Foundation

/**
 Who a message is posted as.

 The token decides the principal: a user token (`xoxp`) posts as that person, a
 bot token (`xoxb`) posts as the app. The persona fields customise how a *bot*
 post is presented and are ignored by Slack on a user token.

 Previously this was a protocol with two structurally identical conformers
 (`Bot` and `UserAuthor`) whose only difference was which initialiser you
 reached for. It's one type now, with the two intents expressed as factories, so
 `Author` can be compared, stored, and defaulted without an existential.
 */
public struct Author: Sendable, Equatable {

    //--------------------------------------
    // MARK: - VARIABLES -
    //--------------------------------------

    /// The credential. Decides the principal; everything else is presentation.
    public var token: String?

    /**
     Display name for a bot post.

     > Warning: Ignored by Slack when `token` is a user token.
     */
    public var username: String?

    /**
     Emoji to use as the icon for this message, colon-surrounded
     (`":nerd_face:"`). Overrides ``iconURL``.

     > Warning: Ignored by Slack when `token` is a user token.
     */
    public var iconEmoji: String?

    /**
     URL of an image to use as the icon for this message.

     > Warning: Ignored by Slack when `token` is a user token, and when
     ``iconEmoji`` is also set.
     */
    public var iconURL: String?

    //--------------------------------------
    // MARK: - INITIALISERS -
    //--------------------------------------

    public init(token: String?, username: String? = nil, iconEmoji: String? = nil, iconURL: String? = nil) {
        self.token = token
        self.username = username
        self.iconEmoji = iconEmoji
        self.iconURL = iconURL
    }

    /// Posts as the app, optionally overriding how the post is presented.
    public static func bot(token: String, username: String? = nil, iconEmoji: String? = nil, iconURL: String? = nil) -> Author {
        Author(token: token, username: username, iconEmoji: iconEmoji, iconURL: iconURL)
    }

    /**
     The token's kind, read from its prefix.

     A cheap local answer to "will this post as a person or as an app", for
     deciding *before* spending a round trip on ``Slack/Slack/whoAmI(as:)``.
     Slack's answer is the authoritative one; this is the label on the tin.
     */
    public var kind: Kind {
        switch token?.prefix(5) {
        case "xoxp-": .user
        case "xoxb-": .bot
        default:      .unknown
        }
    }

    public enum Kind: Sendable, Equatable { case user, bot, unknown }

    /// Posts as the person the token belongs to. Persona fields are omitted
    /// because Slack ignores them on a user token.
    public static func user(token: String) -> Author {
        Author(token: token)
    }

    //--------------------------------------
    // MARK: - HELPERS -
    //--------------------------------------

    /// The presentation overrides, normalised for the wire. `nil` when this
    /// author doesn't override anything.
    package var persona: Persona? {
        guard username != nil || iconEmoji != nil || iconURL != nil else { return nil }
        return Persona(
            username: username,
            icon_emoji: iconEmoji.map(Self.colonWrapped),
            // Slack honours `icon_emoji` over `icon_url`; sending both is
            // ambiguous, so the emoji wins here too rather than at Slack.
            icon_url: iconEmoji == nil ? iconURL : nil
        )
    }

    private static func colonWrapped(_ emoji: String) -> String {
        guard emoji.first == ":", emoji.last == ":", emoji.count > 1 else { return ":\(emoji):" }
        return emoji
    }

    /// The persona fields as Slack names them on the wire.
    package struct Persona: Encodable, Sendable, Equatable {
        package let username: String?
        package let icon_emoji: String?
        package let icon_url: String?
    }
}

//--------------------------------------
// MARK: - DESCRIPTION -
//--------------------------------------

/**
 A credential that doesn't print itself.

 Without this, `"\(author)"`, `print`, `dump`, `os_log` and SwiftUI's preview
 inspector all emit the token in full — and unified-logging entries persist on
 disk long after the process is gone. The synthesised description was a leak
 waiting for someone to log a request they were debugging.
 */
extension Author: CustomStringConvertible, CustomDebugStringConvertible {

    public var description: String {
        guard let token, !token.isEmpty else { return "Author(unauthenticated)" }

        let kindLabel = switch kind {
        case .user: "user"
        case .bot: "bot"
        case .unknown: "token"
        }
        let persona = username.map { " as \($0)" } ?? ""
        return "Author(\(kindLabel) \(Self.redact(token))\(persona))"
    }

    public var debugDescription: String { description }

    /// Keeps the prefix — which says what kind of credential it is, and is not
    /// a secret — and discards the rest.
    fileprivate static func redact(_ token: String) -> String {
        let prefix = token.prefix(5)
        return prefix.hasSuffix("-") ? "\(prefix)…" : "…"
    }
}

/**
 `dump` reads a value's *stored properties* and ignores
 `CustomStringConvertible` entirely, so redacting `description` alone left the
 token in plain sight of `dump`, the Xcode variables view, and SwiftUI's
 preview inspector. Reflection has to be overridden separately.
 */
extension Author: CustomReflectable {

    public var customMirror: Mirror {
        Mirror(
            self,
            children: [
                "token": token.map(Author.redact) ?? "nil",
                "kind": kind,
                "username": username as Any,
                "iconEmoji": iconEmoji as Any,
                "iconURL": iconURL as Any,
            ],
            displayStyle: .struct
        )
    }
}
