//
//  Field.swift
//  SlackKit
//
//  Created by Sarfraz Basha on 1/12/2025.
//

import Foundation

/**
 A custom profile field on a workspace member.

 `label` is optional because Slack only sends it when the request asked for
 `include_labels=true`. `users.info` and `users.list` don't, so a non-optional
 label failed to decode any member holding a custom field — and, because the
 failure surfaced as a generic error, took the whole member (or the whole list)
 with it.
 */
public struct Field: Codable, Equatable, Sendable {

    public let label: String?
    public let value: String?
    public let alt: String?
}
