//
//  Member.swift
//  SlackKit
//
//  Created by Sarfraz Basha on 1/12/2025.
//

import Foundation

public struct Member: Codable {
    
    //--------------------------------------
    // MARK: - VARIABLES -
    //--------------------------------------
    public let id: String
    public var team_id: String?
    
    public var color: String?
    public var name: String?
    public var real_name: String?
    public var profile: Profile?
    
    public var tz: String?
    public var tz_label: String?
    public var tz_offset: Int?
    
    public var updated: Int?
    public var deleted: Bool?
    
    //--------------------------------------
    // MARK: - FLAGS -
    //--------------------------------------
    public var is_admin: Bool?
    public var is_app_user: Bool?
    public var is_bot: Bool?
    public var is_email_confirmed: Bool?
    public var is_owner: Bool?
    public var is_primary_owner: Bool?
    public var is_restricted: Bool?
    public var is_ultra_restricted: Bool?
    
    
    //--------------------------------------
    // MARK: - INITIALISERS -
    //--------------------------------------
    public init(_ id: String) {
        self.id = id
    }
    
}
public struct Profile: Codable {
    
    public var title: String?
    public var pronouns: String?
    public var first_name: String?
    public var last_name: String?
    public var real_name: String?
    public var display_name: String?
    
    public var real_name_normalized: String?
    public var display_name_normalized: String?
    
    public var email: String?
    public var phone: String?
    public var fields: [String: Field]?
    public var start_date: String? // yyyy-mm-dd
    
    public var team: String?
    public var always_active: Bool?
    
    public var avatar_hash: String?
    public var image_24: String?
    public var image_32: String?
    public var image_48: String?
    public var image_72: String?
    public var image_192: String?
    public var image_512: String?
    public var image_1024: String?
    public var image_original: String?
    public var is_custom_image: Bool?
    
    public var status_text: String?
    public var status_text_canonical: String?
    public var status_emoji: String?
    public var status_expiration: Int?
    public var status_emoji_display_info: [Status]?
    
    public var huddle_state: String?
    public var huddle_state_expiration_ts: Int?
    
    public struct Status: Codable {
        public let display_url: String?
        public let emoji_name: String?
        public let unicode: String?
    }
    
}
