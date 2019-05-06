//
//  UartModuleViewController.swift
//  Basic Chat
//
//  Created by Trevor Beaton on 12/4/16.
//  Copyright © 2016 Vanguard Logic LLC. All rights reserved.
//

import UIKit
import CoreBluetooth
import PolarBleSdk
import Firebase
import FirebaseDatabase
import UserNotificationsUI

class UartModuleViewController: UIViewController, CBPeripheralManagerDelegate, UITextViewDelegate, PolarBleApiDeviceHrObserver, UNUserNotificationCenterDelegate, MessagingDelegate  {
    
    //UI
    @IBOutlet weak var physicalHR: UILabel!
    @IBOutlet weak var digitalHR: UILabel!
    
    //Data
    var peripheralManager: CBPeripheralManager?
    var peripheral: CBPeripheral!
    private var consoleAsciiText:NSAttributedString? = NSAttributedString(string: "")
    
    var hr = Int()
    
    let gcmMessageIDKey = "gcm.message_id"
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    var db: DatabaseReference!
    
    let date = Date()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //Create and start the peripheral manager
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        //-Notification for updating the text view with incoming text
        updateIncomingData()
        var api = PolarBleApiDefaultImpl.polarImplementation(DispatchQueue.main, features: Features.allFeatures.rawValue)
        api.deviceHrObserver = self
        
        if #available(iOS 10.0, *) {
            // For iOS 10 display notification (sent via APNS)
            UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
        }
        
        appDelegate.registerForPushNotifications(application: UIApplication.shared)
        Messaging.messaging().delegate = self as MessagingDelegate
        
        db = Database.database().reference()
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
            print(numVal)
//            if (numVal!.count > 0 && numVal?[0] == 1) {
////                print("Value Recieved: \(String(describing: numVal[0])) at \(String(describing: date))")
////                db.childByAutoId().setValue(["date": String(describing: date), "source":"embrace", "heartbeat": hr])
//            }
        }
    }
    
    // PolarBleApiDeviceHrObserver
    func hrValueReceived(_ identifier: String, data: PolarHrData) {
        hr = Int(data.hr)
        NSLog("(\(identifier)) HR notification: \(data.hr) rrs: \(data.rrs) rrsMs: \(data.rrsMs) c: \(data.contact) s: \(data.contactSupported)")
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
            db.childByAutoId().setValue(["date": String(describing: date), "source":"notification", "heartbeat": hr])
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

