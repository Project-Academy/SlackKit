//
//  Error.swift
//  SlackKit
//
//  Created by Sarfraz Basha on 27/11/2025.
//

//public protocol SlackError: Error {}

public enum SlackError: Error {
    case Chat(_ error: Any?)
    case Conversations(_ error: Any?)
    case Reactions(_ error: Any?)
    case Users(_ error: Any?)
}
