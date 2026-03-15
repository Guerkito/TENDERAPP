import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Manejar clic en la notificación si es necesario
      },
    );
  }

  Future<void> showLowStockAlert(String productName, double currentStock) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'stock_alerts_channel',
      'Alertas de Stock',
      channelDescription: 'Notificaciones para productos con stock bajo',
      importance: Importance.high,
      priority: Priority.high,
      color: Color(0xFFFF0000),
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: DarwinNotificationDetails(),
    );

    await _notificationsPlugin.show(
      0,
      '¡Stock Bajo!',
      'El producto $productName se está agotando (Quedan: $currentStock)',
      platformChannelSpecifics,
    );
  }

  Future<void> showExpiryAlert(String productName, String expiryDate) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'expiry_alerts_channel',
      'Alertas de Vencimiento',
      channelDescription: 'Notificaciones para productos próximos a vencer',
      importance: Importance.high,
      priority: Priority.high,
      color: Color(0xFFFF9800),
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: DarwinNotificationDetails(),
    );

    await _notificationsPlugin.show(
      1,
      '¡Producto por Vencer!',
      'El producto $productName vence pronto: $expiryDate',
      platformChannelSpecifics,
    );
  }
}
