import UIKit

final class FabushiAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        IOSBackgroundTransferService.shared.handleEvents(
            forBackgroundURLSession: identifier,
            completionHandler: completionHandler
        )
    }
}
