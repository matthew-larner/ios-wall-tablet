//
//  ViewController.swift
//  HaKiosk
//
//  Created by ClickSend on 11/21/20.
//

import UIKit
import WebKit
import GPUImage

class HomeViewController: UIViewController {

    var activityIndicatorView = UIActivityIndicatorView()
    var homeViewModel = HomeViewModel()

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

    private lazy var motionRenderView: RenderView = {
        let renderView = RenderView(frame: UIScreen.main.bounds)
        return renderView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        initialiseGpuImageMotionDetection()
        addNotificationObservers()
        homeViewModel.webView = webView
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    // MARK: Private Functions
    private func initialiseGpuImageMotionDetection() {
        #if targetEnvironment(simulator)
            print("Simulator - skipping camera initialization")
        #else
        DispatchQueue.main.async {
            do {
                let camera = try Camera(sessionPreset:.vga640x480, location:.frontFacing)
                let filter = MotionDetector()
                filter.lowPassStrength = 0.1
                camera --> filter --> self.motionRenderView
                camera.startCapture()
                filter.motionDetectedCallback = { (s, f) in
                    self.homeViewModel.motionDetected(strenght: f)
                }
            } catch {
                print("Could not initialize rendering pipeline: \(error)")
            }
        }
        #endif
    }

    private func addNotificationObservers() {
        let name = NSNotification.Name(rawValue: mqttMessageNotificationName)
        NotificationCenter.default.addObserver(self, selector: #selector(HomeViewController.receivedMessage(notification:)), name: name, object: nil)
        MQTTService.shared.errorBlock = {
            (error) in
            DispatchQueue.main.async {
                self.showAlertView(title: "Error", message: error.localizedDescription)
            }
        }
    }

    private func setupUI() {
        self.view.backgroundColor = .white
        self.view.addSubview(motionRenderView)
        NSLayoutConstraint.activate([
            motionRenderView.topAnchor
                    .constraint(equalTo: self.view.topAnchor),
            motionRenderView.leftAnchor
                    .constraint(equalTo: self.view.leftAnchor),
            motionRenderView.bottomAnchor
                    .constraint(equalTo: self.view.bottomAnchor),
            motionRenderView.rightAnchor
                    .constraint(equalTo: self.view.rightAnchor)
        ])
        motionRenderView.alpha = 0

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

    // MARK: Actions
    @objc func receivedMessage(notification: NSNotification) {
        let userInfo = notification.userInfo as! [String: AnyObject]
        let content = userInfo["message"] as! String
        let topic = userInfo["topic"] as! String
        homeViewModel.recievedMqttTopic(topic: topic, message: content)
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
extension HomeViewController: WKUIDelegate, WKNavigationDelegate {
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
