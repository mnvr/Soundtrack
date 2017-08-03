//
//  Copyright (c) 2017 Manav Rathi
//
//  Apache License, v2.0
//

import Foundation

class SHOUTcastStream {

    let url: URL
    let expectedMimeType: String

    private let queue = { () -> OperationQueue in
        var queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    private let configuration = URLSessionConfiguration.default

    private let session: URLSession

    private var dataTask: URLSessionDataTask?
    private var streamTask: URLSessionStreamTask?

    private var metadataInterval: Int?
    private var nextMetadataInterval: Int?

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
        if self.dataTask != nil || self.streamTask != nil {
            print("Trying to connect to an stream with an existing task")
            disconnect_()
        }

        let task = session.dataTask(with: makeURLRequest())
        self.dataTask = task

        task.resume()
        print("Created and resumed \(task) in \(session)")
    }

    private func disconnect_() {
        let activeTask = streamTask

        self.dataTask = nil
        self.streamTask = nil

        self.metadataInterval = nil
        self.nextMetadataInterval = nil

        if let activeTask = activeTask {
            print("Cancelling \(activeTask)")
            activeTask.cancel()
        } else {
            print("Trying to disconnect a stream without an existing task")
        }
    }

    private func makeURLRequest() -> URLRequest {
        let request = URLRequest(url: url)
        // FIXME handle response
        //request.setValue("1", forHTTPHeaderField: "icy-metadata")
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

        if let string = headers["icy-metaint"] as? String, let int8 = Int8(string) {
            metadataInterval = Int(int8) * 16
            print("Metadata expected to be embedded every \(metadataInterval) bytes in the stream")
        } else {
            print("The stream contains no embedded metadata. Track titles will not be available")
        }

        return true
    }

    private func imbibe(_ streamTask: URLSessionStreamTask) {
        self.dataTask = nil
        self.streamTask = streamTask

        enqueueRead()
    }

    private func enqueueRead() {
        guard let streamTask = streamTask else { return }

        if streamTask.state == .canceling || streamTask.state == .completed {
            print("Skipping read \(streamTask) in state \(streamTask.state.rawValue)")
            return
        }

        let length = nextReadSize()

        print("Enqueuing read of \(length) bytes on \(streamTask)")

        streamTask.readData(ofMinLength: length, maxLength: 4 * length, timeout: 0) { [weak self] (data, atEOF, error) in
            if let data = data {
                self?.process(data)
            }

            if let error = error {
                print("Read error: \(error)")
            } else if atEOF {
                print("Read encountered EOF")
            } else {
                self?.enqueueRead()
            }
        }
    }

    private func process(_ data: Data) {
        print("Read \(data.count) bytes")
    }

    private func nextReadSize() -> Int {
        // FIXME
        return 1024 // AAC frame size?
    }

    private func endTask(_ task: URLSessionTask) {
        if task == dataTask || task == streamTask {
            disconnect_()
        }
    }

    class SessionDelegate: NSObject, URLSessionDataDelegate {

        weak var stream: SHOUTcastStream?

        func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
            print("Did become invalid: \(session) became invalid with error \(error)")
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            print("Did complete: \(task) completed with error \(error))")
            stream?.endTask(task)
        }

        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
            print("Did receive response: \(dataTask) received \(response)")

            if stream?.parse(response: response) == true {
                completionHandler(.becomeStream)
            } else {
                completionHandler(.cancel)
            }
        }

        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome streamTask: URLSessionStreamTask) {
            print("Did become: \(dataTask) became a \(streamTask)")
            streamTask.closeWrite()
            stream?.imbibe(streamTask)
        }

    }

}

func testDrive(shoutcastServerEndpoint: String) {
    let url = URL(string: shoutcastServerEndpoint)!
    let aacMimeType = "audio/aac"

    let stream: SHOUTcastStream? = SHOUTcastStream(url: url, mimeType: aacMimeType)
    stream?.connect()

    // API Bug
    //
    // NSURLSessionStreamTask cancel has no effect. The socket remains established.
    //
    // Reproducible on: macOS 10.11
    //
    // Someone else who also ran into the same thing: https://github.com/belkevich/stream-task

    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 3.0) {
        stream?.disconnect()
    }
}


