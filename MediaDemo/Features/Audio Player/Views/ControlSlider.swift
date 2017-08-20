//
//  ControlSlider.swift
//  MediaDemo
//
//  Created by Lee on 2017/6/11.
//  Copyright © 2017年 arKen. All rights reserved.
//

import UIKit

class ControlSlider: UISlider {
    
    override func awakeFromNib() {
        super.awakeFromNib()
        let tap = UITapGestureRecognizer(target: self, action: #selector(tappedSlider(_:)))
        self.addGestureRecognizer(tap)
    }

    override func thumbRect(forBounds bounds: CGRect, trackRect rect: CGRect, value: Float) -> CGRect {
        var tmpRect = rect
        tmpRect.origin.x = rect.origin.x - 10
        tmpRect.size.width = rect.size.width + 20        
        return super.thumbRect(forBounds: bounds, trackRect: tmpRect, value: value).insetBy(dx: 10, dy: 10)
    }

    @objc private func tappedSlider(_ sender: UITapGestureRecognizer) {
        let position =  sender.location(in: self)
        let progress = (position.x - 5) / self.bounds.width

        self.value = Float(progress) * self.maximumValue
        sendActions(for: .touchUpInside)
    }
}
