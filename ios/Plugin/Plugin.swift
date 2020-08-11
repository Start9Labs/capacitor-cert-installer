import Foundation
import Capacitor
import Swifter

class ConfigServer: NSObject {

    //TODO: Don't foget to add your custom app url scheme to info.plist if you have one!

    private enum ConfigState: Int
    {
        case Stopped, Ready, InstalledConfig, BackToApp
    }

    internal let listeningPort: in_port_t! = 8080
    internal var configName: String! = "Profile install"
    private var localServer: HttpServer!
    private var configData: Data!

    private var serverState: ConfigState = .Stopped
    private var startTime: NSDate!
    private var registeredForNotifications = false
    private var backgroundTask = UIBackgroundTaskIdentifier.invalid

    deinit
    {
        unregisterFromNotifications()
    }

    init(configData: Data)
    {
        super.init()
        self.configData = configData
        localServer = HttpServer()
        self.setupHandlers()
    }

    //MARK:- Control functions

    internal func start() -> Error?
    {
        let page = self.baseURL(pathComponent: "start/")
        let url: URL = URL(string: page)!
        if UIApplication.shared.canOpenURL(url) {
            var err: Error? = nil
            do {
                try localServer.start(listeningPort)
            } catch {
                err = error
            }
            if err == nil {
                startTime = NSDate()
                serverState = .Ready
                registerForNotifications()
                UIApplication.shared.open(url)
                return nil
            } else {
                self.stop()
                return err
            }
        }
        return URLError(.badURL)
    }

    internal func stop()
    {
        if serverState != .Stopped {
            serverState = .Stopped
            unregisterFromNotifications()
        }
    }

    //MARK:- Private functions

    private func setupHandlers()
    {
        localServer["/start"] = { request in
            if self.serverState == .Ready {
                let page = self.basePage(pathComponent: "install/")
                return .ok(.html(page))
            } else {
                return .notFound
            }
        }
        localServer["/install"] = { request in
            switch self.serverState {
            case .Stopped:
                return .notFound
            case .Ready:
                self.serverState = .InstalledConfig
                return HttpResponse.raw(200, "OK", ["Content-Type": "application/x-x509-ca-cert"]) { writer in
                    try writer.write(self.configData)
                }
            case .InstalledConfig:
                return .ok(.html("<h1>GO TO SETTINGS</h1><br /><h2>General -> Profiles -> Downloaded Profile -> Install (x3)</h2><br /><h2>General -> About -> Certificate Trust Settings -> Enable Full Trust for Root Certificates</h2><br /><br /><br /><h3>TODO: make this pretty, add screenshots</h3>")) // TODO
            case .BackToApp:
                let page = self.basePage(pathComponent: nil)
                return .ok(.html(page))
            }
        }
    }

    private func baseURL(pathComponent: String?) -> String
    {
        var page = "http://localhost:\(listeningPort!)"
        if let component = pathComponent {
            page += "/\(component)"
        }
        return page
    }

    private func basePage(pathComponent: String?) -> String
    {
        var page = "<!doctype html><html>" + "<head><meta charset='utf-8'><title>\(self.configName!)</title></head>"
        if let component = pathComponent {
            let script = "function load() { window.location.href='\(self.baseURL(pathComponent: component))'; }window.setInterval(load, 600);"
            page += "<script>\(script)</script>"
        }
        page += "<body></body></html>"
        return page
    }

    private func returnedToApp() {
        if serverState != .Stopped {
            serverState = .BackToApp
            localServer.stop()
        }
        // Do whatever else you need to to
    }

    private func registerForNotifications() {
        if !registeredForNotifications {
            let notificationCenter = NotificationCenter.default
            notificationCenter.addObserver(self, selector: #selector(ConfigServer.didEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
            notificationCenter.addObserver(self, selector: #selector(ConfigServer.willEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
            registeredForNotifications = true
        }
    }

    private func unregisterFromNotifications() {
        if registeredForNotifications {
            let notificationCenter = NotificationCenter.default
            notificationCenter.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
            notificationCenter.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
            registeredForNotifications = false
        }
    }

    
    @objc internal func didEnterBackground(notification: NSNotification) {
        if serverState != .Stopped {
            startBackgroundTask()
        }
    }

    @objc internal func willEnterForeground(notification: NSNotification) {
        if backgroundTask != UIBackgroundTaskIdentifier.invalid {
            stopBackgroundTask()
            returnedToApp()
        }
    }

    private func startBackgroundTask() {
        let application = UIApplication.shared
        backgroundTask = application.beginBackgroundTask() {
            DispatchQueue.main.async {
                self.stopBackgroundTask()
            }
        }
    }

    private func stopBackgroundTask() {
        if backgroundTask != UIBackgroundTaskIdentifier.invalid {
            UIApplication.shared.endBackgroundTask(self.backgroundTask)
            backgroundTask = UIBackgroundTaskIdentifier.invalid
        }
    }
}

/**
 * Please read the Capacitor iOS Plugin Development Guide
 * here: https://capacitorjs.com/docs/plugins/ios
 */
@objc(CertInstaller)
public class CertInstaller: CAPPlugin {
    
    var view: WKWebView?

    @objc func installCert(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            guard let value = call.getString("value") else {
                call.error("value required")
                return
            }
            let server = ConfigServer(configData: value.data(using: .utf8)!)
            let err = server.start()
            if err == nil {
                call.success()
            } else {
                call.error("\(err as Any)")
            }
            return
        }
    }
}
