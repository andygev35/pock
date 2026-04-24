//
//  main.swift
//  Relaunch
//
//  Created by Pierluigi Galdi on 20/03/21.
//  Updated to use modern NSWorkspace API (macOS 10.15+)
//

import AppKit

class Observer: NSObject {
    let completion: (() -> Void)?
    init(_ completion: (() -> Void)?) {
        self.completion = completion
    }
    // swiftlint:disable block_based_kvo
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        completion?()
    }
    // swiftlint:enable block_based_kvo
}

autoreleasepool {
    let parentPID = atoi(ProcessInfo.processInfo.arguments[1])
    if let app = NSRunningApplication(processIdentifier: parentPID), let url = app.bundleURL {
        let listener = Observer {
            CFRunLoopStop(CFRunLoopGetCurrent())
        }
        app.addObserver(listener, forKeyPath: "isTerminated", options: .new, context: nil)
        app.forceTerminate()
        CFRunLoopRun()
        app.removeObserver(listener, forKeyPath: "isTerminated", context: nil)
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, error in
            if let error = error {
                NSLog("[Pock][Relaunch]: Can't relaunch Pock right now. Reason: \(error.localizedDescription)")
            } else {
                NSLog("[Pock][Relaunch]: Pock relaunched successfully!")
            }
        }
        // Give the async open call time to complete before the process exits
        Thread.sleep(forTimeInterval: 2.0)
    }
}
