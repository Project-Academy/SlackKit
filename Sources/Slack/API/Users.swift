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
    case info
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
        else { throw SlackError.Users(resp.json) }
        return members
        
        struct Response: Decodable {
            let ok: Bool
            let members: [Member]?
        }
    }
    
    /**
     Fetches full member info via `users.info`.

     Unlike ``getProfile()`` (which returns a ``Profile`` with no membership
     flags), this returns the whole ``Member`` — including ``Member/deleted``,
     i.e. whether the member has been deactivated on the workspace.

     - Parameters:
       - id: The Slack member ID to look up.
       - author: The workspace's ``Author`` (e.g. a ``Bot`` carrying that
                 workspace's bot token) used to authenticate the request. When
                 `nil`, ``Slack/defaultAuthor`` is used instead.
     */
    public static func getInfo(_ id: String, as author: Author? = nil) async throws -> Member {

        let resp = try await Users.info.GET
            .from(author)
            .params(["user": id])
            .response()

        guard let response = try? resp.asType(Response.self),
              let member = response.user
        else { throw SlackError.Users(resp.json) }
        return member

        struct Response: Decodable {
            let ok: Bool
            let user: Member?
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
        else { throw SlackError.Users(resp.json) }
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
        else { throw SlackError.Conversations(resp.json)  }
        return channel
        
        struct Response: Decodable {
            let ok: Bool
            let channel: Channel?
            let warning: String?
        }
    }
}

