//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import Foundation

extension Data {

    func split(at index: Data.Index) -> (head: Data, tail: Data) {

        // As of Swift 3, there is no specialization for initializing a Data
        // instance from a MutableRandomAccessSlice<Data>. It seems to be
        // doing a non-lazy byte-by-byte copy 😱. This is why we don't:
        //
        //     let head = Data(prefix(upTo: index))
        //     let tail = Data(suffix(from: index))

        if index <= startIndex {
            return (Data(), self)
        } else if index >= endIndex {
            return (self, Data())
        } else {
            let head = subdata(in: Range(uncheckedBounds: (startIndex, index)))
            let tail = subdata(in: Range(uncheckedBounds: (index, endIndex)))
            return (head, tail)
        }
    }

}
