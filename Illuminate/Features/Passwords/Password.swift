//
//  Password.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/9/26.
//


import Foundation
import SwiftData

@Model
final class Password {
    var id: UUID = UUID()
    var profileID: UUID?
    var url: String
    var username: String
    var email: String?
    var passwordData: String
    var createdAt: Date
    
    init(profileID: UUID? = nil, url: String, username: String, email: String? = nil, passwordData: String, id: UUID = UUID()) {
        self.id = id
        self.profileID = profileID
        self.url = url
        self.username = username
        self.email = email
        self.passwordData = passwordData
        self.createdAt = Date()
    }
}
