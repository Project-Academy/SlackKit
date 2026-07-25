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
