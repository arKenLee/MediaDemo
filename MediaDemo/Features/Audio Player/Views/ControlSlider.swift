//
//  ControlSlider.swift
//  MediaDemo
//
//  Created by Lee on 2017/6/11.
//  Copyright © 2017年 arKen. All rights reserved.
//

import UIKit

class ControlSlider: UISlider {

    override func thumbRect(forBounds bounds: CGRect, trackRect rect: CGRect, value: Float) -> CGRect {
        var tmpRect = rect
        tmpRect.origin.x = rect.origin.x - 10
        tmpRect.size.width = rect.size.width + 20        
        return super.thumbRect(forBounds: bounds, trackRect: tmpRect, value: value).insetBy(dx: 10, dy: 10)
//        return CGRectInset ([super thumbRectForBounds:bounds trackRect:rect value:value], 10 , 10);
    }

}
