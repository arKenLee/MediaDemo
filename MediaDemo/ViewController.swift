//
//  ViewController.swift
//  MediaDemo
//
//  Created by Lee on 2017/4/2.
//  Copyright © 2017年 arKen. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

/*
// Configure the audio session for playback and recording
NSError *audioSessionError = nil;

AVAudioSession *session = [AVAudioSession sharedInstance];

[session setCategory:AVAudioSessionCategoryPlayback error:&audioSessionError];
if (audioSessionError) {
    NSLog(@"Error %ld, %@",
           (long)audioSessionError.code, audioSessionError.localizedDescription);
}

// Set some preferred values
NSTimeInterval bufferDuration = .005; // I would prefer a 5ms buffer duration
[session setPreferredIOBufferDuration:bufferDuration error:&audioSessionError];
if (audioSessionError) {
    NSLog(@"Error %ld, %@",
           (long)audioSessionError.code, audioSessionError.localizedDescription);
}

double sampleRate = 44100.0; // I would prefer a sample rate of 44.1kHz
[session setPreferredSampleRate:sampleRate error:&audioSessionError];
if (audioSessionError) {
    NSLog(@"Error %ld, %@",
           (long)audioSessionError.code, audioSessionError.localizedDescription);
}

// Register for Route Change notifications
[[NSNotificationCenter defaultCenter] addObserver: self
    selector: @selector(handleRouteChange:)
    name: AVAudioSessionRouteChangeNotification
    object: session];

// *** Activate the audio session before asking for the "Current" values ***
[session setActive:YES error:&audioSessionError];
if (audioSessionError) {
    NSLog(@"Error %ld, %@",
           (long)audioSessionError.code, audioSessionError.localizedDescription);
}

// Get current values
sampleRate = session.sampleRate;
bufferDuration = session.IOBufferDuration;

NSLog(@"Sample Rate:%0.0fHz I/O Buffer Duration:%f", sampleRate, bufferDuration);
 */
