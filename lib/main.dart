
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'firebase_options.dart';
import 'screens/splash_screen.dart';

final FlutterLocalNotificationsPlugin localNotifications =
    FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel notificationChannel =
    AndroidNotificationChannel(
  'career_pilot_notifications',
  'CareerPilot Notifications',
  description: 'Study reminders and placement notifications',
  importance: Importance.high,
);

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

Future<void> initializeNotifications() async {
  const androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const initializationSettings = InitializationSettings(
    android: androidSettings,
  );

  await localNotifications.initialize(
    settings: initializationSettings,
  );

  final androidPlugin =
      localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  await androidPlugin?.createNotificationChannel(
    notificationChannel,
  );

  await androidPlugin?.requestNotificationsPermission();

  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    final notification = message.notification;

    if (notification == null) return;

    await localNotifications.show(
      id: message.hashCode,
      title: notification.title ?? 'CareerPilot AI',
      body: notification.body ?? 'You have a new notification.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'career_pilot_notifications',
          'CareerPilot Notifications',
          channelDescription:
              'Study reminders and placement notifications',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(
    firebaseMessagingBackgroundHandler,
  );

  await initializeNotifications();

  runApp(const AICareerMentorApp());
}

class AICareerMentorApp extends StatelessWidget {
  const AICareerMentorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AI Career Mentor',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      ),
      home: const SplashScreen(),
    );
  }
}
