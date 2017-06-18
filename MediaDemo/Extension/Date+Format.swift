//
//  Date+Format.swift
//  MediaDemo
//
//  Created by Lee on 2017/6/11.
//  Copyright © 2017年 arKen. All rights reserved.
//

import Foundation

extension Date {
    private static var recordFileDateFormatter: DateFormatter?
    
    var recordFileName: String {
        
        if Date.recordFileDateFormatter == nil {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH_mm_ss"
            Date.recordFileDateFormatter = formatter
        }
        
        return Date.recordFileDateFormatter!.string(from: self)
    }
}
