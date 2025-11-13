import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)

    // Register SpruceID channel handler from SpruceIdSupport.swift
    if let window = NSApplication.shared.windows.first,
       let flutterViewController = window.contentViewController as? FlutterViewController {
        let registrar = flutterViewController.registrar(forPlugin: "SpruceIdPlugin")
        SpruceIdChannelHandler.register(with: registrar)
        print("SpruceID macOS: Channel handler registered")
    } else {
        print("SpruceID macOS: Warning - Could not get Flutter view controller")
    }
  }
}
