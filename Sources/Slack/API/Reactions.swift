//
//  Reactions.swift
//  SlackKit
//
//  Created by Sarfraz Basha on 1/12/2025.
//

import Foundation

private enum Reactions: String, Endpoints {
    public typealias API = Slack
    public static let base = API.baseURL
    
    case add
    case get
    case list
    case remove
    
    public var path: URL { Self.base.appending(component: "reactions.\(rawValue)") }
}

extension MessageResponse {
    
    public func addReaction(_ reaction: String) async throws {
        
        let resp = try await Reactions.add.POST
            .params([
                "channel": channel.id,
                "name": reaction,
                "timestamp": ts
            ])
            .response()
        
        guard let response = try? resp.asType(Response.self)
        else { throw SlackError.Reactions(resp.JSON) }
        
        guard let error = response.error,
              error != "already_reacted"
        else { return }
        throw SlackError.Reactions(resp.JSON)
        
        struct Response: Decodable {
            let ok: Bool
            let error: String?
        }
        
    }
    
    public func removeReaction(_ reaction: String) async throws {
        
        let resp = try await Reactions.remove.POST
            .params([
                "channel": channel.id,
                "name": reaction,
                "timestamp": ts
            ])
            .response()
        
        guard let response = try? resp.asType(Response.self)
        else { throw SlackError.Reactions(resp.JSON) }
        
        guard let error = response.error,
              error != "no_reaction"
        else { return }
        throw SlackError.Reactions(resp.JSON)
        
        struct Response: Decodable {
            let ok: Bool
            let error: String?
        }
        
    }
    
    public func getReactions() async throws -> [Message.Reaction] {
        
        let resp = try await Reactions.get.GET
            .params([
                "channel": channel.id,
                "full": true, // If true always return the complete reaction list.
                "timestamp": ts
            ])
            .response()
        
        guard let response = try? resp.asType(Response.self),
              let reactions = response.message?.reactions
        else { throw SlackError.Reactions(resp.JSON) }
        return reactions
        
        struct Response: Decodable {
            let ok: Bool
            let error: String?
            let type: String?
            let message: Message?
            let channel: String?
        }
        
    }
}


public struct ProfileSchema: Decodable {
    let fields: [FieldSchema]?
    let sections: [SectionSchema]?
    
    struct FieldSchema: Decodable {
        let id: String
        let type: String?
        let field_name: String?
        let hint: String?
        let is_hidden: Bool?
        let label: String?
        let ordering: Int?
    //    let options:
    }
    
    struct SectionSchema: Decodable {
        let id: String
        let team_id: String?
        
        let section_type: String?
        let label: String?
        let order: Int?
        let is_hidden: Bool?
    }
}
