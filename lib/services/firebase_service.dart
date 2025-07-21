import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:device_info_plus/device_info_plus.dart';
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

  /// Initialize Firebase and FCM
  Future<void> initialize() async {
    try {
      debugPrint('🔥 Initializing Firebase Service...');
      
      if (_isInitialized) {
        debugPrint('Firebase already initialized');
        return;
      }

      // Initialize Firebase if not already done
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        debugPrint('🔥 Firebase Core initialized');
      }

      // Request notification permissions
      await _requestPermissions();

      // Get FCM token
      await _getFCMToken();

      // Setup message handlers
      _setupMessageHandlers();

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((token) {
        debugPrint('🔄 FCM Token refreshed: ${token.substring(0, 20)}...');
        _fcmToken = token;
        _registerTokenWithBackend(token);
      });

      _isInitialized = true;
      debugPrint('✅ Firebase Service initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing Firebase Service: $e');
    }
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    try {
      debugPrint('📱 Requesting notification permissions...');
      
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('📱 Permission status: ${settings.authorizationStatus}');
      
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('✅ User granted notification permissions');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint('✅ User granted provisional notification permissions');
      } else {
        debugPrint('❌ User declined or has not accepted notification permissions');
      }
    } catch (e) {
      debugPrint('❌ Error requesting permissions: $e');
    }
  }

  /// Get FCM token from device
  Future<void> _getFCMToken() async {
    try {
      debugPrint('🔑 Getting FCM token...');
      
      _fcmToken = await _messaging.getToken();
      
      if (_fcmToken != null) {
        debugPrint('🔑 FCM Token obtained: ${_fcmToken!.substring(0, 20)}...');
        
        // Store token locally
        await _storage.write(key: 'fcm_token', value: _fcmToken!);
      } else {
        debugPrint('❌ Failed to get FCM token');
      }
    } catch (e) {
      debugPrint('❌ Error getting FCM token: $e');
    }
  }

  /// Setup message handlers for foreground and background
  void _setupMessageHandlers() {
    debugPrint('📨 Setting up message handlers...');

    // Handle messages when app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📨 Foreground notification received');
      debugPrint('Title: ${message.notification?.title}');
      debugPrint('Body: ${message.notification?.body}');
      debugPrint('Data: ${message.data}');
      
      // Show local notification or update UI
      _handleForegroundMessage(message);
    });

    // Handle notification taps when app is in background/terminated
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('📨 Notification tapped - app opened from background');
      debugPrint('Title: ${message.notification?.title}');
      debugPrint('Data: ${message.data}');
      
      // Handle navigation based on notification data
      _handleNotificationTap(message);
    });

    // Check if app was opened from a notification when terminated
    _messaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint('📨 App opened from terminated state via notification');
        debugPrint('Title: ${message.notification?.title}');
        debugPrint('Data: ${message.data}');
        
        // Handle navigation
        _handleNotificationTap(message);
      }
    });
  }

  /// Handle foreground notifications
  void _handleForegroundMessage(RemoteMessage message) {
    // You can show a local notification, snackbar, or update UI
    // For now, just log the message
    debugPrint('🔔 Handling foreground notification: ${message.notification?.title}');
  }

  /// Handle notification tap navigation
  void _handleNotificationTap(RemoteMessage message) {
    // Extract navigation data from message
    final data = message.data;
    
    if (data.containsKey('taskId') || data.containsKey('taskGuid')) {
      // Navigate to specific task
      final taskId = data['taskId'] ?? data['taskGuid'];
      debugPrint('🎯 Navigating to task: $taskId');
      // TODO: Implement navigation to task details
    } else if (data.containsKey('projectId') || data.containsKey('projectGuid')) {
      // Navigate to specific project
      final projectId = data['projectId'] ?? data['projectGuid'];
      debugPrint('🎯 Navigating to project: $projectId');
      // TODO: Implement navigation to project details
    }
  }

  /// Register FCM token with backend after login
  Future<bool> registerTokenWithBackend() async {
    try {
      if (_fcmToken == null) {
        debugPrint('❌ No FCM token available for registration');
        return false;
      }

      return await _registerTokenWithBackend(_fcmToken!);
    } catch (e) {
      debugPrint('❌ Error registering token with backend: $e');
      return false;
    }
  }

  /// Internal method to register token with backend
  Future<bool> _registerTokenWithBackend(String token) async {
    try {
      debugPrint('📤 Registering FCM token with backend...');
      
      // Get device info
      final deviceInfo = await _getDeviceInfo();
      
      // Prepare request data
      final requestData = {
        'token': token,
        'deviceType': Platform.isAndroid ? 'android' : 'ios',
        'userAgent': 'AlbaniApp/${deviceInfo['version'] ?? '1.0'}',
      };

      debugPrint('📤 Request data: $requestData');

      // Make API call
      await _apiService.post('api/EmployeeClients/RegisterToken', requestData);
      
      debugPrint('✅ FCM token registered successfully with backend');
      
      // Store registration timestamp
      await _storage.write(
        key: 'fcm_token_registered_at', 
        value: DateTime.now().toIso8601String(),
      );
      
      return true;
    } catch (e) {
      debugPrint('❌ Failed to register FCM token with backend: $e');
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
      debugPrint('❌ Error getting device info: $e');
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

  /// Unregister token (call on logout)
  Future<void> unregisterToken() async {
    try {
      debugPrint('🔄 Unregistering FCM token...');
      
      // Clear local storage
      await _storage.delete(key: 'fcm_token');
      await _storage.delete(key: 'fcm_token_registered_at');
      
      // TODO: Call backend to remove token if endpoint exists
      
      _fcmToken = null;
      debugPrint('✅ FCM token unregistered');
    } catch (e) {
      debugPrint('❌ Error unregistering FCM token: $e');
    }
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('📨 Background notification received: ${message.notification?.title}');
  
  // Handle background notification
  // Note: You can't update UI here, only perform background tasks
} 