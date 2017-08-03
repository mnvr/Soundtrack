//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import Foundation

class SHOUTcastStream {

    let url: URL
    let expectedMimeType: String

    weak var delegate: SHOUTcastStreamDelegate?

    private let queue = { () -> OperationQueue in
        var queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    private let configuration = URLSessionConfiguration.default

    private let session: URLSession

    private var task: URLSessionDataTask?

    private var metadataInterval: Int?
    private var nextMetadataInterval: Int?

    private var unprocessedMetadataCount: Int?
    private var unprocessedMetadata: Data?

    init(url: URL, mimeType expectedMimeType: String) {
        self.url = url
        self.expectedMimeType = expectedMimeType

        let sessionDelegate = SessionDelegate()
        session = URLSession(configuration: configuration, delegate: sessionDelegate, delegateQueue: queue)

        sessionDelegate.stream = self
    }

    func connect() {
        queue.addOperation { [weak self] in
            self?.connect_()
        }
    }

    func disconnect() {
        queue.addOperation { [weak self] in
            self?.disconnect_()
        }
    }

    private func connect_() {
        if self.task != nil {
            print("Trying to connect to an stream with an existing task")
            disconnect_()
        }

        let task = session.dataTask(with: makeURLRequest())
        self.task = task

        task.resume()
        print("Created and resumed \(task) in \(session)")
    }

    private func disconnect_() {
        let activeTask = task

        task = nil

        metadataInterval = nil
        nextMetadataInterval = nil

        unprocessedMetadataCount = nil
        unprocessedMetadata = nil

        if let activeTask = activeTask {
            print("Cancelling \(activeTask)")
            activeTask.cancel()
        } else {
            print("Trying to disconnect a stream without an existing task")
        }
    }

    private func makeURLRequest() -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("1", forHTTPHeaderField: "icy-metadata")
        return request
    }

    private func parse(response: URLResponse) -> Bool {
        guard response.mimeType == expectedMimeType else {
            print("Unexpected MIME type '\(response.mimeType)' received (we were expecting '\(expectedMimeType)')")
            return false
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            print("Unexpected \(response) when expecting a HTTP response")
            return false
        }

        guard httpResponse.statusCode == 200 else {
            print("Unexpected HTTP response status \(httpResponse.statusCode)")
            return false
        }

        let headers = httpResponse.allHeaderFields

        if let icyMetaInt = extractIntValue(fromHTTPHeaders: headers, forKey: "icy-metaint") {
            metadataInterval = icyMetaInt
            nextMetadataInterval = icyMetaInt
            print("Metadata expected to be embedded every \(icyMetaInt) bytes in the stream")
        } else {
            print("The stream contains no embedded metadata; track titles will not be available")
        }

        return true
    }

    private func extractIntValue(fromHTTPHeaders headers: [AnyHashable: Any], forKey key: String) -> Int? {
        guard let value: Any = headers[key] else {
            return nil
        }
        let string = String(describing: value)
        return Int(string)
    }

    private func process(data: Data) {
        guard !data.isEmpty else {
            print("Unexpected empty data")
            return
        }

        guard let nextMetadataInterval = nextMetadataInterval else {
            return emit(data: data)
        }

        print("Next metadata chunk expected after \(nextMetadataInterval) bytes")

        if let unprocessedMetadata = unprocessedMetadata {
            self.unprocessedMetadata = nil
            return process(metadata: unprocessedMetadata + data)
        }

        assert(unprocessedMetadataCount == nil)

        if nextMetadataInterval >= data.count {
            self.nextMetadataInterval = nextMetadataInterval - data.count
            return emit(data: data)
        }

        if nextMetadataInterval == 0 {
            return process(lengthPrefixedMetadata: data)
        }

        let (head, optionalTail) = safeSplit(data, at: nextMetadataInterval)

        self.nextMetadataInterval = 0

        emit(data: head)

        if let tail = optionalTail {
            process(lengthPrefixedMetadata: tail)
        }
    }

    private func process(lengthPrefixedMetadata: Data) {
        guard !lengthPrefixedMetadata.isEmpty else {
            print("Unexpected empty length-prefixed metadata")
            return
        }

        assert(unprocessedMetadata == nil)
        assert(unprocessedMetadataCount == nil)
        assert(nextMetadataInterval == 0)

        let (lengthByte, optionalRemainder) = safeSplit(lengthPrefixedMetadata, at: 1)

        let metadataLength = Int(lengthByte[0]) * 16

        if metadataLength == 0 {
            print("Empty metadata")

            nextMetadataInterval = metadataInterval!

            if let remainder = optionalRemainder {
                return process(data: remainder)
            } else {
                return
            }
        }

        unprocessedMetadataCount = metadataLength
        if let remainder = optionalRemainder {
            process(metadata: remainder)
        }

    }

    private func process(metadata: Data) {
        guard !metadata.isEmpty else {
            print("Unexpected empty metadata")
            return
        }

        assert(unprocessedMetadata == nil)
        assert(nextMetadataInterval == 0)

        guard let unprocessedMetadataCount = unprocessedMetadataCount else {
            print("Trying to process metadata without a corresponding length")
            return
        }

        if metadata.count < unprocessedMetadataCount {
            unprocessedMetadata = metadata
            return
        }

        let (onlyMetadata, optionalRemainder) = safeSplit(metadata, at: unprocessedMetadataCount)

        self.unprocessedMetadataCount = nil
        nextMetadataInterval = metadataInterval!

        emit(metadata: onlyMetadata)

        if let remainder = optionalRemainder {
            process(data: remainder)
        }
    }

    // Optimize?
    private func safeSplit(_ data: Data, at index: Data.Index) -> (Data, Data?) {
        let nsdata = data as NSData
        var head: Data
        var tail: Data?

        if index >= data.count {
            head = nsdata.subdata(with: NSMakeRange(0, data.count))
        } else {
            head = nsdata.subdata(with: NSMakeRange(0, index))
            tail = nsdata.subdata(with: NSMakeRange(index, data.count - index))
        }

        return (head, tail)
    }

    private func emit(metadata: Data) {
        guard let string = String(data: metadata, encoding: .utf8) else {
            return
        }

        var title: String?

        let singleQuote = CharacterSet(charactersIn: "'")

        let trimmedString = string.trimmingCharacters(in: CharacterSet.whitespaces)
        let fields = trimmedString.components(separatedBy: ";")
        for field in fields {
            let columns = field.components(separatedBy: "=")
            if columns.count != 2 {
                print("Ignoring unparseable field: \(field)")
                continue
            }
            let (key, quotedValue) = (columns[0], columns[1])
            let value = quotedValue.trimmingCharacters(in: singleQuote)
            print("Parsed metadata: \(key) = [\(value)]")
            if key == "StreamTitle" {
                title = value
            }
        }

        if let title = title {
            delegate?.shoutcastStream(self, gotTitle: title)
        }
    }

    private func emit(data: Data) {
        delegate?.shoutcastStream(self, gotData: data)
    }

    private func endTask(_ task: URLSessionTask) {
        if task == self.task {
            disconnect_()
        }
    }

    class SessionDelegate: NSObject, URLSessionDataDelegate {

        weak var stream: SHOUTcastStream?

        func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
            print("Session did become invalid (\(session)) with error \(error)")
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            if let error = error {
                let nserror = error as NSError
                if nserror.domain == NSURLErrorDomain, nserror.code == NSURLErrorCancelled {
                    print("Cancelled \(task)")
                } else {
                    print("Completed \(task) with error \(error))")
                }
            } else {
                print("Completed \(task)")
            }
            stream?.endTask(task)
        }

        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
            print("Received response for \(dataTask): \(response)")

            if stream?.parse(response: response) == true {
                completionHandler(.allow)
            } else {
                print("Parsing of response headers failed; will cancel the task")
                completionHandler(.cancel)
            }
        }

        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
            print("Received \(data.count) bytes for \(dataTask)")
            stream?.process(data: data)
        }

    }

}

protocol SHOUTcastStreamDelegate: class {

    func shoutcastStream(_ stream: SHOUTcastStream, gotTitle title: String)
    func shoutcastStream(_ stream: SHOUTcastStream, gotData data: Data)

}

class StreamDelegate: SHOUTcastStreamDelegate {

    func shoutcastStream(_ stream: SHOUTcastStream, gotTitle title: String) {
        print("Got title: \(title)")
    }

    func shoutcastStream(_ stream: SHOUTcastStream, gotData data: Data) {
        print("Got \(data.count) bytes")
    }
    
}

func testDrive(shoutcastServerEndpoint: String) {
    let url = URL(string: shoutcastServerEndpoint)!
    let aacMimeType = "audio/aac"

    let stream: SHOUTcastStream = SHOUTcastStream(url: url, mimeType: aacMimeType)
    let delegate = StreamDelegate()
    stream.delegate = delegate
    stream.connect()

    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 3.0) {
        stream.disconnect()
    }
}
