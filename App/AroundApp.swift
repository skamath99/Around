import CloudKit
import SwiftUI
import UserNotifications

@main
struct AroundApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .tint(.teal)
                .task { AppDelegate.localSenderID = model.senderID }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    /// Used to suppress notification banners for the user's own messages,
    /// since CloudKit subscription predicates can't express `senderID != me`.
    static var localSenderID: String?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        application.registerForRemoteNotifications()
        return true
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any]
    ) async -> UIBackgroundFetchResult {
        NotificationCenter.default.post(name: .aroundRemotePoke, object: nil)
        return .newData
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        // Expected on simulators without push support; CloudKit polling still works.
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        NotificationCenter.default.post(name: .aroundRemotePoke, object: nil)
        if let payload = notification.request.content.userInfo as? [String: NSObject],
           let ckNotification = CKNotification(fromRemoteNotificationDictionary: payload) as? CKQueryNotification,
           let sender = ckNotification.recordFields?["senderID"] as? String,
           sender == Self.localSenderID {
            return []
        }
        return [.banner, .sound, .list]
    }
}
