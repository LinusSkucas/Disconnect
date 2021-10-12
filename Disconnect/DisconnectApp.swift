//
//  DisconnectApp.swift
//  Disconnect
//
//  Created by Linus Skucas on 10/2/21.
//

import SwiftUI
import NetworkExtension
import SystemExtensions

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var internetEnabled = true
    
    // Get the Bundle of the system extension.
    lazy var extensionBundle: Bundle = {

        let extensionsDirectoryURL = URL(fileURLWithPath: "Contents/Library/SystemExtensions", relativeTo: Bundle.main.bundleURL)
        let extensionURLs: [URL]
        do {
            extensionURLs = try FileManager.default.contentsOfDirectory(at: extensionsDirectoryURL,
                                                                        includingPropertiesForKeys: nil,
                                                                        options: .skipsHiddenFiles)
        } catch let error {
            fatalError("Failed to get the contents of \(extensionsDirectoryURL.absoluteString): \(error.localizedDescription)")
        }

        guard let extensionURL = extensionURLs.first else {
            fatalError("Failed to find any system extensions")
        }

        guard let extensionBundle = Bundle(url: extensionURL) else {
            fatalError("Failed to create a bundle with URL \(extensionURL.absoluteString)")
        }

        return extensionBundle
    }()

    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: internetEnabled ? "lightbulb" : "lightbulb.slash", accessibilityDescription: nil)
            button.action = #selector(toggleInternet(_:))
        }
    }
    
    func loadFilterConfiguration(completionHandler: @escaping (Bool) -> Void) {

        NEFilterManager.shared().loadFromPreferences { loadError in
            DispatchQueue.main.async {
                var success = true
                if let error = loadError {
                    os_log("Failed to load the filter configuration: %@", error.localizedDescription)
                    success = false
                }
                completionHandler(success)
            }
        }
    }
    
    @objc func toggleInternet(_ sender: AnyObject?) {
        internetEnabled.toggle()
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: internetEnabled ? "lightbulb" : "lightbulb.slash", accessibilityDescription: nil)
        }
        if !internetEnabled {
            guard !NEFilterManager.shared().isEnabled else {
                registerWithProvider()
                return
            }
            
            guard let extensionIdentifier = extensionBundle.bundleIdentifier else {
                internetEnabled.toggle()
                return
            }
            let activativeRequest = OSSystemExtensionRequest.activationRequest(forExtensionWithIdentifier: extensionIdentifier, queue: .main)
            activativeRequest.delegate = self
            OSSystemExtensionRequest.shared.submitRequest(activativeRequest)
        }
    }
}

@main
struct DisconnectApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
