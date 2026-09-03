//
//  UIVIewController+Extensions.swift
//  HaKiosk
//
//  Created by ClickSend on 11/21/20.
//

import Foundation
import UIKit

extension UIViewController {
    func showAlertView(title: String, message: String) {
        let alertView = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertView.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alertView, animated: true, completion: nil)
    }

    /// Shows a non-blocking alert that dismisses itself after `duration` seconds.
    /// If an alert is already on screen, its message is updated instead of stacking a new one.
    func showTransientAlert(title: String, message: String, duration: TimeInterval = 3.0) {
        if let existing = presentedViewController as? UIAlertController {
            existing.title = title
            existing.message = message
            return
        }
        // Don't fight with another presented screen (e.g. the settings menu).
        guard presentedViewController == nil else { return }

        let alertView = UIAlertController(title: title, message: message, preferredStyle: .alert)
        present(alertView, animated: true, completion: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak alertView] in
            guard let alertView = alertView, alertView.presentingViewController != nil else { return }
            alertView.dismiss(animated: true, completion: nil)
        }
    }
}
