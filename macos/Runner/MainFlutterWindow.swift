import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var desktopClipboardChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let channel = FlutterMethodChannel(
      name: "sked/desktop_clipboard",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "files" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let urls = NSPasteboard.general.readObjects(
        forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]
      ) as? [NSURL] ?? []
      result(urls.compactMap { value -> [String: Any]? in
        let url = value as URL
        guard url.isFileURL else { return nil }
        var file: [String: Any] = ["path": url.path]
        if let bookmark = try? url.bookmarkData(
          options: .withSecurityScope,
          includingResourceValuesForKeys: nil,
          relativeTo: nil) {
          file["bookmark"] = FlutterStandardTypedData(bytes: bookmark)
        }
        return file
      })
    }
    desktopClipboardChannel = channel

    super.awakeFromNib()
  }
}
