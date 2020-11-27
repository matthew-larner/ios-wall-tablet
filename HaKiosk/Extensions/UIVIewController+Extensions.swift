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
}
