//
//  UartModuleViewController.swift
//  Basic Chat
//
//  Created by Trevor Beaton on 12/4/16.
//  Copyright © 2016 Vanguard Logic LLC. All rights reserved.
//

import UIKit
import CoreBluetooth
import Firebase
import FirebaseDatabase
import UserNotificationsUI

class UartModuleViewController: UIViewController, CBPeripheralManagerDelegate, UITextViewDelegate, UNUserNotificationCenterDelegate, MessagingDelegate  {
    
    //UI
    @IBOutlet weak var physicalHR: UILabel!
    @IBOutlet weak var digitalHR: UILabel!
    
    //Data
    var peripheralManager: CBPeripheralManager?
    var peripheral: CBPeripheral!
    private var consoleAsciiText:NSAttributedString? = NSAttributedString(string: "")
    
    let gcmMessageIDKey = "gcm.message_id"
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    var db: DatabaseReference!
    var notifHandle: DatabaseHandle?
    var embraceHandle: DatabaseHandle?
    var notifRate = 0
    var embraceRate = 0
    var notifTotal = 0
    var embraceTotal = 0
    var notifNum = 0
    var embraceNum = 0
    
    let date = Date()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //Create and start the peripheral manager
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        //-Notification for updating the text view with incoming text
        updateIncomingData()
        
        if #available(iOS 10.0, *) {
            // For iOS 10 display notification (sent via APNS)
            UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
        }
        
        appDelegate.registerForPushNotifications(application: UIApplication.shared)
        Messaging.messaging().delegate = self as MessagingDelegate
        
        db = Database.database().reference()
        
        let notif_hr = db.child("notif")
        let embrace_hr = db.child("embrace")
        
        notifHandle = notif_hr.observe(.childAdded) { (snapshot) in
            
            let post = snapshot.value as? [String: Any]
            
            if let actualPost = post {
//                print(actualPost["heartbeat"] as! Int)
                self.notifRate += actualPost["heartbeat"] as! Int
                self.notifNum += 1
                print("Notif beat \(String(describing: actualPost["heartbeat"]))")
            }
            
            self.notifTotal = self.notifRate/self.notifNum
            print("Notif BPM \(self.notifRate)/\(self.notifNum) = \(self.notifRate/self.notifNum)")
            self.digitalHR.text = "\(String(describing: self.notifTotal)) BPM"
        }
        
        embraceHandle = embrace_hr.observe(.childAdded) { (snapshot) in
            
            let post = snapshot.value as? [String: Any]
            
            if let actualPost = post {
//                print(actualPost["heartbeat"] as! Int)
                self.embraceRate += actualPost["heartbeat"] as! Int
                self.embraceNum += 1
                print("Embrace beat \(String(describing: actualPost["heartbeat"]))")
            }
            
            self.embraceTotal = self.embraceRate/self.embraceNum
            print("Notif BPM \(self.embraceRate)/\(self.embraceNum) = \(self.embraceRate/self.embraceNum)")
            self.physicalHR.text = "\(String(describing: self.embraceTotal)) BPM"
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        // peripheralManager?.stopAdvertising()
        // self.peripheralManager = nil
        super.viewDidDisappear(animated)
        NotificationCenter.default.removeObserver(self)
        
    }
    
    func updateIncomingData () {
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "Notify"), object: nil , queue: nil){
            notification in
            if (numVal!.count > 0 && numVal?[0] == 1) {
                print("Value Recieved: \(String(describing: numVal?[0])) at \(String(describing: self.date))")
                self.db.child("embrace/").childByAutoId().setValue(["date": String(describing: self.date), "heartbeat": hr])
            }
        }
    }
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if peripheral.state == .poweredOn {
            return
        }
        print("Peripheral manager is running")
    }
    
    // Receive displayed notifications for iOS 10 devices.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        
        // With swizzling disabled you must let Messaging know about the message, for Analytics
        // Messaging.messaging().appDidReceiveMessage(userInfo)
        
        // Print message ID.
        if let messageID = userInfo[gcmMessageIDKey] {
            print("Message ID: \(messageID)")
        }
        
        // Print full message.
        print(userInfo)
        
        // Change this to your preferred presentation option
        completionHandler([.alert])
        
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        // Print message ID.
        if let messageID = userInfo[gcmMessageIDKey] {
            print("Message ID: \(messageID)")
        }
        
        // Print full message.
        print(userInfo)
        
        switch response.actionIdentifier {
        case "CONFIRM_ACTION":
            print("Heart beat: \(String(describing: (hr)))")
            db.child("notif/").childByAutoId().setValue(["date": String(describing: date), "heartbeat": hr])
            break
            
        default:
            break
        }
        
        completionHandler()
    }
    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String) {
        print("Firebase registration token: \(fcmToken)")
        
        let dataDict:[String: String] = ["token": fcmToken]
        NotificationCenter.default.post(name: Notification.Name("FCMToken"), object: nil, userInfo: dataDict)
        // TODO: If necessary send token to application server.
        // Note: This callback is fired at each app startup and whenever a new token is generated.
    }
    
    func messaging(_ messaging: Messaging, didReceive remoteMessage: MessagingRemoteMessage) {
        print("Message Data:", remoteMessage.appData)
    }
}

