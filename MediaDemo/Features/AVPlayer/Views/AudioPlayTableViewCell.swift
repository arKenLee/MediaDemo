//
//  AudioPlayTableViewCell.swift
//  MediaDemo
//
//  Created by Lee on 2017/4/30.
//  Copyright © 2017年 arKen. All rights reserved.
//

import UIKit

protocol AudioPlayTableViewCellDelegate: class {
    func audioPlayCell(cell: AudioPlayTableViewCell, playPauseButtonClickedWithIndexPath indexPath: NSIndexPath)
}

class AudioPlayTableViewCell: UITableViewCell {
    
    static let identifier = "AudioPlayCell"
    static let cellHeight: CGFloat = 94.0 + 1.0 / UIScreen.main.scale

    @IBOutlet weak var albumImageView: UIImageView!
    @IBOutlet weak var playPauseButton: UIButton!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var artistsLabel: UILabel!
    
    weak var delegate: AudioPlayTableViewCellDelegate?
    var indexPath = NSIndexPath(row: -1, section: -1)
    
    @IBAction func playPauseButtonClicked(_ sender: UIButton) {
        delegate?.audioPlayCell(cell: self, playPauseButtonClickedWithIndexPath: indexPath)
    }

}
