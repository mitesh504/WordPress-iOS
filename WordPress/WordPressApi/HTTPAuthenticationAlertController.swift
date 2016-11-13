import Foundation


public class HTTPAuthenticationAlertController {

    public typealias AuthenticationHandler = (NSURLSessionAuthChallengeDisposition, NSURLCredential?) -> Void

    private static var onGoingChallenges = [NSURLProtectionSpace: [AuthenticationHandler]]()

    static public func presentWithChallenge(challenge: NSURLAuthenticationChallenge, handler: AuthenticationHandler) {
        if var handlers = onGoingChallenges[challenge.protectionSpace] {
            handlers.append(handler)
            onGoingChallenges[challenge.protectionSpace] = handlers
            return
        }
        onGoingChallenges[challenge.protectionSpace] = [handler]

        let  controller: UIAlertController
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            controller = controllerForServerTrustChallenge(challenge)
        } else {
            controller = controllerForUserAuthenticationChallenge(challenge)
        }

        controller.presentFromRootViewController()
    }

    static func executeHandlerForChallenge(challenge: NSURLAuthenticationChallenge, disposition: NSURLSessionAuthChallengeDisposition, credential: NSURLCredential?) {
        guard let handlers = onGoingChallenges[challenge.protectionSpace] else {
            return
        }
        for handler in handlers {
            handler(disposition, credential)
        }
        onGoingChallenges.removeValueForKey(challenge.protectionSpace)
    }

    static private func controllerForServerTrustChallenge(challenge: NSURLAuthenticationChallenge) -> UIAlertController {
        let title = NSLocalizedString("Certificate error", comment:"Popup title for wrong SSL certificate.")
        let message = String(format: NSLocalizedString("The certificate for this server is invalid. You might be connecting to a server that is pretending to be “%@” which could put your confidential information at risk.\n\nWould you like to trust the certificate anyway?", comment: ""), challenge.protectionSpace.host)
        let controller =  UIAlertController(title:title, message:message, preferredStyle:UIAlertControllerStyle.Alert)

        let cancelAction = UIAlertAction(title:NSLocalizedString("Cancel", comment:"Cancel button label"),
                                         style:UIAlertActionStyle.Default,
                                         handler:{ (action) in
                                            executeHandlerForChallenge(challenge, disposition: .CancelAuthenticationChallenge, credential: nil)
        })
        controller.addAction(cancelAction)

        let trustAction = UIAlertAction(title:NSLocalizedString("Trust", comment:"Connect when the SSL certificate is invalid"),
                                        style:UIAlertActionStyle.Default,
                                        handler:{ (action) in
                                            let credential = NSURLCredential(forTrust: challenge.protectionSpace.serverTrust!)
                                            NSURLCredentialStorage.sharedCredentialStorage().setDefaultCredential(credential, forProtectionSpace:challenge.protectionSpace)
                                            executeHandlerForChallenge(challenge, disposition: .UseCredential, credential: credential)
        })
        controller.addAction(trustAction)
        return controller
    }

    static private func controllerForUserAuthenticationChallenge(challenge: NSURLAuthenticationChallenge) -> UIAlertController {
        let title = String(format: NSLocalizedString("Authentication required for host: %@", comment: "Popup title to ask for user credentials."), challenge.protectionSpace.host)
        let message = NSLocalizedString("Please enter your credentials", comment: "Popup message to ask for user credentials (fields shown below).")
        let controller =  UIAlertController(title: title,
                                            message: message,
                                            preferredStyle: UIAlertControllerStyle.Alert)

        controller.addTextFieldWithConfigurationHandler( { (textField) in
            textField.placeholder = NSLocalizedString("Username", comment: "Login dialog username placeholder")
        })

        controller.addTextFieldWithConfigurationHandler({ (textField) in
            textField.placeholder = NSLocalizedString("Password", comment: "Login dialog password placeholder")
            textField.secureTextEntry = true
        })

        let cancelAction = UIAlertAction(title:NSLocalizedString("Cancel", comment: "Cancel button label"),
                                         style: .Default,
                                         handler:{ (action) in
                                            executeHandlerForChallenge(challenge, disposition: .CancelAuthenticationChallenge, credential: nil)
        })
        controller.addAction(cancelAction)

        let loginAction = UIAlertAction(title: NSLocalizedString("Log In", comment:"Log In button label."),
                                        style: .Default,
                                        handler:{(action) in
                                            guard let username = controller.textFields?.first?.text,
                                                let password = controller.textFields?.last?.text else {
                                                    executeHandlerForChallenge(challenge, disposition: .CancelAuthenticationChallenge, credential: nil)
                                                    return
                                            }
                                            let credential = NSURLCredential(user: username, password: password, persistence:NSURLCredentialPersistence.Permanent)
                                            NSURLCredentialStorage.sharedCredentialStorage().setDefaultCredential(credential, forProtectionSpace: challenge.protectionSpace)
                                            executeHandlerForChallenge(challenge, disposition: .UseCredential, credential: credential)
        })
        controller.addAction(loginAction)
        return controller
    }

}
