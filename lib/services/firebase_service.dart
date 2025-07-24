import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../firebase_options.dart';
import 'api_service.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final ApiService _apiService = ApiService();
  
  String? _fcmToken;
  bool _isInitialized = false;
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
  late AndroidNotificationChannel channel;
  bool _localNotificationsInitialized = false;

  /// Initialize Firebase Services (Firebase Core should already be initialized)
  Future<void> initialize() async {
    try {
      debugPrint('🔥🔥🔥 [FCM] Starting Firebase Service initialization...');
      
      if (_isInitialized) {
        debugPrint('🔥 [FCM] Firebase Service already initialized');
        return;
      }

      // Firebase Core should already be initialized from main.dart
      if (Firebase.apps.isEmpty) {
        debugPrint('❌ [FCM] ERROR: Firebase Core not initialized in main.dart!');
        throw Exception('Firebase Core must be initialized in main.dart before FirebaseService');
      } else {
        debugPrint('✅ [FCM] Firebase Core already initialized from main.dart');
      }

      debugPrint('🔥 [FCM] Setting up Flutter local notifications...');
      await _setupFlutterNotifications();
      debugPrint('🔥 [FCM] Flutter local notifications setup complete');

      debugPrint('🔥 [FCM] Requesting notification permissions...');
      await _requestPermissions();
      debugPrint('🔥 [FCM] Permission request complete');

      debugPrint('🔥 [FCM] Getting FCM token...');
      await _getFCMToken();
      debugPrint('🔥 [FCM] FCM token retrieval complete');

      debugPrint('🔥 [FCM] Setting up message handlers...');
      _setupMessageHandlers();
      debugPrint('🔥 [FCM] Message handlers setup complete');

      // Listen for token refresh and register immediately
      _messaging.onTokenRefresh.listen((token) {
        debugPrint('🔄 [FCM] FCM Token refreshed: ${token.substring(0, 20)}...');
        _fcmToken = token;
        _registerTokenWithBackend(token);
      });

      _isInitialized = true;
      debugPrint('✅✅✅ [FCM] Firebase Service initialized successfully');
    } catch (e) {
      debugPrint('❌❌❌ [FCM] Error initializing Firebase Service: $e');
      debugPrint('❌ [FCM] Stack trace: ${StackTrace.current}');
    }
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    try {
      debugPrint('📱 [FCM] Requesting notification permissions...');
      
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('📱 [FCM] Permission status: ${settings.authorizationStatus}');
      debugPrint('📱 [FCM] Alert enabled: ${settings.alert}');
      debugPrint('📱 [FCM] Badge enabled: ${settings.badge}');
      debugPrint('📱 [FCM] Sound enabled: ${settings.sound}');
      
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('✅ [FCM] User granted notification permissions');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint('✅ [FCM] User granted provisional notification permissions');
      } else {
        debugPrint('❌ [FCM] User declined or has not accepted notification permissions');
      }
    } catch (e) {
      debugPrint('❌ [FCM] Error requesting permissions: $e');
    }
  }

  /// Get FCM token from device and register with backend
  Future<void> _getFCMToken() async {
    try {
      debugPrint('🔑 [FCM] Getting FCM token...');
      
      _fcmToken = await _messaging.getToken();
      
      if (_fcmToken != null) {
        debugPrint('🔑🔑🔑 [FCM] FCM Token obtained: ${_fcmToken!.substring(0, 50)}...');
        debugPrint('🔑 [FCM] Full token length: ${_fcmToken!.length} characters');
        
        // Store token locally
        await _storage.write(key: 'fcm_token', value: _fcmToken!);
        debugPrint('🔑 [FCM] Token stored locally');
        
        // Register with backend immediately if we have a valid token
        debugPrint('🔑 [FCM] Attempting to register token with backend...');
        await _registerTokenWithBackend(_fcmToken!);
      } else {
        debugPrint('❌ [FCM] Failed to get FCM token - token is null');
        // Try again after a delay
        debugPrint('🔑 [FCM] Retrying token retrieval in 2 seconds...');
        Future.delayed(const Duration(seconds: 2), () async {
          final retryToken = await _messaging.getToken();
          if (retryToken != null) {
            debugPrint('🔑 [FCM] Token obtained on retry: ${retryToken.substring(0, 20)}...');
            _fcmToken = retryToken;
            await _storage.write(key: 'fcm_token', value: retryToken);
            await _registerTokenWithBackend(retryToken);
          }
        });
      }
    } catch (e) {
      debugPrint('❌ [FCM] Error getting FCM token: $e');
      debugPrint('❌ [FCM] Stack trace: ${StackTrace.current}');
    }
  }

  /// Setup message handlers for foreground and background
  void _setupMessageHandlers() {
    debugPrint('📨 [FCM] Setting up message handlers...');

    // Handle messages when app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📨📨📨 [FCM] Foreground notification received');
      debugPrint('📨 [FCM] Message ID: ${message.messageId}');
      debugPrint('📨 [FCM] Title: ${message.notification?.title}');
      debugPrint('📨 [FCM] Body: ${message.notification?.body}');
      debugPrint('📨 [FCM] Data: ${message.data}');
      debugPrint('📨 [FCM] From: ${message.from}');
      
      // Show local notification or update UI
      _handleForegroundMessage(message);
    });

    // Handle notification taps when app is in background/terminated
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('📨 [FCM] Notification tapped - app opened from background');
      debugPrint('📨 [FCM] Title: ${message.notification?.title}');
      debugPrint('📨 [FCM] Data: ${message.data}');
      
      // Handle navigation based on notification data
      _handleNotificationTap(message);
    });

    // Check if app was opened from a notification when terminated
    _messaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint('📨 [FCM] App opened from terminated state via notification');
        debugPrint('📨 [FCM] Title: ${message.notification?.title}');
        debugPrint('📨 [FCM] Data: ${message.data}');
        
        // Handle navigation
        _handleNotificationTap(message);
      } else {
        debugPrint('📨 [FCM] No initial message found');
      }
    });

    debugPrint('📨 [FCM] Message handlers setup complete');
  }

  /// Handle foreground notifications
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('🔔🔔🔔 [FCM] Handling foreground notification');
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;
    
    debugPrint('🔔 [FCM] Notification object: $notification');
    debugPrint('🔔 [FCM] Android notification: $android');
    
    if (notification != null) {
      debugPrint('🔔 [FCM] Showing local notification...');
      debugPrint('🔔 [FCM] Title: ${notification.title}');
      debugPrint('🔔 [FCM] Body: ${notification.body}');
      
      try {
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id, // Use the new high-importance channel
              channel.name,
              channelDescription: channel.description,
              icon: '@mipmap/ic_launcher', // Use mipmap path, not drawable
              importance: Importance.max,
              priority: Priority.high,
              showWhen: true,
              enableVibration: true,
              enableLights: true,
              playSound: true,
              ticker: notification.title,
              autoCancel: true,
              ongoing: false,
            ),
          ),
        ).then((_) {
          debugPrint('✅ [FCM] Local notification display completed successfully');
          debugPrint('🔔 [FCM] Notification details: title="${notification.title}", body="${notification.body}", channel="${channel.id}"');
        }).catchError((error) {
          debugPrint('❌ [FCM] Local notification display failed: $error');
        });
        debugPrint('🔔 [FCM] Local notification show() called');
      } catch (e) {
        debugPrint('❌ [FCM] Exception showing local notification: $e');
      }
    } else {
      debugPrint('🔔 [FCM] Cannot show notification - notification is null');
    }
  }

  /// Handle notification tap navigation
  void _handleNotificationTap(RemoteMessage message) {
    // Extract navigation data from message
    final data = message.data;
    debugPrint('🎯 [FCM] Handling notification tap with data: $data');
    
    if (data.containsKey('taskId') || data.containsKey('taskGuid')) {
      // Navigate to specific task
      final taskId = data['taskId'] ?? data['taskGuid'];
      debugPrint('🎯 [FCM] Navigating to task: $taskId');
      // TODO: Implement navigation to task details
    } else if (data.containsKey('projectId') || data.containsKey('projectGuid')) {
      // Navigate to specific project
      final projectId = data['projectId'] ?? data['projectGuid'];
      debugPrint('🎯 [FCM] Navigating to project: $projectId');
      // TODO: Implement navigation to project details
    }
  }

  /// Setup Flutter local notifications
  Future<void> _setupFlutterNotifications() async {
    try {
      debugPrint('🔔 [FCM] Setting up Flutter local notifications...');
      if (_localNotificationsInitialized) {
        debugPrint('🔔 [FCM] Local notifications already initialized');
        return;
      }
      
      // Create HIGH IMPORTANCE channel with NEW ID
      channel = AndroidNotificationChannel(
        'task_updates_v2', // NEW ID to reset importance
        'Task Updates',
        description: 'Notifies assignees when they get a task',
        importance: Importance.max, // HIGH IMPORTANCE
        enableLights: true,
        enableVibration: true,
        playSound: true,
      );
      debugPrint('🔔 [FCM] High importance notification channel created: ${channel.id}');
      
      flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      debugPrint('🔔 [FCM] FlutterLocalNotificationsPlugin initialized');
      
      // Get Android implementation and create channel BEFORE initializing plugin
      final androidImplementation = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidImplementation != null) {
        // Create notification channel FIRST
        await androidImplementation.createNotificationChannel(channel);
        debugPrint('🔔 [FCM] Android notification channel created BEFORE plugin init');
        
        // Check if notifications are enabled
        final bool? areNotificationsEnabled = await androidImplementation.areNotificationsEnabled();
        debugPrint('🔔 [FCM] Are notifications enabled: $areNotificationsEnabled');
        
        if (areNotificationsEnabled == false) {
          debugPrint('⚠️ [FCM] Notifications are disabled at OS level - requesting permission...');
          final bool? permissionGranted = await androidImplementation.requestNotificationsPermission();
          debugPrint('🔔 [FCM] Permission request result: $permissionGranted');
        }
      }
      
      // THEN initialize the plugin with platform specific settings
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);
      
      await flutterLocalNotificationsPlugin.initialize(initializationSettings);
      debugPrint('🔔 [FCM] Notification plugin initialized with settings AFTER channel creation');
      
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('🔔 [FCM] Foreground notification presentation options set');
      
      _localNotificationsInitialized = true;
      debugPrint('🔔 [FCM] Local notifications setup complete');
    } catch (e) {
      debugPrint('❌ [FCM] Error setting up local notifications: $e');
      debugPrint('❌ [FCM] Stack trace: ${StackTrace.current}');
    }
  }

  /// Register FCM token with backend (public method called after login)
  Future<bool> registerTokenWithBackend() async {
    try {
      debugPrint('📤 [FCM] Public registerTokenWithBackend called');
      
      // Wait for token if not available yet
      if (_fcmToken == null) {
        debugPrint('📤 [FCM] No token available, waiting for FCM token...');
        _fcmToken = await _messaging.getToken();
      }
      
      if (_fcmToken == null) {
        debugPrint('❌ [FCM] Still no FCM token available for registration');
        return false;
      }

      return await _registerTokenWithBackend(_fcmToken!);
    } catch (e) {
      debugPrint('❌ [FCM] Error registering token with backend: $e');
      return false;
    }
  }

  /// Internal method to register token with backend
  Future<bool> _registerTokenWithBackend(String token) async {
    try {
      debugPrint('📤📤📤 [FCM] Registering FCM token with backend...');
      debugPrint('📤 [FCM] Token (first 50 chars): ${token.substring(0, 50)}...');
      
      // Get device info
      final deviceInfo = await _getDeviceInfo();
      debugPrint('�� [FCM] Device info: $deviceInfo');
      
      // Prepare request data
      final requestData = {
        'token': token,
        'deviceType': Platform.isAndroid ? 'android' : 'ios',
        'userAgent': 'AlbaniApp/${deviceInfo['version'] ?? '1.0'}',
      };

      debugPrint('📤 [FCM] Request data: $requestData');

      // Make API call
      debugPrint('📤 [FCM] Making API call to register token...');
      await _apiService.post('api/EmployeeClients/RegisterToken', requestData);
      
      debugPrint('✅✅✅ [FCM] FCM token registered successfully with backend');
      
      // Store registration timestamp
      await _storage.write(
        key: 'fcm_token_registered_at', 
        value: DateTime.now().toIso8601String(),
      );
      
      return true;
    } catch (e) {
      debugPrint('❌❌❌ [FCM] Failed to register FCM token with backend: $e');
      debugPrint('❌ [FCM] Stack trace: ${StackTrace.current}');
      return false;
    }
  }

  /// Get device information
  Future<Map<String, String>> _getDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    
    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return {
          'platform': 'Android',
          'model': androidInfo.model,
          'version': androidInfo.version.release,
          'manufacturer': androidInfo.manufacturer,
        };
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return {
          'platform': 'iOS',
          'model': iosInfo.model,
          'version': iosInfo.systemVersion,
          'manufacturer': 'Apple',
        };
      }
    } catch (e) {
      debugPrint('❌ [FCM] Error getting device info: $e');
    }
    
    return {
      'platform': Platform.operatingSystem,
      'model': 'Unknown',
      'version': '1.0',
      'manufacturer': 'Unknown',
    };
  }

  /// Get current FCM token
  String? get fcmToken => _fcmToken;

  /// Check if Firebase is initialized
  bool get isInitialized => _isInitialized;

  /// Unregister token (call on logout only)
  Future<void> unregisterToken() async {
    try {
      debugPrint('🔄 [FCM] Unregistering FCM token on logout...');
      
      // Clear local storage
      await _storage.delete(key: 'fcm_token');
      await _storage.delete(key: 'fcm_token_registered_at');
      
      // TODO: Call backend to remove token if endpoint exists
      
      _fcmToken = null;
      debugPrint('✅ [FCM] FCM token unregistered');
    } catch (e) {
      debugPrint('❌ [FCM] Error unregistering FCM token: $e');
    }
  }

  /// Handle background messages (called from background handler)
  static Future<void> handleBackgroundMessage(RemoteMessage message) async {
    try {
      debugPrint('📨📨📨 [FCM] Background message handler called');
      debugPrint('📨 [FCM] Title: ${message.notification?.title}');
      debugPrint('📨 [FCM] Body: ${message.notification?.body}');

      if (message.notification != null) {
        final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

        // Initialize plugin for background use
        const AndroidInitializationSettings initializationSettingsAndroid =
            AndroidInitializationSettings('@mipmap/ic_launcher');
        const InitializationSettings initializationSettings =
            InitializationSettings(android: initializationSettingsAndroid);

        await flutterLocalNotificationsPlugin.initialize(initializationSettings);

        // Create and register the HIGH IMPORTANCE channel
        final AndroidNotificationChannel channel = AndroidNotificationChannel(
          'task_updates_v2', // Same NEW ID
          'Task Updates',
          description: 'Notifies assignees when they get a task',
          importance: Importance.max,
          enableLights: true,
          enableVibration: true,
          playSound: true,
        );

        final androidImplementation = flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

        if (androidImplementation != null) {
          await androidImplementation.createNotificationChannel(channel);
        }

        // Show notification with proper icon
        await flutterLocalNotificationsPlugin.show(
          message.notification.hashCode,
          message.notification?.title,
          message.notification?.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'task_updates_v2', // Same channel ID
              'Task Updates',
              channelDescription: 'Notifies assignees when they get a task',
              icon: '@mipmap/ic_launcher', // Use mipmap path, not drawable
              importance: Importance.max,
              priority: Priority.high,
              showWhen: true,
              enableVibration: true,
              enableLights: true,
              playSound: true,
              autoCancel: true,
              ongoing: false,
            ),
          ),
        );

        debugPrint('📨 [FCM] Background notification displayed');
      }
    } catch (e) {
      debugPrint('❌ [FCM] Error in background message handler: $e');
    }
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('📨📨📨 [FCM] Background notification received: ${message.notification?.title}');
  debugPrint('📨 [FCM] Background message ID: ${message.messageId}');
  debugPrint('📨 [FCM] Background data: ${message.data}');
  
  // Handle background notification using the service method
  await FirebaseService.handleBackgroundMessage(message);
} 