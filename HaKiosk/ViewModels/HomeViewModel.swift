//
//  HomeViewModel.swift
//  HaKiosk
//
//  Created by ClickSend on 12/14/20.
//

import Foundation
import WebKit
import AVKit
import AVFoundation
import MediaPlayer

class HomeViewModel {
    
    var readyToSendMotionDection = false
    var motionDetectionInterval = 10.0
    var timer: Timer?
    
    ///https://developer.apple.com/forums/thread/712809
    ///Moved the declaration of AVSpeechSynthesizer outside the function
    ///issue is iOS16 and later
    let synthesizer = AVSpeechSynthesizer()
    
    var webView: WKWebView! {
        didSet {
            webView.configuration.userContentController.addUserScript(getZoomDisableScript())
        }
    }
    
    init() {
        runTimer()
    }
    
    private func runTimer() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.timer = Timer.scheduledTimer(timeInterval: self.motionDetectionInterval, target: self, selector: #selector(self.timerExecuted), userInfo: nil, repeats: true)
        }
    }
    
    @objc func timerExecuted() {
        print("readyToSendMotionDection")
        readyToSendMotionDection = true
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - Public Funtions
    func recievedMqttTopic(topic: String, message: String) {
        guard let navigateTopic = MQTTService.shared.navigationTopic,
              let ttsTopic = MQTTService.shared.ttsTopic,
              let brightnessTopic = MQTTService.shared.brightnessControlTopic,
              let userInterfaceStyleTopic = MQTTService.shared.userInterfaceStyleTopic,
              let systemSoundTopic = MQTTService.shared.systemSoundTopic else {
            return
        }
        
        if topic == navigateTopic {
            let url = message
            loadUrlToWebView(urlString: url)
        } else if topic == ttsTopic {
            let data = message.data(using: .utf8)!
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options : .allowFragments) as? Dictionary<String,Any> {
                    let message = json["message"] as! String
                    let voice = json["voice"] as! String
                    let vol = json["volume"] as! String
                    readMessage(message: message, voice: voice, volume: Float(vol) ?? 1.0)
                }
            } catch let error as NSError {
                print(error.localizedDescription)
            }
        } else if topic == brightnessTopic {
            UIScreen.main.brightness = CGFloat(Double(message) ?? 1)
        } else if topic == userInterfaceStyleTopic {
            let isDarkMode = message == "dark"
            UIApplication.shared.connectedScenes.forEach { (scene: UIScene) in
                (scene.delegate as? SceneDelegate)?.window?.overrideUserInterfaceStyle =  isDarkMode ? .dark : .light  //Just this one works on iPhone.
            }
        } else if topic == systemSoundTopic {
            let data = message.data(using: .utf8)!
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options : .allowFragments) as? Dictionary<String,Any> {
                    if let soundId = json["system_sound_id"] as? Int {
                        playSound(soundId: soundId)
                    }
                }
            } catch let error as NSError {
                print(error.localizedDescription)
            }
        }
    }
    
    func getZoomDisableScript() -> WKUserScript {
        let source: String = "var meta = document.createElement('meta');" +
            "meta.name = 'viewport';" +
            "meta.content = 'width=device-width, initial-scale=1.0, maximum- scale=1.0, user-scalable=no';" +
            "var head = document.getElementsByTagName('head')[0];" + "head.appendChild(meta);"
        return WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
    }
    
    func loadUrlToWebView(urlString: String) {
        let myURL = URL(string: urlString)
        let myRequest = URLRequest(url: myURL!)
        webView.load(myRequest)
    }
    
    func readMessage(message: String, voice: String, volume: Float = 1.0) {
        let utterance = AVSpeechUtterance(string: message)
        utterance.voice = AVSpeechSynthesisVoice(language: voice)
        utterance.volume = volume
        synthesizer.speak(utterance)
    }
    
    func playSound(soundId: Int) {
        AudioServicesPlayAlertSound(SystemSoundID(soundId))
    }
    
    func setVolumeTo(volume: Float) {
      (MPVolumeView().subviews.filter{NSStringFromClass($0.classForCoder) == "MPVolumeSlider"}.first as? UISlider)?.setValue(volume, animated: false)
    }
    
    func publishMessage(message: String, topic: String) {
        MQTTService.shared.publish(message:message, topic:topic)
    }
    
    func motionDetected(strenght: Float) {
        //At least detected a it a big motion
        if strenght > 0.0 {
            publishMotionDetection()
        }
    }
    func publishMotionDetection() {
        guard readyToSendMotionDection == true,
              let motionDetectionTopic = MQTTService.shared.motionDetectionTopic else {
            return
        }
        readyToSendMotionDection = false
        runTimer()
        publishMessage(message: "on", topic:  motionDetectionTopic)
    }
}
