import UserNotifications
import OneSignalExtension

final class NotificationService: UNNotificationServiceExtension {
  private var contentHandler: ((UNNotificationContent) -> Void)?
  private var bestAttemptContent: UNMutableNotificationContent?
  private var notificationRequest: UNNotificationRequest?

  override func didReceive(
    _ request: UNNotificationRequest,
    withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
  ) {
    notificationRequest = request
    self.contentHandler = contentHandler
    bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

    guard let mutableContent = bestAttemptContent else {
      contentHandler(request.content)
      return
    }

    self.bestAttemptContent = OneSignalExtension.didReceiveNotificationExtensionRequest(
      request,
      with: mutableContent,
      withContentHandler: contentHandler
    )
  }

  override func serviceExtensionTimeWillExpire() {
    guard let contentHandler,
      let mutableContent = bestAttemptContent,
      let notificationRequest
    else {
      return
    }

    let content = OneSignalExtension.serviceExtensionTimeWillExpireRequest(
      notificationRequest,
      with: mutableContent
    )
    contentHandler(content ?? mutableContent)
  }
}
