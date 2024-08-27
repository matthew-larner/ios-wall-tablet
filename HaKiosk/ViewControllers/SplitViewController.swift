//
//  SplitViewController.swift
//  HaKiosk
//
//  Created by ClickSend on 11/21/20.
//

import UIKit

class SplitViewController: UISplitViewController, UISplitViewControllerDelegate {

    var hideMenu = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if #available(iOS 14.0, *) {
            preferredDisplayMode = .secondaryOnly
        } else {
            preferredDisplayMode = .primaryHidden
        }
        
        navigationController?.setNavigationBarHidden(true, animated: false)
        
        MQTTService.shared.connectionSuccessBlock =  {
            (status) in
            if (status == true) {
                DispatchQueue.main.async {
                    if #available(iOS 14.0, *) {
                        self.hide(.primary)
                    } else {
                        // Fallback on earlier versions
                        self.splitViewController?.preferredDisplayMode = .primaryHidden
                    }
                }
            }
        }
    }
    

    
}
