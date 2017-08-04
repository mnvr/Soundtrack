//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import Foundation

extension Array {

    var random: Element? {
        if isEmpty {
            return nil
        }

        let randomIndex = Index(arc4random_uniform(UInt32(count)))
        return self[randomIndex]
    }

}
