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

    /// Utterances handed to the synthesizer that have not yet started.
    /// The watchdog uses this to detect a synthesizer that has gone silently dead.
    private struct PendingSpeech {
        let message: String
        let voice: String
        let volume: Float
        let isRetry: Bool
        let order: Int
    }
    private var pendingSpeech: [ObjectIdentifier: PendingSpeech] = [:]
    private var speechCounter = 0

    /// Last time the synthesizer reported any progress (start, word range,
    /// finish, cancel). A synthesizer that claims to be speaking but reports no
    /// progress for `speechStallTimeout` is treated as wedged.
    private var lastSpeechActivity = Date.distantPast
    private let speechStallTimeout: TimeInterval = 3.0

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
        synthesizer.delegate = nil
        synthesizer.stopSpeaking(at: .immediate)
        synthesizer = AVSpeechSynthesizer()
        synthesizer.delegate = self
        pendingSpeech.removeAll()
        lastSpeechActivity = Date.distantPast
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

        speechCounter += 1
        pendingSpeech[ObjectIdentifier(utterance)] = PendingSpeech(message: message, voice: voice, volume: volume, isRetry: isRetry, order: speechCounter)
        synthesizer.speak(utterance)
        scheduleSpeechWatchdog(for: utterance)
    }

    /// Checks that `utterance` starts within `speechStallTimeout`. If the
    /// synthesizer is busy with an earlier utterance that is still making
    /// progress, the check is deferred; otherwise the synthesizer is treated as
    /// dead, recreated, and every pending utterance is replayed once.
    private func scheduleSpeechWatchdog(for utterance: AVSpeechUtterance) {
        DispatchQueue.main.asyncAfter(deadline: .now() + speechStallTimeout) { [weak self] in
            guard let self = self else { return }
            let id = ObjectIdentifier(utterance)
            guard let pending = self.pendingSpeech[id] else { return } // already started or cancelled

            if Date().timeIntervalSince(self.lastSpeechActivity) < self.speechStallTimeout {
                // Something else is genuinely speaking; this one is queued behind it.
                self.scheduleSpeechWatchdog(for: utterance)
                return
            }

            print("TTS watchdog: synthesizer stalled (isSpeaking=\(self.synthesizer.isSpeaking)); recreating and retrying")
            let toRetry = self.pendingSpeech.values.filter { !$0.isRetry }.sorted { $0.order < $1.order }
            self.recreateSynthesizer()
            if toRetry.isEmpty {
                print("TTS watchdog: retry already failed for '\(pending.message)', giving up on it")
            }
            for item in toRetry {
                self.speak(message: item.message, voice: item.voice, volume: item.volume, isRetry: true)
            }
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
        pendingSpeech.removeValue(forKey: ObjectIdentifier(utterance))
        lastSpeechActivity = Date()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        lastSpeechActivity = Date()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        pendingSpeech.removeValue(forKey: ObjectIdentifier(utterance))
        lastSpeechActivity = Date()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        pendingSpeech.removeValue(forKey: ObjectIdentifier(utterance))
        lastSpeechActivity = Date()
    }
}
