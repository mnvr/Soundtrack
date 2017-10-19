# Soundtrack ⌬

Minimalistic internet radio player.

## Building Soundtrack from Source

There are no external dependencies. You can download the source code,
double click the Xcode project file to open it in Xcode, and click the
Xcode's "Build and Run" button to, well, build and run.

Before running, you need to tell Soundtrack about the URL of your
internet radio server.  You can do this with the following command:

    defaults write com.github.mnvr.Soundtrack.Soundtrack-macOS shoutcastURLs -array "http://your.shoutcast-or-icecast-endpoint.com/etc"

Note that this in not the URL to the playlist (M3U/PLS) file, but the
URL of the SHOUTcast/ICEcast server endpoint itself.  If in doubt, you
can obtain this value by downloading the playlist file and reading it
in a text editor.

