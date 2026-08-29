//
//  Password.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/9/26.
//


// I know jack shit about secuitry so maybe encript this later??
// Idk...
import Foundation
import SwiftData

@Model
final class Password {
    var profileID: UUID?
    var url: String
    var username: String
    var email: String?
    var passwordData: String
    var createdAt: Date
    
    init(profileID: UUID? = nil, url: String, username: String, email: String? = nil, passwordData: String) {
        self.profileID = profileID
        self.url = url
        self.username = username
        self.email = email
        self.passwordData = passwordData
        self.createdAt = Date()
    }
}
