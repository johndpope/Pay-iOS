//
//  AppDelegate.swift
//  BankexWallet
//
//  Created by Alexander Vlasov on 26.01.2018.
//  Copyright © 2018 Alexander Vlasov. All rights reserved.
//

import UIKit
import CoreData
import Fabric
import Crashlytics
import Amplitude_iOS
import Firebase
import UserNotifications
import FirebaseMessaging
import FirebaseInstanceID
import PushKit
import CoreSpotlight

enum ShortcutIdentifier:String {
    case send
    case receive
    
    init?(identifer:String) {
        guard let identity = identifer.components(separatedBy: ".").last else {
            return nil
        }
        self.init(rawValue: identity)
    }
}


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    var navigationVC:UINavigationController?
    var currentViewController:UIViewController?
    var service = ContactService()
    var tokenService = CustomERC20TokensServiceImplementation()
    var keyService = SingleKeyServiceImplementation()
    var selectedContact:FavoriteModel?
    let gcmMessageIDKey = "gcm.message_id"
    var selectedAddress:String {
        return keyService.selectedAddress() ?? ""
    }
    
    enum tabBarPage: Int {
        case main = 0
        case wallet = 1
        case settings = 2
    }
    
    static var initiatingTabBar: tabBarPage = .main
    
    
    
    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        completionHandler(handleShortcut(shortcutItem: shortcutItem))
    }
    
    func handleShortcut(shortcutItem:UIApplicationShortcutItem) -> Bool {
        let shortcutType = shortcutItem.type
        guard let shortcutIdentifier = ShortcutIdentifier(identifer:shortcutType) else { return false }
        selectPath(shortcutIdentifier)
        return true
    }
    
    func selectPath(_ identifier:ShortcutIdentifier) {
        if identifier == .send {
            showFirstTabController()
        }else if identifier == .receive {
            //From background
            if isLaunched {
            let tabvc = window?.rootViewController as! BaseTabBarController
            tabvc.selectedIndex = 0
            if let nav = tabvc.viewControllers?[0] as? BaseNavigationController {
                if let addressQRVC = storyboard().instantiateViewController(withIdentifier: "AddressQRCodeController") as? AddressQRCodeController {
                    addressQRVC.addressToGenerateQR = SingleKeyServiceImplementation().selectedAddress()
                    nav.pushViewController(addressQRVC, animated: false)
                }
            }
                //From unlaunch
            }else if !isLaunched {
                Guide.value = identifier.rawValue
            }
        }
    }
    
//    guard let launchOptions = launchOptions else { return true }
//    guard let url = launchOptions[.url] as? NSURL else { return true }
//    handleURL(url as URL)
    

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        prepareAppearance()
        FirebaseApp.configure()
        configurePushes()
        Amplitude.instance().initializeApiKey("27da55fc989fc196d40aa68b9a163e36")
        Crashlytics.start(withAPIKey: "5b2cfd1743e96d92261c59fb94482a93c8ec4e13")
        Fabric.with([Crashlytics.self])
        let initialRouter = InitialLogicRouter()
        let isOnboardingNeeded = UserDefaults.standard.value(forKey: "isOnboardingNeeded")
        if isOnboardingNeeded == nil  {
            showOnboarding()
        }
        guard let navigationController = window?.rootViewController as? UINavigationController else {
            return true
        }
        initialRouter.navigateToMainControllerIfNeeded(rootControler: navigationController)
        window?.backgroundColor = .white
        return true
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        UIApplication.shared.applicationIconBadgeNumber = 0
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        UIApplication.attachBlur()
    }
    
    
    func configurePushes() {
        // [START set_messaging_delegate]
        Messaging.messaging().delegate = self
        // [END set_messaging_delegate]
        // Register for remote notifications. This shows a permission dialog on first run, to
        // show the dialog at a more appropriate time move this registration accordingly.
        // [START register_for_notifications]
        if #available(iOS 10.0, *) {
            // For iOS 10 display notification (sent via APNS)
            UNUserNotificationCenter.current().delegate = self
            
            let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
            UNUserNotificationCenter.current().requestAuthorization(
                options: authOptions,
                completionHandler: {_, _ in })
        } else {
            let settings: UIUserNotificationSettings =
                UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
            UIApplication.shared.registerUserNotificationSettings(settings)
        }
        
        UIApplication.shared.registerForRemoteNotifications()
        
        // [END register_for_notifications]
    }


    func applicationWillEnterForeground(_ application: UIApplication) {
        UIApplication.unattachBlur()
        if UserDefaults.standard.value(forKey: Keys.multiSwitch.rawValue) == nil {
            UserDefaults.standard.set(true, forKey: Keys.multiSwitch.rawValue)
        }
        if UserDefaults.standard.bool(forKey: Keys.multiSwitch.rawValue) && UserDefaults.standard.bool(forKey: "isNotFirst")  {
            showPasscode()
        }
    }
    
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([Any]?) -> Void) -> Bool {
        if userActivity.activityType == FavoriteModel.domainIdentifier || userActivity.activityType == CSSearchableItemActionType {
            if let objectID = userActivity.userInfo![CSSearchableItemActivityIdentifier] as? String {
                if let tabViewController = window?.rootViewController as? BaseTabBarController {
                    tabViewController.selectedIndex = 2
                        if let vcs = tabViewController.viewControllers, let mainNav = vcs[2] as? BaseNavigationController {
                            if let contactsVC = mainNav.viewControllers.first as? ListContactsViewController {
                                service.contactByAddress(objectID) { contact in
                                    if let contact = contact {
                                        mainNav.popToRootViewController(animated: false)
                                        contactsVC.chooseContact(contact: contact)
                                    }
                                }
                                return true
                            }
                        }
                }else if let _ = window?.rootViewController as? BaseNavigationController {
                    if let addr = userActivity.userInfo![CSSearchableItemActivityIdentifier] as? String {
                        service.contactByAddress(addr) { contact in
                            self.selectedContact = contact
                        }
                    }
                }
            }
        }
        
        
        if let incomingURL = userActivity.webpageURL {
            
            let linkHandled = DynamicLinks.dynamicLinks().handleUniversalLink(incomingURL) {
                [weak self] (dynamicLink, error) in
                if let dynamicLink = dynamicLink, let _ = dynamicLink.url {
                    self?.handleIncomingDynamicLink(dynamicLink)
                }
            }
            return linkHandled
        } else {
            return false
        }
    }
    

    
    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        if let dynamicLink = DynamicLinks.dynamicLinks().dynamicLink(fromCustomSchemeURL: url) {
            print("I am handling a link through the openURL method (custom scheme instead of universal)")
            self.handleIncomingDynamicLink(dynamicLink)
            return true
        } else {
            return handleURL(url)
        }
    }
    
    
    
    @discardableResult
    func handleURL(_ url:URL) -> Bool {
        guard let filteredURL = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return true }
        guard let host = filteredURL.host else { return true }
        if host == "ether" {
            if isLaunched {
                goToMain("", true)
            }else {
                goToMain("", false)
            }
            return true
        }else {
            guard let nameToken = host.components(separatedBy: ".").last else { return true }
            guard let selectedToken = tokenService.availableTokensList()?.filter({ return $0.name == nameToken }).first else { return true }
            if isLaunched {
                goToMain(selectedToken.address, true)
            }else {
                goToMain(selectedToken.address, false)
            }
            return true
        }
    }
    
    func handleIncomingDynamicLink(_ dynamicLink: DynamicLink) {
        if dynamicLink.matchType == .weak {
            print("I think your incoming link parameter is \(dynamicLink.url!) but I'm not shure")
        } else {
            guard let pathComponents = dynamicLink.url?.pathComponents else {return}
            for nextPiece in pathComponents {
                if nextPiece == "helloworld" {
                    AppDelegate.initiatingTabBar = .settings
                }
                
                // parsing
            }
            print("Incoming link parameter is \(dynamicLink.url!)")
        }
        
    }
    
    // [START receive_message]
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) {
        // If you are receiving a notification message while your app is in the background,
        // this callback will not be fired till the user taps on the notification launching the application.
        // TODO: Handle data of notification
        // With swizzling disabled you must let Messaging know about the message, for Analytics
        // Messaging.messaging().appDidReceiveMessage(userInfo)
        // Print message ID.
        if let messageID = userInfo[gcmMessageIDKey] {
            print("Message ID: \(messageID)")
        }
        
        // Print full message.
        print(userInfo)
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // If you are receiving a notification message while your app is in the background,
        // this callback will not be fired till the user taps on the notification launching the application.
        // TODO: Handle data of notification
        // With swizzling disabled you must let Messaging know about the message, for Analytics
        // Messaging.messaging().appDidReceiveMessage(userInfo)
        // Print message ID.
        if let messageID = userInfo[gcmMessageIDKey] {
            print("Message ID: \(messageID)")
        }
        
        // Print full message.
        print(userInfo)
        
        completionHandler(UIBackgroundFetchResult.newData)
    }
    // [END receive_message]
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Unable to register for remote notifications: \(error.localizedDescription)")
    }
    
    // This function is added here only for debugging purposes, and can be removed if swizzling is enabled.
    // If swizzling is disabled then this function must be implemented so that the APNs token can be paired to
    // the FCM registration token.
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("APNs token retrieved: \(deviceToken)")
        
        // With swizzling disabled you must set the APNs token here.
        // Messaging.messaging().apnsToken = deviceToken
    }
    
}


// [START ios_10_message_handling]
@available(iOS 10, *)
extension AppDelegate : UNUserNotificationCenterDelegate {
    
    // Receive displayed notifications for iOS 10 devices.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        
        // With swizzling disabled you must let Messaging know about the message, for Analytics
        // Messaging.messaging().appDidReceiveMessage(userInfo)
        // Print message ID.
        if let messageID = userInfo[gcmMessageIDKey] {
            print("Message ID: \(messageID)")
        }
        
        // Print full message.
        print(userInfo)
        
        // Change this to your preferred presentation option
        completionHandler([])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        // Print message ID.
        if let messageID = userInfo[gcmMessageIDKey] {
            print("Message ID: \(messageID)")
        }
        
        // Print full message.
        print(userInfo)
        
        completionHandler()
    }
}
// [END ios_10_message_handling]

extension AppDelegate : MessagingDelegate {
    
    func goToMain(_ tokenAddress:String, _ isLaunch:Bool) {
        let mainInfo = CreateVC(byName: "MainInfoController") as! MainInfoController
        if isLaunch {
            let tab = window?.rootViewController as! BaseTabBarController
            tab.selectedIndex = 0
            guard let nav = tab.viewControllers?[0] as? BaseNavigationController else { return }
            nav.popToRootViewController(animated: false)
            tokenService.updateSelectedToken(to: tokenAddress)
            nav.pushViewController(mainInfo, animated: false)
        }else {
            let tabBar = CreateVC(byName: "MainTabController") as! BaseTabBarController
            window?.rootViewController = tabBar
            guard !PasscodeEnterController.isLocked else { return }
            let passcodeVC = CreateVC(byName: "passcodeEnterController") as! PasscodeEnterController
            currentPasscodeViewController = passcodeVC
            window?.rootViewController?.present(passcodeVC, animated: true, completion: nil)
            let tab = rootVC() as! BaseTabBarController
            tab.selectedIndex = 0
            guard let nav = tab.viewControllers?[0] as? BaseNavigationController else { return }
            tokenService.updateSelectedToken(to: tokenAddress)
            nav.pushViewController(mainInfo, animated: false)
        }
        
    }
    
    // [START refresh_token]
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String) {
        print("Firebase registration token: \(fcmToken)")
        
        let dataDict:[String: String] = ["token": fcmToken]
        NotificationCenter.default.post(name: Notification.Name("FCMToken"), object: nil, userInfo: dataDict)
        UserDefaults.standard.set(fcmToken, forKey: "FirebaseRegistrationToken")
        // TODO: If necessary send token to application server.
        // Note: This callback is fired at each app startup and whenever a new token is generated.
    }
    // [END refresh_token]
    // [START ios_10_data_message]
    // Receive data messages on iOS 10+ directly from FCM (bypassing APNs) when the app is in the foreground.
    // To enable direct data messages, you can set Messaging.messaging().shouldEstablishDirectChannel to true.
    func messaging(_ messaging: Messaging, didReceive remoteMessage: MessagingRemoteMessage) {
        print("Received data message: \(remoteMessage.appData)")
    }
    // [END ios_10_data_message]
}

  var currentPasscodeViewController: PasscodeEnterController?






