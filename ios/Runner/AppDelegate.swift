import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Default to Signature theme colour so corners never flash white before
    // Flutter paints its first frame.
    window?.backgroundColor = UIColor(
      red: 250.0/255.0, green: 241.0/255.0, blue: 225.0/255.0, alpha: 1.0)

    // Method channel so Dart can update the UIWindow background whenever
    // the user changes theme (keeps corners in sync with app background).
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "app/window_color",
        binaryMessenger: controller.binaryMessenger)

      channel.setMethodCallHandler { [weak self] call, result in
        guard call.method == "setWindowColor",
              let argb = call.arguments as? Int else {
          result(FlutterMethodNotImplemented)
          return
        }
        let a = CGFloat((argb >> 24) & 0xFF) / 255.0
        let r = CGFloat((argb >> 16) & 0xFF) / 255.0
        let g = CGFloat((argb >>  8) & 0xFF) / 255.0
        let b = CGFloat( argb        & 0xFF) / 255.0
        DispatchQueue.main.async {
          self?.window?.backgroundColor = UIColor(red: r, green: g, blue: b, alpha: a)
        }
        result(nil)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
