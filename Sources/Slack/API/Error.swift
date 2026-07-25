//
//  Error.swift
//  SlackKit
//
//  Created by Sarfraz Basha on 27/11/2025.
//

import Foundation

/**
 Everything that can go wrong on the way to a Slack verdict.

 The three cases are deliberately distinct, because they call for different
 handling and were previously indistinguishable:

 - ``refused`` — Slack answered and said no. There is a machine-readable
   ``Code``, and the call will fail again the same way until something changes.
 - ``unreadable`` — Slack answered *successfully* but the body wasn't the shape
   this kit expects. The operation probably **happened**; retrying may duplicate
   it. This is a bug in the kit or a Slack schema change, not a caller error.
 - ``transport`` — no Slack verdict at all (HTTP 5xx, 429, a proxy, an outage).
   Nothing was processed, so retrying is safe.

 Conflating these is how a successful post gets reported as a failure and then
 retried into a duplicate.
 */
public enum SlackError: Error, Sendable, Equatable {

    /// Slack answered and refused. `method` is the API method that was called
    /// (`"chat.postMessage"`), `code` is Slack's own error code.
    case refused(method: String, code: Code)

    /// Slack reported success but the payload didn't decode. `detail` carries
    /// the decoding failure for diagnosis — it is not fit for user-facing copy.
    case unreadable(method: String, detail: String)

    /// The request never reached a Slack verdict. `retryAfter` is Slack's
    /// `Retry-After` header when it sent one.
    case transport(method: String, status: Int, retryAfter: TimeInterval?)

    //--------------------------------------
    // MARK: - ACCESSORS -
    //--------------------------------------

    /// The API method that failed, e.g. `"conversations.join"`.
    public var method: String {
        switch self {
        case let .refused(method, _),
             let .unreadable(method, _),
             let .transport(method, _, _):
            return method
        }
    }

    /// Slack's error code, when Slack got far enough to give one.
    public var code: Code? {
        guard case let .refused(_, code) = self else { return nil }
        return code
    }

    /// Whether re-issuing the identical request is safe. Only true when we know
    /// Slack never processed it.
    public var isRetryable: Bool {
        switch self {
        case .transport:              return true
        case let .refused(_, code):   return code == .rateLimited
        case .unreadable:             return false
        }
    }
}

extension SlackError {

    /**
     Slack's machine-readable error codes.

     Modelled as a case-per-code (plus ``other(_:)``) rather than a bare string
     so a caller can branch on one in a way the compiler checks:

     ```swift
     catch SlackError.refused(_, .alreadyInChannel) { … }
     ```

     Slack's full code list is long and grows; ``other(_:)`` carries anything
     not named here without loss, so an unrecognised code is never swallowed.
     */
    public enum Code: Sendable, Equatable, Hashable, RawRepresentable, CustomStringConvertible {

        // MARK: Membership
        case alreadyInChannel
        case notInChannel
        case methodNotSupportedForChannelType
        case channelNotFound
        case isArchived
        case cantInvite
        case cantInviteSelf

        // MARK: Auth
        case notAuthed
        case invalidAuth
        case tokenRevoked
        case accountInactive
        case missingScope
        case noPermission

        // MARK: Messaging
        case messageNotFound
        case cantUpdateMessage
        case cantDeleteMessage
        case msgTooLong
        case noText

        // MARK: Reactions
        case alreadyReacted
        case noReaction
        case tooManyEmoji
        case tooManyReactions

        // MARK: Users
        case userNotFound
        case usersNotFound

        // MARK: Throttling
        case rateLimited

        /// Any code this kit doesn't name. Carries Slack's raw string verbatim.
        case other(String)

        public init(rawValue: String) {
            switch rawValue {
            case "already_in_channel":                     self = .alreadyInChannel
            case "not_in_channel":                         self = .notInChannel
            case "method_not_supported_for_channel_type":  self = .methodNotSupportedForChannelType
            case "channel_not_found":                      self = .channelNotFound
            case "is_archived":                            self = .isArchived
            case "cant_invite":                            self = .cantInvite
            case "cant_invite_self":                       self = .cantInviteSelf

            case "not_authed":                             self = .notAuthed
            case "invalid_auth":                           self = .invalidAuth
            case "token_revoked":                          self = .tokenRevoked
            case "account_inactive":                       self = .accountInactive
            case "missing_scope":                          self = .missingScope
            case "no_permission":                          self = .noPermission

            case "message_not_found":                      self = .messageNotFound
            case "cant_update_message":                    self = .cantUpdateMessage
            case "cant_delete_message":                    self = .cantDeleteMessage
            case "msg_too_long":                           self = .msgTooLong
            case "no_text":                                self = .noText

            case "already_reacted":                        self = .alreadyReacted
            case "no_reaction":                            self = .noReaction
            case "too_many_emoji":                         self = .tooManyEmoji
            case "too_many_reactions":                     self = .tooManyReactions

            case "user_not_found":                         self = .userNotFound
            case "users_not_found":                        self = .usersNotFound

            case "ratelimited", "rate_limited":            self = .rateLimited

            default:                                       self = .other(rawValue)
            }
        }

        public var rawValue: String {
            switch self {
            case .alreadyInChannel:                    return "already_in_channel"
            case .notInChannel:                        return "not_in_channel"
            case .methodNotSupportedForChannelType:    return "method_not_supported_for_channel_type"
            case .channelNotFound:                     return "channel_not_found"
            case .isArchived:                          return "is_archived"
            case .cantInvite:                          return "cant_invite"
            case .cantInviteSelf:                      return "cant_invite_self"

            case .notAuthed:                           return "not_authed"
            case .invalidAuth:                         return "invalid_auth"
            case .tokenRevoked:                        return "token_revoked"
            case .accountInactive:                     return "account_inactive"
            case .missingScope:                        return "missing_scope"
            case .noPermission:                        return "no_permission"

            case .messageNotFound:                     return "message_not_found"
            case .cantUpdateMessage:                   return "cant_update_message"
            case .cantDeleteMessage:                   return "cant_delete_message"
            case .msgTooLong:                          return "msg_too_long"
            case .noText:                              return "no_text"

            case .alreadyReacted:                      return "already_reacted"
            case .noReaction:                          return "no_reaction"
            case .tooManyEmoji:                        return "too_many_emoji"
            case .tooManyReactions:                    return "too_many_reactions"

            case .userNotFound:                        return "user_not_found"
            case .usersNotFound:                       return "users_not_found"

            case .rateLimited:                         return "ratelimited"

            case let .other(raw):                      return raw
            }
        }

        public var description: String { rawValue }

        /// Whether this code means the caller's credential is the problem —
        /// i.e. re-authenticating is the only thing that will help.
        public var isAuthFailure: Bool {
            switch self {
            case .notAuthed, .invalidAuth, .tokenRevoked, .accountInactive,
                 .missingScope, .noPermission:
                return true
            default:
                return false
            }
        }
    }
}

extension SlackError: LocalizedError {

    /**
     A short, human-readable summary.

     Deliberately does **not** include the raw response body. Slack's error
     payloads carry `needed`/`provided` OAuth scope lists, which have no place
     in a surface a student or staff member can see.
     */
    public var errorDescription: String? {
        switch self {
        case let .refused(method, code):
            return "Slack refused \(method): \(code.rawValue)"
        case let .unreadable(method, _):
            return "Slack's response to \(method) couldn't be read"
        case let .transport(method, status, _):
            return "Couldn't reach Slack for \(method) (HTTP \(status))"
        }
    }
}
