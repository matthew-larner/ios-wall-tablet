//
//  ViewController.swift
//  HaKiosk
//
//  Created by ClickSend on 11/21/20.
//

import UIKit
import WebKit
import AVKit

class ViewController: UIViewController {
    var activityIndicatorView = UIActivityIndicatorView()
    var url: String?
   
    private lazy var webView: WKWebView = {
        let webConfiguration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.uiDelegate = self
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.panGestureRecognizer.isEnabled = false
        webView.scrollView.bounces = false
        return webView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        webView.configuration.userContentController.addUserScript(self.getZoomDisableScript())
        
        NotificationCenter.default.addObserver(self,
            selector: #selector(applicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil)
        
        let name = NSNotification.Name(rawValue: mqttMessageNotificationName)
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.receivedMessage(notification:)), name: name, object: nil)
        MQTTService.shared.errorBlock = {
            (error) in
            DispatchQueue.main.async {
                self.showAlertView(title: "Error", message: error.localizedDescription)
            }   
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    // MARK: Private Functions
    private func loadUrl(urlString: String) {
        let myURL = URL(string: urlString)
        let myRequest = URLRequest(url: myURL!)
        webView.load(myRequest)
    }
    
    private func getZoomDisableScript() -> WKUserScript {
        let source: String = "var meta = document.createElement('meta');" +
            "meta.name = 'viewport';" +
            "meta.content = 'width=device-width, initial-scale=1.0, maximum- scale=1.0, user-scalable=no';" +
            "var head = document.getElementsByTagName('head')[0];" + "head.appendChild(meta);"
        return WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
    }
    
    private func setupUI() {
        self.view.backgroundColor = .white
        self.view.addSubview(webView)
            
        NSLayoutConstraint.activate([
            webView.topAnchor
                    .constraint(equalTo: self.view.topAnchor),
            webView.leftAnchor
                    .constraint(equalTo: self.view.leftAnchor),
            webView.bottomAnchor
                    .constraint(equalTo: self.view.bottomAnchor),
            webView.rightAnchor
                    .constraint(equalTo: self.view.rightAnchor)
        ])
      
        view.addSubview(activityIndicatorView);
        activityIndicatorView.center = self.view.center
        activityIndicatorView.hidesWhenStopped = true
        activityIndicatorView.style = UIActivityIndicatorView.Style.large

    }
    
    private func showActivityIndicator(show: Bool) {
        if show {
            activityIndicatorView.startAnimating()
        } else {
            activityIndicatorView.stopAnimating()
        }
    }
    
    private func readMessage(message: String, voice: String, volume: Float = 1.0) {
        let synthesizer = AVSpeechSynthesizer()
        let utterance = AVSpeechUtterance(string: message)
        utterance.voice = AVSpeechSynthesisVoice(language: voice)
        utterance.volume = volume
        synthesizer.speak(utterance)
    }
    // MARK: Actions
    @objc func receivedMessage(notification: NSNotification) {
        let userInfo = notification.userInfo as! [String: AnyObject]
        let content = userInfo["message"] as! String
        let topic = userInfo["topic"] as! String
        print("Topic: \(topic)" )
        print("Message: \(content)" )
        guard let navigateTopic = MQTTService.shared.navigationTopic,
              let ttsTopic = MQTTService.shared.ttsTopic,
              let brightnessTopic = MQTTService.shared.brightnessControlTopic else {
            return
        }
        
        if topic == navigateTopic {
            let url = content
            loadUrl(urlString: url);
        } else if topic == ttsTopic {
            print("is TTS Topic" )
            let data = content.data(using: .utf8)!
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options : .allowFragments) as? Dictionary<String,Any> {
                   print(json)
                    let message = json["message"] as! String
                    let voice = json["voice"] as! String
                    let vol = json["volume"] as! String
                    self.readMessage(message: message, voice: voice, volume: Float(vol) ?? 1.0)
                } else {
                    print("Bad json")
                    showAlertView(title: "ERROR:: TTS Topic Payload Bad JSON", message: content)
                }
            } catch let error as NSError {
                print(error)
                showAlertView(title: "ERROR:: TTS Topic Payload Bad JSON", message: error.localizedDescription)
            }
        } else if topic == brightnessTopic {
            UIScreen.main.brightness = CGFloat(Double(content) ?? 1) 
        }
    }
    
    @objc func applicationDidBecomeActive() {

    }
    
    @objc func forwardAction() {
        if webView.canGoForward {
            webView.goForward()
        }
    }
        
    @objc func backAction() {
        if webView.canGoBack {
            webView.goBack()
        }
    }

}


// MARK: WKUIDelegate
extension ViewController: WKUIDelegate, WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        showActivityIndicator(show: false)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        showActivityIndicator(show: true)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        showActivityIndicator(show: false)
    }
}
