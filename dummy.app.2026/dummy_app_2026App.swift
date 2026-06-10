import SwiftUI
import FirebaseCore
import Firebase
import FirebaseAnalytics
import FirebaseMessaging
import GoogleTagManager
import BrazeKit

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    static var braze: Braze?
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // MARK: - Braze SDK initialize
        Braze.prepareForDelayedInitialization()
        let configuration = Braze.Configuration(
            apiKey: BrazeSecrets.apiKey, // TODO: Replace with your own apiKey
            endpoint: BrazeSecrets.endpoint // TODO: Replace with your own endpoint
        )
        // Braze debug verbose level
        #if DEBUG
        configuration.logger.level = .debug
        #else
        configuration.logger.level = .info
        #endif
        
        let braze = Braze(configuration: configuration)
        AppDelegate.braze = braze
        print("# ⚡ Braze initialized ⚡")
        
        // MARK: - Firebase SDK initialize
        FirebaseApp.configure()
        print("# ⚡ Firebase initialized ⚡")
        // Enable Firebase SDK Debug (DEV ONLY)
        #if DEBUG
        var args = ProcessInfo.processInfo.arguments
        args.append("-FIRAnalyticsDebugEnabled")
        args.append("-FIRAnalyticsVerboseLoggingEnabled")
        args.append("-FIRDebugEnabled")
        ProcessInfo.processInfo.setValue(args, forKey: "arguments")
        print("# ⚡ Firebase debug enabled ⚡")
        #else
        //
        #endif
        
        // MARK: - Set The FCM Delegate
        Messaging.messaging().delegate = self
        
        // MARK: - User Properties variable
         let userProperties: [String: String] = [
             "first_name": "Scott",
             "last_name": "Pilgrim",
             "email": "test@aja.com",
             "date_of_birth": "2012-12-12",
             "country": "ID",
             "home_city": "Jakarta",
             "language": "en",
             "phone_number": "+6281234567890",
             "gender": "male",
             "test_su_1": "test_su_1",
             "test_su_2": "test_su_2",
             "test_su_3": "test_su_3"
         ]

         userProperties.forEach { key, value in
             Analytics.setUserProperty(value, forName: key)
         }
         print("# ✅ User properties shipped: \(userProperties)")
        
        // MARK: - GTM Initialization Checker
        // === STEP 1: List ALL files in the bundle ===
        print("# ⚙️ === START GTM CONTAINER DEBUG === ⚙️")
        print("# ⚙️ ALL BUNDLE CONTENTS ⚙️")
        if let bundlePath = Bundle.main.resourcePath {
            do {
                let contents = try FileManager.default.contentsOfDirectory(atPath: bundlePath)
                for item in contents {
                    print("#          📦 \(item)")
                    
                    // If it's a directory, list its contents too
                    let fullPath = (bundlePath as NSString).appendingPathComponent(item)
                    var isDirectory: ObjCBool = false
                    if FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDirectory), isDirectory.boolValue {
                        if let subContents = try? FileManager.default.contentsOfDirectory(atPath: fullPath) {
                            for subItem in subContents {
                                print("#                └─ 📄 \(subItem)")
                            }
                        }
                    }
                }
            } catch {
                print("# ❌ Error reading bundle: \(error)")
            }
        }

        // === STEP 2: Check for container folder ===
        print("# ⚙️ === CHECKING CONTAINER FOLDER === ⚙️")
        if let containerPath = Bundle.main.path(forResource: "container", ofType: nil) {
        print("# ✅ Container folder found at: \(containerPath)")
            do {
                let containerContents = try FileManager.default.contentsOfDirectory(atPath: containerPath)
        print("# Files inside container folder:")
                for file in containerContents {
                print("# 📄 \(file)")
                   }
               } catch {
                print("# ❌ Error reading container folder: \(error)")
               }
           } else {
               print("# ❌ Container folder NOT found in bundle")
           }
           
        print("# ⚙️ === TRYING DIFFERENT PATHS === ⚙️")
           let pathsToTry = [
               Bundle.main.path(forResource: GoogleTagManagerSecrets.apiKey, ofType: "json"),  // TODO: Replace with your own container id
               Bundle.main.path(forResource: GoogleTagManagerSecrets.apiKey, ofType: "json", inDirectory: "container"), // TODO: Replace with your own container id
               Bundle.main.path(forResource: "container/\(GoogleTagManagerSecrets.apiKey)", ofType: "json") // TODO: Replace with your own container id
           ]
           for (index, path) in pathsToTry.enumerated() {
               if let path = path {
                   print("# ✅ Path \(index + 1) FOUND: \(path)")
               } else {
                   print("# ❌ Path \(index + 1) NOT FOUND")
               }
           }
           print("# ⚙️ === END GTM CONTAINER DEBUG === ⚙️")
        
        // Request push notification permissions
        UNUserNotificationCenter.current().delegate = self
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { granted, error in
            if granted {
                print("# ✅ Push notifications authorized")
            } else {
                print("# ❌ Push notifications denied")
            }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
        application.registerForRemoteNotifications()

        return true
    }
    
    // MARK: - APNs Token → Forward to Firebase AND Braze
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        AppDelegate.braze?.notifications.register(deviceToken: deviceToken)
        print("# ✅ Device token registered with Firebase + Braze")

        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
            print("# ✅ APNs token received: \(tokenString)")
        
        // MARK: - Fetch FCM Token (moved here so APNs token is guaranteed to be set first)
        Messaging.messaging().token { token, error in
            if let error = error {
                print("# ❌ Error fetching FCM token: \(error)")
            } else if let token = token {
                print("# ✅ FCM Token: \(token)")
            }
        }
    }

    // MARK: - FCM Token auto-refresh listener
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else {
            print("# ❌ FCM token is nil")
            return
        }
        print("# ✅ FCM Token (refreshed): \(fcmToken)")
        UserDefaults.standard.set(fcmToken, forKey: "fcmToken")
    }

    // MARK: - Foreground notification display
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 willPresent notification: UNNotification,
                                 withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .badge, .sound])
    }

    // MARK: - Notification tap handling
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 didReceive response: UNNotificationResponse,
                                 withCompletionHandler completionHandler: @escaping () -> Void) {
        let handled = AppDelegate.braze?.notifications.handleUserNotification(response: response, withCompletionHandler: completionHandler) ?? false
        if handled {
            print("# ✅ Notification handled by Braze")
        } else {
            print("# ⚠️ Notification not handled by Braze")
            completionHandler()
        }
    }
}

@main
struct dummy_app_2026App: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self)
    var delegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

enum BrazeSecrets {
    static let apiKey: String = {
        value(for: "BRAZE_API_KEY")
    }()

    static let endpoint: String = {
        value(for: "BRAZE_ENDPOINT")
    }()

    private static func value(for key: String) -> String {
        guard
            let path = Bundle.main.path(forResource: "BrazeSecrets", ofType: "plist"),
            let dict = NSDictionary(contentsOfFile: path),
            let value = dict[key] as? String
        else {
            fatalError("❌ Missing \(key) in BrazeSecrets.plist")
        }
        return value
    }
}

enum GoogleTagManagerSecrets {
    static let apiKey: String = {
        value(for: "GTM_CONTAINER_ID")
    }()

    private static func value(for key: String) -> String {
        guard
            let path = Bundle.main.path(forResource: "GoogleTagManagerSecrets", ofType: "plist"),
            let dict = NSDictionary(contentsOfFile: path),
            let value = dict[key] as? String
        else {
            fatalError("❌ Missing \(key) in GoogleTagManagerSecrets.plist")
        }
        return value
    }
}
