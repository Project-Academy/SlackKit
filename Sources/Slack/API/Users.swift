//
//  Users.swift
//  SlackKit
//
//  Created by Sarfraz Basha on 1/12/2025.
//

import Foundation

private enum Users: String, Endpoints {
    typealias API = Slack
    static let base = API.baseURL
    
    case list
    case profileGet = "profile.get"
    case profileSet = "profile.set"
    
    var path: URL { Self.base.appending(component: "users.\(rawValue)") }
}

extension Member {
    
    public static func list() async throws -> [Member] {
        
        let resp = try await Users.list.GET
            .response()
        
        guard let response = try? resp.asType(Response.self),
              let members = response.members
        else { throw SlackError.Users(resp.JSON) }
        return members
        
        struct Response: Decodable {
            let ok: Bool
            let members: [Member]?
        }
    }
    
    public func getProfile() async throws -> Profile {
        
        let resp = try await Users.profileGet.GET
            .params([
                "user": id,
                "include_labels": true
            ])
            .response()
        
        guard let response = try? resp.asType(Response.self),
              let profile = response.profile
        else { throw SlackError.Users(resp.JSON) }
        return profile
        
        struct Response: Decodable {
            let ok: Bool
            let profile: Profile?
        }
    }
    
    public func getDM(createIfNeeded: Bool = true) async throws -> Channel {
        try await Member.getDM(withUser: id, createIfNeeded: createIfNeeded)
    }
    
    public static func getDM(withUser id: String, createIfNeeded: Bool = true) async throws -> Channel {
        
        let resp = try await Conversations.open.POST
            .params([
                "users": id,
                "return_im": true,
                "prevent_creation": !createIfNeeded
            ])
            .response()
        
        guard let response = try? resp.asType(Response.self),
              let channel = response.channel
        else { throw SlackError.Conversations(resp.JSON)  }
        return channel
        
        struct Response: Decodable {
            let ok: Bool
            let channel: Channel?
            let warning: String?
        }
    }
}

