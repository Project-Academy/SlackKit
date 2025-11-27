//
//  Author.swift
//  SlackKit
//
//  Created by Sarfraz Basha on 27/11/2025.
//

import Foundation

/**
 The Author Protocol.
 
 Slack Messages can either be sent by:
 1. the app/Bot, OR
 2. the User
 In the case of the former, you can pass extra parameters to customize the Bot's display name &/or display picture when sending the message.
 
 The thing that determines the Author is the token that is passed into the request.
 Use a User's token, and it will send as them, or use a Bot token to send as the Bot.
 */
public protocol Author: Sendable {
    var token: String? { get set }
    
    /**
     Set your bot's display name.
     
     > Example:
     `"My Bot"`
     
     > Warning:
     Setting this field when using a User-token has no effect.
    */
    var username: String? { get set }
    
    /**
     Emoji to use as the icon for this message.
     This IS a colon-surrounded string.
     
     > Example:
     `":nerd_face:"`
     
     > Important:
     Overrides `icon_url`.
     
     > Warning:
     Setting this field when using a User-token has no effect.
     */
    var icon_emoji: String? { get set }
    /**
     URL to an image to use as the icon for this message.

     > Example:
     `"http://lorempixel.com/48/48"`
     
     > Warning:
     Setting this field when using a User-token has no effect.
     */
    var icon_url: String? { get set }
}

public struct Bot: Author {
    
    //--------------------------------------
    // MARK: - VARIABLES -
    //--------------------------------------
    public var username:    String?
    public var icon_emoji:  String?
    public var icon_url:    String?
    
    public var token:       String?
    
    //--------------------------------------
    // MARK: - INITIALISERS -
    //--------------------------------------
    public init(token: String) {
        self.token = token
    }
    public init(username: String?, icon_emoji: String?, token: String?) {
        self.username = username
        self.icon_emoji = icon_emoji
        self.token = token
    }
    public init(username: String?, icon_url: String?, token: String?) {
        self.username = username
        self.icon_url = icon_url
        self.token = token
    }

    
}

public struct User: Author {
    
    //--------------------------------------
    // MARK: - VARIABLES -
    //--------------------------------------
    public var username: String?
    public var icon_emoji: String?
    public var icon_url: String?
    
    public var token: String?
    
    //--------------------------------------
    // MARK: - INITIALISERS -
    //--------------------------------------
    public init(token: String) {
        self.token = token
    }

    
}
