//
//  UIViewController+Alert.swift
//  MediaDemo
//
//  Created by Lee on 2017/6/17.
//  Copyright © 2017年 arKen. All rights reserved.
//

import UIKit

extension UIViewController {
    
    func showAlertPanel(
        title: String?,
        actionTitle: String = "确定",
        handle: ((Void)->Void)?
        )
    {
        showAlert(title: title, message: nil, actionTitles: [actionTitle]) { (_, _) in
            handle?()
        }
    }
    
    func showConfirmPanel(
        title: String?,
        message: String?,
        cancelTitle: String = "取消",
        confirmTitle: String = "确定",
        handle: ((Bool)->Void)?
        )
    {
        showAlert(title: title, message: message, actionTitles: [cancelTitle, confirmTitle]) { (index, _) in
            handle?(index>0)
        }
    }
    
    func showAlert(
        title: String?,
        message: String?,
        actionTitles: [String],
        hasDestructiveAction: Bool = false,
        configureTextFieldHandles: Array<((UITextField) -> Void)>? = nil,
        handle: ((Int, [UITextField]?)->Void)?
        )
    {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        if let configureTextFieldHandles = configureTextFieldHandles {
            for configureHandler in configureTextFieldHandles {
                alertController.addTextField(configurationHandler: configureHandler)
            }
        }
        
        for (index, actionTitle) in actionTitles.enumerated() {
            
            var style: UIAlertActionStyle = ((index == 0) ? .cancel : .default)
            
            if index == 1 && hasDestructiveAction {
                style = .destructive
            }
            
            let action = UIAlertAction(title: actionTitle, style: style) { (_) in
                handle?(index, alertController.textFields)
            }
            
            alertController.addAction(action)
        }
        
        present(alertController, animated: true, completion: nil)
    }
}
