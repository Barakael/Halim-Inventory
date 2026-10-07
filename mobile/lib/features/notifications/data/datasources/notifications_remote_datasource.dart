import '../models/notification_model.dart';

/// Backend has no notifications API; stub returns empty data.
class NotificationsRemoteDataSource {
  const NotificationsRemoteDataSource();

  Future<List<NotificationModel>> getNotifications() async => [];

  Future<void> markAsRead(String id) async {}

  Future<void> markAllAsRead() async {}

  Future<void> deleteNotification(String id) async {}
}
