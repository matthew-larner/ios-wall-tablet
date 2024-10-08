//
//  MQTTService.swift
//  HaKiosk
//
//  Created by ClickSend on 11/21/20.
//

import Foundation
import CocoaMQTT

class MQTTService {
    
    var mqtt: CocoaMQTT?
    var errorBlock: ((_ error: Error) -> ())?
    var connectionSuccessBlock: ((_ status: Bool) -> ())?
    var connectionStatusChangeBlock: ((_ status: CocoaMQTTConnState) -> ())?
    
    static let shared = MQTTService(debug: false)

    init(debug: Bool) {
        if debug {
            UserDefaults.standard.setValue("test.mosquitto.org", forKey: hostKeyId)
            UserDefaults.standard.setValue(1883, forKey: portKeyId)
            UserDefaults.standard.setValue("tts_topic", forKey: ttsTopicKeyId)
            UserDefaults.standard.setValue("nav_topic", forKey: navigateTopicKeyId)
            UserDefaults.standard.setValue("b_topic", forKey: brightnessControlTopicKeyId)
            UserDefaults.standard.setValue("motion_topic", forKey: motionDetectionTopicKeyId)
            UserDefaults.standard.setValue("ui_topic", forKey: userInterfaceStyleTopicKeyId)
            UserDefaults.standard.setValue("system_sound_topic", forKey: systemSoundTopicKeyId)
        } else {
            
            if UserDefaults.standard.integer(forKey: portKeyId) == 0 {
                UserDefaults.standard.setValue(1883, forKey: portKeyId)
            }
            
            if UserDefaults.standard.string(forKey: ttsTopicKeyId) == nil {
                UserDefaults.standard.setValue("wall-tablet/1/tts", forKey: ttsTopicKeyId)
            }
            
            if UserDefaults.standard.string(forKey: navigateTopicKeyId) == nil {
                UserDefaults.standard.setValue("wall-tablet/1/navigate", forKey: navigateTopicKeyId)
            }
            
            if UserDefaults.standard.string(forKey: brightnessControlTopicKeyId) == nil {
                UserDefaults.standard.setValue("wall-tablet/1/brightness", forKey: brightnessControlTopicKeyId)
            }
            
            if UserDefaults.standard.string(forKey: motionDetectionTopicKeyId) == nil {
                UserDefaults.standard.setValue("wall-tablet/1/motion", forKey: motionDetectionTopicKeyId)
            }
            
            if UserDefaults.standard.string(forKey: userInterfaceStyleTopicKeyId) == nil {
                UserDefaults.standard.setValue("wall-tablet/1/appearance", forKey: userInterfaceStyleTopicKeyId)
            }
            
            if UserDefaults.standard.string(forKey: systemSoundTopicKeyId) == nil {
                UserDefaults.standard.setValue("wall-tablet/1/sound", forKey: systemSoundTopicKeyId)
            }
            
        }
    }
    var host: String? {
        get {
            return UserDefaults.standard.string(forKey: hostKeyId);
        } set(val) {
            UserDefaults.standard.setValue(val, forKey: hostKeyId)
        }
    }
    
    var port: Int? {
        get {
            return UserDefaults.standard.integer(forKey: portKeyId);
        } set(val) {
            UserDefaults.standard.setValue(val, forKey: portKeyId)
        }
    }
    
    var username: String? {
        get {
            return UserDefaults.standard.string(forKey: usernameKeyId);
        } set(val) {
            UserDefaults.standard.setValue(val, forKey: usernameKeyId)
        }
    }
    
    var password: String? {
        get {
            return UserDefaults.standard.string(forKey: passwordKeyId);
        } set(val) {
            UserDefaults.standard.setValue(val, forKey: passwordKeyId)
        }
    }
    
    var ttsTopic: String? {
        get {
            return UserDefaults.standard.string(forKey: ttsTopicKeyId);
        } set(val) {
            UserDefaults.standard.setValue(val, forKey: ttsTopicKeyId)
        }
    }
    
    var navigationTopic: String? {
        get {
            return UserDefaults.standard.string(forKey: navigateTopicKeyId);
        } set(val) {
            UserDefaults.standard.setValue(val, forKey: navigateTopicKeyId)
        }
    }
    
    var brightnessControlTopic: String? {
        get {
            return UserDefaults.standard.string(forKey: brightnessControlTopicKeyId);
        } set(val) {
            UserDefaults.standard.setValue(val, forKey: brightnessControlTopicKeyId)
        }
    }
    
    var motionDetectionTopic: String? {
        get {
            return UserDefaults.standard.string(forKey: motionDetectionTopicKeyId);
        } set(val) {
            UserDefaults.standard.setValue(val, forKey: motionDetectionTopicKeyId)
        }
    }
    
    var userInterfaceStyleTopic: String? {
        get {
            return UserDefaults.standard.string(forKey: userInterfaceStyleTopicKeyId);
        } set(val) {
            UserDefaults.standard.setValue(val, forKey: userInterfaceStyleTopicKeyId)
        }
    }
    
    var systemSoundTopic: String? {
        get {
            return UserDefaults.standard.string(forKey: systemSoundTopicKeyId);
        } set(val) {
            UserDefaults.standard.setValue(val, forKey: systemSoundTopicKeyId)
        }
    }
    
    private let clientID = "CocoaMQTT-Matt-" + String(ProcessInfo().processIdentifier)
    
    private init() { }
    
    // Checks Required fields for MQTT
    private func hasMqttRequiredFields() -> Bool {
        guard let _ = host,
              let _ = port,
              let _ = ttsTopic,
              let _ = navigationTopic,
              let _ = brightnessControlTopic,
              let _ = motionDetectionTopic,
              let _ = userInterfaceStyleTopic,
              let _ = systemSoundTopic else {
            return false
        }
        return true;
    }
    
    private func initialiseMqtt() {
        if hasMqttRequiredFields() {
            guard let host = host,
                  let port = port else {
                return
            }
            
            mqtt = CocoaMQTT(clientID: clientID, host: host, port: UInt16(port))
            mqtt!.username = username
            mqtt!.password = password
            mqtt!.keepAlive = 10
            mqtt!.delegate = self
            mqtt!.autoReconnect = true
            
            _ = mqtt!.connect()
        }
    }
    
    func subscribeToTopics() {
        guard let ttsTopic = ttsTopic,
              let navigationTopic = navigationTopic,
              let brightnessControlTopic = brightnessControlTopic,
              let userInterfaceStyleTopic = userInterfaceStyleTopic,
              let systemSoundTopic = systemSoundTopic else {
            return
        }
        
        mqtt?.subscribe(ttsTopic, qos: .qos1)
        mqtt?.subscribe(navigationTopic, qos: .qos1)
        mqtt?.subscribe(brightnessControlTopic, qos: .qos1)
        mqtt?.subscribe(userInterfaceStyleTopic, qos: .qos1)
        mqtt?.subscribe(systemSoundTopic, qos: .qos1)
    }
    
    // MARK: Public Function
    func disconnectToServer() {
        guard let mqtt = self.mqtt else {
            return
        }
        
        mqtt.disconnect()
    }
    
    func connectToServer() {
        guard let mqtt = self.mqtt else {
            initialiseMqtt()
            return
        }
        
        if mqtt.connState == .connecting {
            return
        }
        
        if isMqttConnected() {
            mqtt.disconnect()
        }
        
        guard let host = host,
              let port = port else {
            return
        }
        
        if hasMqttRequiredFields() {
            mqtt.keepAlive = 10
            mqtt.port = UInt16(port)
            mqtt.host = host
            mqtt.username = username
            mqtt.password = password
            mqtt.autoReconnect = true
            _ = mqtt.connect()
        }
        
    }
    
    func isMqttConnected() -> Bool {
        guard let mqtt = self.mqtt else {
            return false
        }
        return mqtt.connState == CocoaMQTTConnState.connected
    }
    
    func status() -> CocoaMQTTConnState {
        guard let mqtt = self.mqtt else {
            return .disconnected
        }
        return mqtt.connState
    }
    
    func publish(message: String, topic: String) {
        guard let mqtt = self.mqtt else {
            return
        }
        
        mqtt.publish(topic, withString: message, qos: .qos1)
    }
}

// MARK: - CocoaMQTTDelegate
extension MQTTService: CocoaMQTTDelegate {
    func mqtt(_ mqtt: CocoaMQTT, didUnsubscribeTopics topics: [String]) {
        print(#function)
        print(topics)
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didSubscribeTopics success: NSDictionary, failed: [String]) {
        print(#function)
        print(success)
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didConnectAck ack: CocoaMQTTConnAck) {
        print(#function)
        if ack == .accept {
            if let connectionSuccessBlock = self.connectionSuccessBlock {
                connectionSuccessBlock(true)
            }
            subscribeToTopics()
        }
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didPublishMessage message: CocoaMQTTMessage, id: UInt16) {
        print(#function)
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didPublishAck id: UInt16) {
        print(#function)
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didReceiveMessage message: CocoaMQTTMessage, id: UInt16 ) {
        print(#function)
        let name = NSNotification.Name(rawValue: mqttMessageNotificationName)
        NotificationCenter.default.post(name: name, object: self, userInfo: ["message": message.string!, "topic": message.topic])
    }

    func mqttDidPing(_ mqtt: CocoaMQTT) {
        print(#function)
    }
    
    func mqttDidReceivePong(_ mqtt: CocoaMQTT) {
        print(#function)
    }
    
    func mqttDidDisconnect(_ mqtt: CocoaMQTT, withError err: Error?) {
        print(#function)
   
        if let error = err, let errorBlock = self.errorBlock {
            if error.localizedDescription == "Socket closed by remote peer" {
                connectToServer()
            } else if error.localizedDescription == "Broken pipe" {
                // No Operation need since it auto reconnects
            } else {
                errorBlock(error)
            }
        } else {
            if let connectionSuccessBlock = self.connectionSuccessBlock {
                connectionSuccessBlock(false)
            }
        }
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didReceive trust: SecTrust, completionHandler: @escaping (Bool) -> Void) {
        print(#function)
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didPublishComplete id: UInt16) {
        print(#function)
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didStateChangeTo state: CocoaMQTTConnState) {
        print(#function)
        print(mqtt.connState.description)
        if let connStatusChangeBlock = self.connectionStatusChangeBlock {
            connStatusChangeBlock(state)
        }
    }
}
