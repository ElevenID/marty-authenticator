//
//  AppDelegate.swift
//  iOS App Entry Point
//

import UIKit
import Flutter
import SpruceIDMobileSdk
import SpruceIDMobileSdkRs

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }

    let controller = window?.rootViewController as! FlutterViewController

    // Register SpruceID platform channels
    SpruceIdChannelHandler.register(with: controller.binaryMessenger)

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
