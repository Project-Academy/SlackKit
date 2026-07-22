//
//  Error.swift
//  SlackKit
//
//  Created by Sarfraz Basha on 27/11/2025.
//

//public protocol SlackError: Error {}

public enum SlackError: Error, Sendable {
    case Chat(_ error: String?)
    case Conversations(_ error: String?)
    case Reactions(_ error: String?)
    case Users(_ error: String?)
}
