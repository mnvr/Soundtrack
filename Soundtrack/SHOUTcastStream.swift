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

    private let queue = OperationQueue.serial

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
        log.info("Connecting to \(url)")

        if self.task != nil {
            log.warning("Trying to connect to an stream with an existing task")
            disconnect_()
        }

        let task = session.dataTask(with: makeURLRequest())
        self.task = task

        task.resume()
        log.info("Created and resumed \(task) in \(session)")
    }

    private func disconnect_() {
        let activeTask = task

        task = nil

        metadataInterval = nil
        nextMetadataInterval = nil

        unprocessedMetadataCount = nil
        unprocessedMetadata = nil

        if let activeTask = activeTask {
            if activeTask.state != .completed {
                log.info("Cancelling \(activeTask)")
                activeTask.cancel()
            }
        } else {
            log.warning("Trying to disconnect a stream without an existing task")
        }

        log.info("Disconnected from \(url)")
    }

    private func makeURLRequest() -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("1", forHTTPHeaderField: "icy-metadata")
        return request
    }

    private func parse(response: URLResponse) -> Bool {
        guard response.mimeType == expectedMimeType else {
            log.info("Unexpected MIME type '\(response.mimeType)' received (we were expecting '\(expectedMimeType)')")
            return false
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            log.info("Unexpected \(response) when expecting a HTTP response")
            return false
        }

        guard httpResponse.statusCode == 200 else {
            log.info("Unexpected HTTP response status \(httpResponse.statusCode)")
            return false
        }

        let headers = httpResponse.allHeaderFields

        if let icyMetaInt = extractIntValue(fromHTTPHeaders: headers, forKey: "icy-metaint") {
            metadataInterval = icyMetaInt
            nextMetadataInterval = icyMetaInt
            log.info("Metadata expected to be embedded every \(icyMetaInt) bytes in the stream")
        } else {
            log.info("The stream contains no embedded metadata; track titles will not be available")
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
            return
        }

        guard let nextMetadataInterval = nextMetadataInterval else {
            return emit(data: data)
        }

        log.trace("Next metadata chunk expected after \(nextMetadataInterval) bytes")

        if let unprocessedMetadata = unprocessedMetadata {
            self.unprocessedMetadata = nil
            return process(metadata: unprocessedMetadata + data)
        }

        assert(unprocessedMetadataCount == nil)

        if nextMetadataInterval >= data.count {
            self.nextMetadataInterval = nextMetadataInterval - data.count
            return emit(data: data)
        }

        let (head, tail) = data.split(at: nextMetadataInterval)
        self.nextMetadataInterval = 0
        emit(data: head)
        process(lengthPrefixedMetadata: tail)
    }

    private func process(lengthPrefixedMetadata: Data) {
        guard !lengthPrefixedMetadata.isEmpty else {
            return
        }

        assert(unprocessedMetadata == nil)
        assert(unprocessedMetadataCount == nil)
        assert(nextMetadataInterval == 0)

        let (lengthByte, remainder) = lengthPrefixedMetadata.split(at: 1)

        let metadataLength = Int(lengthByte[0]) * 16

        if metadataLength == 0 {
            nextMetadataInterval = metadataInterval!
            return process(data: remainder)
        } else {
            unprocessedMetadataCount = metadataLength
            process(metadata: remainder)
        }
    }

    private func process(metadata: Data) {
        guard !metadata.isEmpty else {
            return
        }

        assert(unprocessedMetadata == nil)
        assert(nextMetadataInterval == 0)

        guard let unprocessedMetadataCount = unprocessedMetadataCount else {
            log.warning("Trying to process metadata without a corresponding length")
            return
        }

        if metadata.count < unprocessedMetadataCount {
            unprocessedMetadata = metadata
            return
        }

        let (onlyMetadata, remainder) = metadata.split(at: unprocessedMetadataCount)
        self.unprocessedMetadataCount = nil
        nextMetadataInterval = metadataInterval!
        parse(metadata: onlyMetadata)
        process(data: remainder)
    }

    private func parse(metadata: Data) {
        guard !metadata.isEmpty else {
            return
        }

        guard let paddedString = String(data: metadata, encoding: .utf8) else {
            return
        }

        let string = paddedString.trimmingCharacters(in: CharacterSet(charactersIn: "\0 "))
        log.debug("Raw metadata: [\(string)]")

        var title: String?

        let singleQuote = CharacterSet(charactersIn: "'")
        for field in string.components(separatedBy: ";") {
            if field.isEmpty {
                continue
            }
            let columns = field.components(separatedBy: "=")
            if columns.count != 2 {
                log.info("Ignoring unparseable field: \(field)")
                continue
            }
            let (key, quotedValue) = (columns[0], columns[1])
            let value = quotedValue.trimmingCharacters(in: singleQuote)
            log.info("Parsed metadata: \(key) = [\(value)]")

            if key == "StreamTitle" {
                title = value
            }
        }

        emit(title: title)
    }

    private func emit(title: String?) {
        if let title = title {
            delegate?.shoutcastStream(self, gotTitle: title)
        }
    }

    private func emit(data: Data) {
        if !data.isEmpty {
            delegate?.shoutcastStream(self, gotData: data)
        }
    }

    private func endTask(_ task: URLSessionTask) {
        if task == self.task {
            disconnect_()
        }
    }

    class SessionDelegate: NSObject, URLSessionDataDelegate {

        weak var stream: SHOUTcastStream?

        func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
            log.info("Session did become invalid (\(session)) with error \(error)")
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            if let error = error {
                let nserror = error as NSError
                if nserror.domain == NSURLErrorDomain, nserror.code == NSURLErrorCancelled {
                    log.info("Cancelled \(task)")
                } else {
                    log.info("Completed \(task) with error \(error))")
                }
            } else {
                log.info("Completed \(task)")
            }
            stream?.endTask(task)
        }

        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
            log.info("Received response for \(dataTask): \(response)")

            if stream?.parse(response: response) == true {
                completionHandler(.allow)
            } else {
                log.info("Parsing of response headers failed; will cancel the task")
                completionHandler(.cancel)
            }
        }

        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
            log.trace("Received \(data.count) bytes for \(dataTask)")
            stream?.process(data: data)
        }

    }

}

protocol SHOUTcastStreamDelegate: class {

    func shoutcastStream(_ stream: SHOUTcastStream, gotTitle title: String)
    func shoutcastStream(_ stream: SHOUTcastStream, gotData data: Data)

}
