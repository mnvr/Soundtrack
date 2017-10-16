//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import Foundation

struct TitleComponents {
    let title: String

    let artist: String
    let song: String

    init(_ title: String) {
        self.title = title
        
        let components = title.components(separatedBy: " - ")
        artist = components.count > 0 ? components[0] : ""
        song = components.count > 1 ? components[1] : ""
    }
}
