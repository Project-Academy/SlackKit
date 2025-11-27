//
//  Error.swift
//  SlackKit
//
//  Created by Sarfraz Basha on 27/11/2025.
//

//public protocol SlackError: Error {}

public enum SlackError: Error {
    case Chat(_ error: Any?)
}
