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
///
/// The lifetime of the connection is tied to the lifetime of an
/// instance of this class. i.e. the connection is initiated when
/// an instance of the stream is created, and is disconnected when
/// the corresponding instance is let go.

final class ShoutcastStream {

    weak var delegate: ShoutcastStreamDelegate?

    private let expectedMIMEType: String

    private let configuration = URLSessionConfiguration.default
    private let session: URLSession

    private let task: URLSessionDataTask

    private var metadataInterval: Int?
    private var nextMetadataInterval: Int?

    private var unprocessedMetadataCount: Int?
    private var unprocessedMetadata: Data?

    private var lastTitle: String?

    /// Initiate a new connection to a SHOUTcast server.
    ///
    /// To disconnect, simply let go of this instance.
    ///
    /// - Parameter url: The URL of the SHOUTcast server. Note that this is
    ///   not the URL of the M3U or PLS playlist, but rather the contents
    ///   of such a playlist.
    ///
    /// - Parameter mimeType: A SHOUTcast server informs us of the MIME type
    ///   of the audio packet that it will be sending us. That value is checked
    ///   against this parameter to make sure we're all on the same page.
    ///   For example, "audio/aac".
    ///
    /// - Parameter queue: A serial queue for scheduling delegate callbacks.
    ///   This should be a serial queue so as to ensure the correct ordering
    ///   of callbacks.

    init(url: URL, mimeType: String, queue: DispatchQueue) {
        expectedMIMEType = mimeType

        let sessionDelegate = SessionDelegate()
        session = URLSession(configuration: configuration, delegate: sessionDelegate, delegateQueue: nil)

        task = session.dataTask(with: ShoutcastStream.makeRequest(url: url))

        sessionDelegate.stream = self
        session.delegateQueue.underlyingQueue = queue

        task.resume()
        log.info("Created task for connecting to \(url): \(task)")
    }

    deinit {
        session.invalidateAndCancel()
    }

    private func taskDidReceiveValidResponse() {
        delegate?.shoutcastStreamDidConnect(self)
    }

    private static func makeRequest(url: URL) -> URLRequest {
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
            log.trace("Parsed metadata: \(key) = [\(value)]")

            if key == "StreamTitle" {
                title = value
            }
        }

        emit(title: title)
    }

    private func emit(title: String?) {
        if let title = title, title != lastTitle {
            delegate?.shoutcastStream(self, gotTitle: title)
            lastTitle = title
        }
    }

    private func emit(data: Data) {
        if !data.isEmpty {
            delegate?.shoutcastStream(self, gotData: data)
        }
    }

    private func taskDidCompleteWithoutCancellation() {
        delegate?.shoutcastStreamDidDisconnect(self)
    }

    class SessionDelegate: NSObject, URLSessionDataDelegate {

        weak var stream: ShoutcastStream?

        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
            log.info("Received response for \(dataTask): \(response)")

            if stream?.parse(response: response) == true {
                stream?.taskDidReceiveValidResponse()
                completionHandler(.allow)
            } else {
                log.info("Parsing of response headers failed; will cancel the task")
                completionHandler(.cancel)
            }
        }

        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
            log.trace("Received \(data.count) bytes")
            stream?.process(data: data)
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            var wasCancelled = false
            if let error = error {
                let nserror = error as NSError
                if nserror.domain == NSURLErrorDomain, nserror.code == NSURLErrorCancelled {
                    log.info("Cancelled \(task)")
                    wasCancelled = true
                } else {
                    log.info("Completed \(task) with error \(error)")
                }
            } else {
                log.info("Completed \(task)")
            }

            if !wasCancelled {
                stream?.taskDidCompleteWithoutCancellation()
            }
        }

    }

}

protocol ShoutcastStreamDelegate: class {

    func shoutcastStreamDidConnect(_ stream: ShoutcastStream)

    /// Invoked when the stream was broken due to an error.
    ///
    /// Subsequently, the stream is effectively unusable and will not emit
    /// any more messages. The client should let go of this instance and
    /// create a new one.
    
    func shoutcastStreamDidDisconnect(_ stream: ShoutcastStream)
    
    /// This method is only called when the stream gets a title that is
    /// different from the last title it received over the network.
    
    func shoutcastStream(_ stream: ShoutcastStream, gotTitle title: String)
    
    func shoutcastStream(_ stream: ShoutcastStream, gotData data: Data)
    
}
