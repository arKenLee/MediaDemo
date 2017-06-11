//
//  VideoPlayTableViewCell.swift
//  MediaDemo
//
//  Created by Lee on 2017/4/30.
//  Copyright © 2017年 arKen. All rights reserved.
//

import UIKit

protocol VideoPlayTableViewCellDelegate: class {
    func videoPlayCell(cell: VideoPlayTableViewCell, playPauseButtonClickedWithIndexPath indexPath: NSIndexPath)
}

class VideoPlayTableViewCell: UITableViewCell {
    
    static let identifier = "VideoPlayCell"
    static let cellHeight: CGFloat = (UIScreen.main.bounds.width - 30) * 0.5625 + 30 + 1.0 / UIScreen.main.scale

    @IBOutlet weak var previewView: PlayerView!
    @IBOutlet weak var playPauseButton: UIButton!
    
    weak var delegate: VideoPlayTableViewCellDelegate?
    var indexPath = NSIndexPath(row: -1, section: -1)
    
    @IBAction func playPauseButtonClicked(_ sender: UIButton) {
        delegate?.videoPlayCell(cell: self, playPauseButtonClickedWithIndexPath: indexPath)
    }
    
}
