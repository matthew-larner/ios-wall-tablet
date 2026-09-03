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

class HomeViewModel: NSObject {

    var readyToSendMotionDection = false
    var motionDetectionInterval = 10.0
    var timer: Timer?

    ///https://developer.apple.com/forums/thread/712809
    ///Moved the declaration of AVSpeechSynthesizer outside the function
    ///issue is iOS16 and later
    var synthesizer = AVSpeechSynthesizer()

    /// Set by the didStart delegate callback; the speak watchdog checks it to
    /// detect a synthesizer that has gone silently dead.
    private var speechStarted = false

    var webView: WKWebView! {
        didSet {
            webView.configuration.userContentController.addUserScript(getZoomDisableScript())
        }
    }

    override init() {
        super.init()
        synthesizer.delegate = self
        runTimer()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }

    @objc private func handleAudioSessionInterruption(notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        if type == .ended {
            // Audio session notifications arrive on a background thread;
            // the synthesizer must only be touched on main.
            DispatchQueue.main.async {
                self.activateAudioSession()
                // Recreate synthesizer — it can get stuck after an interruption
                self.recreateSynthesizer()
            }
        }
    }

    // Bluetooth/headphone connect-disconnect can also break the synthesizer
    @objc private func handleAudioRouteChange(notification: Notification) {
        guard let info = notification.userInfo,
              let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }

        switch reason {
        case .oldDeviceUnavailable, .newDeviceAvailable:
            DispatchQueue.main.async {
                self.recreateSynthesizer()
            }
        default:
            break
        }
    }

    private func recreateSynthesizer() {
        synthesizer.stopSpeaking(at: .immediate)
        synthesizer = AVSpeechSynthesizer()
        synthesizer.delegate = self
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
                    guard let message = json["message"] as? String,
                          let voice = json["voice"] as? String else {
                        print("Ignoring TTS payload missing 'message' or 'voice': \(json)")
                        return
                    }
                    let volume = parseVolume(from: json, defaultValue: 1.0)
                    readMessage(message: message, voice: voice, volume: volume)
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
        guard let myURL = URL(string: urlString) else {
            print("Ignoring invalid navigate URL: \(urlString)")
            return
        }
        let myRequest = URLRequest(url: myURL)
        webView.load(myRequest)
    }

    func readMessage(message: String, voice: String, volume: Float = 1.0) {
        DispatchQueue.main.async {
            self.speak(message: message, voice: voice, volume: volume)
        }
    }

    private func speak(message: String, voice: String, volume: Float, isRetry: Bool = false) {
        activateAudioSession()
        let utterance = AVSpeechUtterance(string: message)
        utterance.voice = AVSpeechSynthesisVoice(language: voice)
        if utterance.voice == nil {
            print("No voice available for language '\(voice)', using system default")
        }
        utterance.volume = volume

        let wasSpeaking = synthesizer.isSpeaking
        speechStarted = false
        synthesizer.speak(utterance)

        // If the synthesizer was already speaking, this utterance is queued and
        // a delayed start is normal — only watchdog an idle synthesizer.
        guard !wasSpeaking, !isRetry else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            guard let self = self, !self.speechStarted else { return }
            print("TTS watchdog: speech never started; recreating synthesizer and retrying")
            self.recreateSynthesizer()
            self.speak(message: message, voice: voice, volume: volume, isRetry: true)
        }
    }

    private func parseVolume(from json: Dictionary<String, Any>, defaultValue: Float) -> Float {
        if let vol = json["volume"] as? String {
            return Float(vol) ?? defaultValue
        } else if let vol = json["volume"] as? NSNumber {
            return vol.floatValue
        }
        return defaultValue
    }

    func playSound(soundId: Int) {
        activateAudioSession()
        AudioServicesPlayAlertSound(SystemSoundID(soundId))
    }

    private func activateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to activate audio session: \(error)")
        }
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

// MARK: - AVSpeechSynthesizerDelegate
extension HomeViewModel: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        speechStarted = true
    }
}
