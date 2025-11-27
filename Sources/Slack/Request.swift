//
//  Request.swift
//  SlackKit
//
//  Created by Sarfraz Basha on 26/11/2025.
//

import Foundation

public struct Request: APIRequest {
    public typealias API = Slack
    
    //--------------------------------------
    // MARK: - VARIABLES -
    //--------------------------------------
    public var urlRequest: URLRequest
    public var httpMethod: HTTPMethod
    public let baseURL: URL
    
    //--------------------------------------
    // MARK: - INTERNAL STATE -
    //--------------------------------------
    public var headers: [String: String] = [:]
    public var accepts: ContentType = .JSON
    public var content: ContentType = .JSON
    
    public var params: [String: (any Sendable)] = [:]
    public var paramTransformer: (@Sendable ([String: Any]) throws -> Data) = { params in
        try JSONSerialization.data(withJSONObject: params, options: .prettyPrinted)
    }
    
    //--------------------------------------
    // MARK: - INITIALISERS -
    //--------------------------------------
    public init(url: URL, _ method: HTTPMethod? = nil) {
        baseURL = url
        urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = (method ?? .GET).rawValue
        httpMethod = method ?? .GET
    }
    
    //--------------------------------------
    // MARK: - MODIFIERS -
    //--------------------------------------
    public func message(_ msg: Message) -> Self {
        var request = self
            .params(msg.json)
        return request
    }
    public func from(_ author: Author?) -> Self {
        guard let author else { return self }
        
        var request = self
        if let name = author.username {
            request.params["username"] = name
        }
        if var emoji = author.icon_emoji {
            // Check for colons, else prepend and append to the string.
            if emoji.first == ":", emoji.last == ":" {}
            else { emoji = ":\(emoji):" }
            request.params["icon_emoji"] = emoji
        } else if let url = author.icon_url {
            request.params["icon_url"] = url
        }
        if let token = author.token {
            request = request.setHeader(key: "Authorization", value: "Bearer \(token)")
        }
        return request
    }
    public func to(_ channel: String) -> Self {
        var request = self
        request.params["channel"] = channel
        return request
    }
    public func messageAt(_ ts: String, in channel: String) -> Self {
        var request = self
            .params(["ts": ts, "channel": channel])
        return request
    }
}
