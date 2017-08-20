//
//  PlayerTableViewController.swift
//  MediaDemo
//
//  Created by Lee on 2017/4/30.
//  Copyright © 2017年 arKen. All rights reserved.
//

import UIKit
import AVFoundation

private let videoPlayCellReuseIdentifier = "VideoPlayCell"
private let audioPlayCellReuseIdentifier = "AudioPlayCell"

class PlayerTableViewController: UITableViewController {
    
//    private let resource: [URL] = ["samplemovie.mov", "TheFatRat - Unity.mp3"].lazy.flatMap { Bundle.main.url(forResource: $0, withExtension: nil)
//    }
    
    private lazy var localResources: [URL] = ["samplemovie.mov", "TheFatRat - Unity.mp3"].flatMap { Bundle.main.url(forResource: $0, withExtension: nil) }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return localResources.count
        default:
            return 0
        }
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        switch indexPath.row {
            
        case 0:
            let cell = tableView.dequeueReusableCell(withIdentifier: videoPlayCellReuseIdentifier, for: indexPath)
            return cell
            
        case 1:
            let cell = tableView.dequeueReusableCell(withIdentifier: audioPlayCellReuseIdentifier, for: indexPath)
            return cell
            
        default:
            return UITableViewCell()
        }
        
    }
    
    // MARK: - UITableViewDelegate
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.row {
        case 0:
            return tableView.bounds.width * 0.56
        case 1:
            return 94
        default:
            return 44
        }
    }

    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        
        guard let destVC = segue.destination as? PlayerViewController,
            let selectedIndexPath = tableView.indexPathForSelectedRow else {
            return
        }
        
        let asset: AVURLAsset?
        
        switch selectedIndexPath.section {
        case 0:
            asset = AVURLAsset(url: localResources[selectedIndexPath.row])
        default:
            asset = nil
        }

        if let asset = asset {
            destVC.playerItem = AVPlayerItem(asset: asset)
        }
    }
}
