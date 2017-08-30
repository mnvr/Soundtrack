//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import Foundation

extension AudioFilePlayer {

    private static func demoFileURL() -> URL {
        let fileName = "MN - Going Down.wav"
        guard let url = Bundle.main.url(forResource: fileName, withExtension: nil) else {
            fatalError("Could not locate \(fileName) in the main bundle")
        }
        return url
    }

    static func makeDemo() -> AudioPlayer? {
        return AudioFilePlayer(url: demoFileURL(), loop: true)
    }
    
}
