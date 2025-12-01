//
//  Emoji.swift
//  SlackKit
//
//  Created by Sarfraz Basha on 1/12/2025.
//

import Foundation

private enum Emoji: String, Endpoints {
    typealias API = Slack
    static let base = API.baseURL
    
    case list
    
    var path: URL { Self.base.appending(component: "emoji.\(rawValue)") }
}

