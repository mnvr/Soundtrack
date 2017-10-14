//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import Foundation

struct TitleComponents {
    let artist: String
    let song: String

    init(_ title: String) {
        let components = title.components(separatedBy: " - ")
        artist = components.count > 0 ? components[0] : ""
        song = components.count > 1 ? components[1] : ""
    }
}
