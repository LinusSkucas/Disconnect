//
//  BananaPhone.swift
//  BananaPhone
//
//  Created by Linus Skucas on 10/11/21.
//  Gracias, apple sample code
//

import Foundation
import Network
import os.log

/// App -> AirGap
@objc protocol ScreamingStampingHumanUsingMiddleFingerToMonkeyCommunication {
    func register(_ completionHandler: @escaping (Bool) -> Void)
}

/// AirGap -> App
@objc protocol MonkeyToHumanSignLanguage {
    func shouldEatBananana(aboutFlow flowInfo: [String: String], responseHandler: @escaping (Bool) -> Void)
}

typealias NSGorilla = NSObject

class BananaPhone: NSGorilla {
    var listener: NSXPCListener?
    var currentBrainInterface: NSXPCConnection?
    weak var delegate: MonkeyToHumanSignLanguage?
    static let shared = BananaPhone()
    
    private func extensionMachServiceName(from bundle: Bundle) -> String {

        guard let networkExtensionKeys = bundle.object(forInfoDictionaryKey: "NetworkExtension") as? [String: Any],
            let machServiceName = networkExtensionKeys["NEMachServiceName"] as? String else {
                fatalError("Mach service name is missing from the Info.plist")
        }

        return machServiceName
    }
    
    func startListener() {

        let machServiceName = extensionMachServiceName(from: Bundle.main)
        os_log("Starting XPC listener for mach service %@", machServiceName)

        let newListener = NSXPCListener(machServiceName: machServiceName)
        newListener.delegate = self
        newListener.resume()
        listener = newListener
    }
    
    /// This method is called by the app to register with the provider running in the system extension.
    func register(withExtension bundle: Bundle, delegate: MonkeyToHumanSignLanguage, completionHandler: @escaping (Bool) -> Void) {

        self.delegate = delegate

        guard currentBrainInterface == nil else {
            os_log("Already registered with the provider")
            completionHandler(true)
            return
        }

        let machServiceName = extensionMachServiceName(from: bundle)
        let newConnection = NSXPCConnection(machServiceName: machServiceName, options: [])

        // The exported object is the delegate.
        newConnection.exportedInterface = NSXPCInterface(with: MonkeyToHumanSignLanguage.self)
        newConnection.exportedObject = delegate

        // The remote object is the provider's IPCConnection instance.
        newConnection.remoteObjectInterface = NSXPCInterface(with: ScreamingStampingHumanUsingMiddleFingerToMonkeyCommunication.self)

        currentBrainInterface = newConnection
        newConnection.resume()

        guard let providerProxy = newConnection.remoteObjectProxyWithErrorHandler({ registerError in
            os_log("Failed to register with the provider: %@", registerError.localizedDescription)
            self.currentBrainInterface?.invalidate()
            self.currentBrainInterface = nil
            completionHandler(false)
        }) as? ScreamingStampingHumanUsingMiddleFingerToMonkeyCommunication else {
            fatalError("Failed to create a remote object proxy for the provider")
        }

        providerProxy.register(completionHandler)
    }
    
    func promptUser(aboutFlow flowInfo: [String: String], responseHandler:@escaping (Bool) -> Void) -> Bool {

        guard let connection = currentBrainInterface else {
            os_log("Cannot prompt user because the app isn't registered")
            return false
        }

        guard let appProxy = connection.remoteObjectProxyWithErrorHandler({ promptError in
            os_log("Failed to prompt the user: %@", promptError.localizedDescription)
            self.currentBrainInterface = nil
            responseHandler(true)
        }) as? MonkeyToHumanSignLanguage else {
            fatalError("Failed to create a remote object proxy for the app")
        }

        appProxy.shouldEatBananana(aboutFlow: flowInfo, responseHandler: responseHandler)

        return true
    }
}

extension BananaPhone: NSXPCListenerDelegate {

    // MARK: NSXPCListenerDelegate

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {

        // The exported object is this IPCConnection instance.
        newConnection.exportedInterface = NSXPCInterface(with: ScreamingStampingHumanUsingMiddleFingerToMonkeyCommunication.self)
        newConnection.exportedObject = self

        // The remote object is the delegate of the app's IPCConnection instance.
        newConnection.remoteObjectInterface = NSXPCInterface(with: MonkeyToHumanSignLanguage.self)

        newConnection.invalidationHandler = {
            self.currentBrainInterface = nil
        }

        newConnection.interruptionHandler = {
            self.currentBrainInterface = nil
        }

        currentBrainInterface = newConnection
        newConnection.resume()

        return true
    }
}

extension BananaPhone: ScreamingStampingHumanUsingMiddleFingerToMonkeyCommunication {

    // MARK: ProviderCommunication

    func register(_ completionHandler: @escaping (Bool) -> Void) {

        os_log("App registered")
        completionHandler(true)
    }
}
