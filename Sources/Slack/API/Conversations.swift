//
//  Conversations.swift
//  SlackKit
//
//  Created by Sarfraz Basha on 27/11/2025.
//

import Foundation

internal enum Conversations: String, Endpoints {
    typealias API = Slack
    static let base = API.baseURL
    
    case list
    case replies
    case history
    case info
    case open
    
    case join
    case invite
    case kick
    
    var path: URL { Self.base.appending(component: "conversations.\(rawValue)") }
}

extension Channel {
    
    public static func list() async throws -> [Channel] {
        
        let resp = try await Conversations.list.GET
            .params([
                "exclude_archived": true,
                "types": "public_channel, private_channel, mpim, im"
            ])
            .response()
        
        guard let response = try? resp.asType(Response.self),
              let channels = response.channels
        else { throw SlackError.Conversations(resp.JSON)  }
        return channels
        
        struct Response: Decodable {
            let ok: Bool
            let channels: [Channel]?
        }
    }
    
    
    
    public func history() async throws -> [MessageResponse] {
        
        let resp = try await Conversations.history.GET
            .params(["channel": id, "include_all_metadata": true])
            .response()
        
        guard let response = try? resp.asType(Response.self),
              let messages = response.messages
        else { throw SlackError.Conversations(resp.JSON)  }
        return messages.compactMap { MessageResponse($0, channel: self) }
        
        struct Response: Decodable {
            let ok: Bool
            let messages: [Message]?
            let is_limited: Bool?
            let pin_count: Int?
            let has_more: Bool?
        }
    }
    public func getReplies(to ts: String) async throws -> [MessageResponse] {
        
        let resp = try await Conversations.replies.GET
            .params([
                "channel": id,
                "ts": ts
            ])
            .response()
        
        print(#function, "JSON", resp.JSON)
        guard let response = try? resp.asType(Response.self),
              let messages = response.messages
        else { throw SlackError.Conversations(resp.JSON)  }
        return messages.compactMap { MessageResponse($0, channel: self) }
        struct Response: Decodable {
            let ok: Bool
            let messages: [Message]?
            let is_limited: Bool?
            let pin_count: Int?
            let has_more: Bool?
        }
    }
    
    public func info() async throws -> Channel {
        
        let resp = try await Conversations.info.GET
            .params([
                "channel": id,
                "include_num_members": true,
                "include_locale": true,
            ])
            .response()
        
        guard let response = try? resp.asType(Response.self),
              let channel = response.channel
        else { throw SlackError.Conversations(resp.JSON)  }
        return channel
    }
    
    @discardableResult
    public func join() async throws -> Channel {
        
        let resp = try await Conversations.join.POST
            .params(["channel": id])
            .response()
        
        guard let response = try? resp.asType(Response.self),
              let channel = response.channel
        else { throw SlackError.Conversations(resp.JSON)  }
        if let warning = response.warning {
            print("Join warning: \(warning)")
        }
        return channel
        
    }
    
    @discardableResult
    public func invite(_ user: Member) async throws -> Channel {
        try await invite([user])
    }
    @discardableResult
    public func invite(_ users: [Member]) async throws -> Channel {
        
        let resp = try await Conversations.invite.POST
            .params([
                "channel": id,
                "users": users.compactMap(\.id).joined(separator: ","),
                "force": true // When set to `true` and multiple user IDs are provided, continue inviting the valid ones while disregarding invalid IDs.
            ])
            .response()
        
        guard let response = try? resp.asType(Response.self)
        else { throw SlackError.Conversations(resp.JSON)  }
        if let warning = response.warning {
            print("Invite warning: \(warning)")
        }
        if let errors = response.errors {
            print("Invite errors: \(errors)")
        }
        return response.channel ?? self
        
        struct Response: Decodable {
            let ok: Bool
            let channel: Channel?
            let warning: String?
            
            let errors: [InviteError]?
            
            struct InviteError: Decodable, CustomStringConvertible {
                let user: String
                let error: String
                
                var description: String {
                    "\(user): \(error)"
                }
            }
            
            
        }
        
    }
    
    /**
     
     */
    public func kick(_ user: Member, authority: Author? = nil) async throws {
        
        let resp = try await Conversations.kick.POST
            .params([
                "channel": id,
                "user": user.id,
            ])
            .from(authority)
            .response()
        
    }
    
    struct Response: Decodable {
        let ok: Bool
        let channel: Channel?
        let warning: String?
    }
}

extension Array where Element == Message {
    public var description: String {
        var array = "[\n\t"
        for elem in self {
            array += "\(elem)"
            if elem != self.last! { array += ",\n\t" }
            else { array += "\n" }
        }
        return array + "]"
    }
}
