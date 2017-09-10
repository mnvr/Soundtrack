//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import Foundation

// A SHOUTcast endpoint is an HTTP endpoint.
//
// - SHOUTcast specific HTTP headers are prefixed with "icy" (I Can Yell).
//
// - The HTTP response body contains the raw audio data, whose MIME type
//   specified by the "Content-Type" header of the HTTP response.
//
// - You can get the server to embed titles by sending it the
//
//       "icy-metadata": 1
//
//   HTTP header in the request. The server will then respond with the
//   "icy-metaint" header in the response, which tell the client how many
//   bytes of data to read from the beginning of the stream before it can
//   expect the beginning of the metadata.
//
//   The first byte of the metadata contains the length of the metadata
//   (divided by 16). The rest of the metadata contains the title, right
//   padded by spaces or nulls if necessary.

/// A socket to a SHOUTcast server
///
/// Connect to a SHOUTcast endpoint, and inform the delegate when
/// we receive song titles and audio packets.

class ShoutcastStream {

    let url: URL
    let expectedMIMEType: String

    weak var delegate: ShoutcastStreamDelegate?

    private let queue: OperationQueue

    private let configuration = URLSessionConfiguration.default

    private let session: URLSession

    private var task: URLSessionDataTask?

    private var metadataInterval: Int?
    private var nextMetadataInterval: Int?

    private var unprocessedMetadataCount: Int?
    private var unprocessedMetadata: Data?

    /// - Parameter url: The URL of the SHOUTcast server. Note that this is
    ///   not the URL of the M3U or PLS playlist, but rather the contents
    ///   of such a playlist.
    ///
    /// - Parameter mimeType: A SHOUTcast server informs us of the MIME type
    ///   of the audio packet that it will be sending us. That value is checked
    ///   against this parameter to make sure we're all on the same page.
    ///   An example and common MIME type is "audio/aac".
    ///
    /// - Parameter queue: A serial dispatch queue which is used to serialize
    ///   the internal functioning of the stream object (this allows the
    ///   stream's public methods to be invoked from any execution context).
    ///   The delegate methods will also be invoked on this queue.
    ///   If the value of this parameter is `nil`, then a serial queue will
    ///   be created and used by the initializer.

    init(url: URL, mimeType expectedMIMEType: String, queue dispatchQueue: DispatchQueue? = nil) {
        self.url = url
        self.expectedMIMEType = expectedMIMEType

        queue = OperationQueue.serial

        let sessionDelegate = SessionDelegate()
        session = URLSession(configuration: configuration, delegate: sessionDelegate, delegateQueue: queue)

        queue.underlyingQueue = dispatchQueue ??
            DispatchQueue(label: String(describing: type(of: self)))

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

    private func didConnect() {
        delegate?.shoutcastStreamDidConnect(self)
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

        delegate?.shoutcastStreamDidDisconnect(self)
    }

    private func makeURLRequest() -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("1", forHTTPHeaderField: "icy-metadata")
        return request
    }

    private func parse(response: URLResponse) -> Bool {
        guard response.mimeType == expectedMIMEType else {
            log.info("Unexpected MIME type '\(response.mimeType)' received (we were expecting '\(expectedMIMEType)')")
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

        weak var stream: ShoutcastStream?

        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
            log.info("Received response for \(dataTask): \(response)")

            if stream?.parse(response: response) == true {
                stream?.didConnect()
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
    }

}

protocol ShoutcastStreamDelegate: class {

    func shoutcastStreamDidConnect(_ stream: ShoutcastStream)
    func shoutcastStreamDidDisconnect(_ stream: ShoutcastStream)

    func shoutcastStream(_ stream: ShoutcastStream, gotTitle title: String)
    func shoutcastStream(_ stream: ShoutcastStream, gotData data: Data)

}
