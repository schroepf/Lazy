//
//  AppDelegate.swift
//  Lazy
//
//  Created by Tobias Schröpf on 06.11.18.
//  Copyright © 2018 Tobias Schröpf. All rights reserved.
//

import UIKit
import XCGLogger

let log = XCGLogger.default

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        log.setup(level: .debug, showThreadName: true, showLevel: true, showFileNames: true, showLineNumbers: true, fileLevel: .debug)

        // You can also change the labels for each log level, most useful for alternate languages, French, German etc, but Emoji's are more fun
        log.levelDescriptions[.verbose] = "💜"
        log.levelDescriptions[.debug] = "💚"
        log.levelDescriptions[.info] = "💙"
        log.levelDescriptions[.notice] = "💛"
        log.levelDescriptions[.warning] = "🧡"
        log.levelDescriptions[.error] = "❤️"
        log.levelDescriptions[.severe] = "🖤"

        log.logAppDetails()

        log.verbose("A verbose message, usually useful when working on a specific problem")
        log.debug("A debug message")
        log.info("An info message, probably useful to power users looking in console.app")
        log.warning("A warning message, may indicate a possible error")
        log.error("An error occurred, but it's recoverable, just info about what happened")
        log.severe("A severe error occurred, we are likely about to crash now")
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }


}

