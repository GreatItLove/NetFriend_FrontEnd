//
//  SocketIOManager.swift
//  SocketChat
//
//  Created by Gabriel Theodoropoulos on 1/31/16.
//  Copyright © 2016 AppCoda. All rights reserved.
//

import UIKit
import SocketIO
import SwiftyJSON

class SocketIOManager: NSObject {
    static let sharedInstance = SocketIOManager()
    
    let socket = SocketIOClient(socketURL: URL(string: baseURL)!)
    
    override init() {
        super.init()
    }
    func establishConnection() {
        socket.connect()
    }
    func closeConnection() {
        socket.disconnect()
    }
    func listenMessages() {
        socket.on("newChatMessage") { (dataArray, socketAck) -> Void in
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "newChatMessage"), object: nil, userInfo: dataArray[0] as! [String: AnyObject])
        }
        socket.on("newGroupMessage") { (dataArray, socketAck) -> Void in
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "newGroupMessage"), object: nil, userInfo: dataArray[0] as! [String: AnyObject])
        }
    }
    func sendMessage(parameters:[String:Any]) {
        socket.emit("chatMessage", parameters)
    }
    func sendGroupMessage(parameters:[String:Any]) {
        socket.emit("groupMessage", parameters)
    }
}
