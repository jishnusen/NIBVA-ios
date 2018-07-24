//
//  SignInView.swift
//  NIBVA
//
//  Created by Jishnu Sen on 7/23/18.
//  Copyright © 2018 Jishnu Sen. All rights reserved.
//

import UIKit
import GoogleSignIn

var globalUser: GIDGoogleUser?

struct UserData: Codable {
    var id = Int()
    var email = String()
    var accType = String()
    var name = String()
    var authCode = String()
}

struct Reading: Codable {
    var authCode = String()
    var id = Int()
    var readings = [ReadBlock]()
}

struct ReadBlock: Codable {
    var timestamp = String()
    var channels = [Int](repeating: Int(), count: 64)
}

class SignInView: UIViewController, GIDSignInUIDelegate {
    @IBOutlet weak var signInButton: UIButton!
    @IBOutlet weak var signOutButton: UIButton!
    @IBOutlet weak var disconnectButton: UIButton!
    @IBOutlet weak var statusText: UILabel!
    @IBOutlet weak var pushText: UILabel!
    
    let urlLogin = URL(string: "https://majestic-legend-193620.appspot.com/security/getAuth")
    let urlReading = URL(string: "https://majestic-legend-193620.appspot.com/insert/reading")
    var signInData = UserData()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        GIDSignIn.sharedInstance().uiDelegate = self
        GIDSignIn.sharedInstance()?.signInSilently()
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(SignInView.receiveToggleAuthUINotification(_:)),
                                               name: NSNotification.Name(rawValue: "ToggleAuthUINotification"),
                                               object: nil)
        
        DispatchQueue.main.async {
            self.pushText.text = ""
        }
        
        toggleAuthUI()
    }
    
    @IBAction func didTapSignOut(_ sender: AnyObject) {
        GIDSignIn.sharedInstance().signOut()
        statusText.text = "Signed out."
        toggleAuthUI()
    }
    
    @IBAction func didTapDisconnect(_ sender: AnyObject) {
        GIDSignIn.sharedInstance().disconnect()
        statusText.text = "Disconnecting."
    }
    
    @IBAction func didTapSignIn(_ sender: AnyObject) {
        GIDSignIn.sharedInstance().signIn()
        toggleAuthUI()
        signIn()
    }
    
    @IBAction func didTapPushReadings(_ sender: Any) {
        pushReadings()
    }
    
    func toggleAuthUI() {
        if GIDSignIn.sharedInstance().hasAuthInKeychain() && globalUser?.profile.name != nil {
            // Signed in
            signInButton.isHidden = true
            signOutButton.isHidden = false
            disconnectButton.isHidden = false
            statusText.text = "Signed in as \(String(globalUser!.profile.name!))"
            print(globalUser?.authentication.accessToken! ?? "NO ACCESS TOKEN")
        } else {
            signInButton.isHidden = false
            signOutButton.isHidden = true
            disconnectButton.isHidden = true
            statusText.text = "Not Signed In"
        }
    }
    
    func signIn() {
        let accessToken = ["accessToken" : globalUser?.authentication.accessToken! ?? ""]
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: accessToken)
            var request = URLRequest(url: urlLogin!)
            request.httpMethod = "POST"
            request.httpBody = jsonData
            var headers = request.allHTTPHeaderFields ?? [:]
            headers["Content-Type"] = "application/json"
            request.allHTTPHeaderFields = headers
            
            let config = URLSessionConfiguration.default
            let session = URLSession(configuration: config)
            let task = session.dataTask(with: request) { (responseData, response, responseError) in
                guard responseError == nil else {
                    print(responseError!)
                    return
                }
                
                // APIs usually respond with the data you just sent in your POST request
                if let data = responseData, let utf8Representation = String(data: data, encoding: .utf8) {
                    print("User data: ", utf8Representation)
                    self.signInData = self.decodeResponse(data)
                } else {
                    print("Failed to log in")
                }
            }
            task.resume()
        } catch {
            print(error)
        }
    }
    
    func decodeResponse(_ data: Data) -> UserData {
        var userData = UserData()
        let decoder = JSONDecoder()
        do {
            userData = try decoder.decode(UserData.self, from: data)
            print(userData)
        } catch {
            print(error)
        }
        
        return userData
    }
    
    func pushReadings() {
        let now = Date()
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        let timestamp = formatter.string(from: now)
        
        var readingData = Reading()
        var lastReading = ReadBlock()
        
        lastReading.timestamp = timestamp
        lastReading.channels = readings
        
        readingData.authCode = self.signInData.authCode
        readingData.id = self.signInData.id
        readingData.readings = [lastReading]
        
        DispatchQueue.main.async {
            self.pushText.text = "Pushing..."
        }
        
        do {
            let encoder = JSONEncoder()
            let jsonData = try encoder.encode(readingData)
            var request = URLRequest(url: urlReading!)
            request.httpMethod = "POST"
            request.httpBody = jsonData
            var headers = request.allHTTPHeaderFields ?? [:]
            headers["Content-Type"] = "application/json"
            request.allHTTPHeaderFields = headers
            
            let config = URLSessionConfiguration.default
            let session = URLSession(configuration: config)
            let task = session.dataTask(with: request) { (responseData, response, responseError) in
                guard responseError == nil else {
                    print(responseError!)
                    return
                }
                
                // APIs usually respond with the data you just sent in your POST request
                if let data = responseData, let utf8Representation = String(data: data, encoding: .utf8) {
                    print("Response: ", utf8Representation)
                    let success = utf8Representation.contains("Success")
                    DispatchQueue.main.async {
                        if (success) {
                            self.pushText.text = "Pushed data on \(timestamp)"
                        } else {
                            self.pushText.text = "Failed to push data on \(timestamp)"
                        }
                    }
                } else {
                    print("Failed to push reading")
                }
            }
            task.resume()
        } catch {
            print(error)
        }
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self,
                                                  name: NSNotification.Name(rawValue: "ToggleAuthUINotification"),
                                                  object: nil)
    }
    
    @objc func receiveToggleAuthUINotification(_ notification: NSNotification) {
        if notification.name.rawValue == "ToggleAuthUINotification" {
            self.toggleAuthUI()
            if notification.userInfo != nil {
                guard let userInfo = notification.userInfo as? [String:String] else { return }
                self.statusText.text = userInfo["statusText"]!
            }
        }
    }
}
