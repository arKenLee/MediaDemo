//
//  AudioRecordFileListCell.swift
//  MediaDemo
//
//  Created by Lee on 2017/6/17.
//  Copyright © 2017年 arKen. All rights reserved.
//

import UIKit

let AudioRecordFileListCellIdentifier = "AudioRecordFileListCell"

class AudioRecordFileListCell: UITableViewCell {

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        accessoryView = selected ? UIImageView(image: #imageLiteral(resourceName: "audio_icon_playing")) : nil
    }
    
}
