//
//  MenuViewController.swift
//  HaKiosk
//
//  Created by ClickSend on 11/21/20.
//

import UIKit
import AVKit

class MenuViewController: UIViewController {

    @IBOutlet private weak var hostTf: UITextField!
    @IBOutlet private weak var portTf: UITextField!
    @IBOutlet private weak var usernameTf: UITextField!
    @IBOutlet private weak var passwordTf: UITextField!
    @IBOutlet private weak var ttsTopicTf: UITextField!
    @IBOutlet private weak var brightnessControlTopicTf: UITextField!
    @IBOutlet private weak var navigateTopicTf: UITextField!
    @IBOutlet private weak var motionDetectionTopicTf: UITextField!
    @IBOutlet private weak var userInterfaceStyleTopicTf: UITextField!
    @IBOutlet private weak var systemSoundTopicTf: UITextField!
    @IBOutlet private weak var statusLabel: UILabel!
    @IBOutlet private weak var saveButton: UIButton!
    
    let mqttService = MQTTService.shared

    override func viewDidLoad() {
        super.viewDidLoad()
    
        hostTf.text = mqttService.host
        if let port =  mqttService.port {
            portTf.text = String(port)
        }
        usernameTf.text = mqttService.username
        passwordTf.text = mqttService.password
        ttsTopicTf.text = mqttService.ttsTopic
        navigateTopicTf.text = mqttService.navigationTopic
        brightnessControlTopicTf.text = mqttService.brightnessControlTopic
        motionDetectionTopicTf.text = mqttService.motionDetectionTopic
        userInterfaceStyleTopicTf.text = mqttService.userInterfaceStyleTopic
        systemSoundTopicTf.text = mqttService.systemSoundTopic
        updateMqttStatus()
        mqttService.connectionStatusChangeBlock =  { [weak self]
            (status) in
            guard let strongSelf = self else {
                return
            }
            DispatchQueue.main.async {
                strongSelf.updateMqttStatus()
            }
        }
        
        mqttService.connectionSuccessBlock =  { [weak self]
            (status) in
            guard let strongSelf = self else {
                return
            }
            DispatchQueue.main.async {
                strongSelf.updateMqttStatus()
            }
        }
    }
    
    private func updateMqttStatus() {
        let status = mqttService.status()
        if (status == .connected) {
            statusLabel!.text = "Connected"
            statusLabel!.textColor = UIColor.systemGreen
            saveButton.setTitle("Disconnect", for: .normal)
        } else if (status == .disconnected) {
            statusLabel!.text = "Disconnected"
            statusLabel!.textColor = UIColor.systemRed
            saveButton.setTitle("Connect and Save", for: .normal)
        } else {
            if status == .initial {
                statusLabel!.text = "Disconnected"
                statusLabel!.textColor = UIColor.systemRed
            } else {
                statusLabel!.textColor = UIColor.systemOrange
                statusLabel!.text = status.description
            }
            
            saveButton.setTitle("Connect and Save", for: .normal)
        }
    }
    
    @IBAction private func didTapSave() {
        if mqttService.status() == .connected {
            mqttService.disconnectToServer()
        } else {
            if allFieldsValid()  {
                guard let host = hostTf.text,
                      let port = portTf.text,
                      let ttsTopic = ttsTopicTf.text,
                      let navigateTopic = navigateTopicTf.text,
                      let brightnessTopic = brightnessControlTopicTf.text,
                      let motionDetectionTopic = motionDetectionTopicTf.text,
                      let userInterfaceStyleTopic = userInterfaceStyleTopicTf.text,
                      let systemSoundTopic = systemSoundTopicTf.text else {
                    return
                }
                
                mqttService.host = host
                mqttService.port = Int(port)
                mqttService.ttsTopic = ttsTopic;
                mqttService.navigationTopic = navigateTopic
                mqttService.brightnessControlTopic = brightnessTopic
                mqttService.motionDetectionTopic = motionDetectionTopic
                mqttService.userInterfaceStyleTopic = userInterfaceStyleTopic
                mqttService.systemSoundTopic = systemSoundTopic
                mqttService.username = usernameTf.text
                mqttService.password = passwordTf.text
                mqttService.connectToServer()
                dismiss(animated: true, completion: nil)
            } else {
                showAlertView(title: "Oops!", message: "Missing required fields")
            }
        }
    }
    
    func allFieldsValid() -> Bool {
        if hostTf.text!.isEmpty ||
            portTf.text!.isEmpty ||
            ttsTopicTf.text!.isEmpty ||
            navigateTopicTf.text!.isEmpty ||
            motionDetectionTopicTf.text!.isEmpty ||
            userInterfaceStyleTopicTf.text!.isEmpty ||
            systemSoundTopicTf.text!.isEmpty {
            return false
        }
        return true;
    }
}
