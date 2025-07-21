# 📱 Mobile App Firebase Push Notifications Integration Guide

## 🎯 **Objective**
Integrate Firebase Cloud Messaging (FCM) push notifications into the mobile application to receive real-time notifications for task assignments, comments, and mentions.

## ✅ **Backend Status - READY**
The backend is **100% configured** and working with Firebase project `albania-engineer-d6b32`. All notification endpoints are functional and tested.

## 🔧 **Firebase Project Configuration**

### **Project Details:**
- **Project ID**: `albania-engineer-d6b32`
- **App ID**: `1:289341419891:web:1b9cbe1a74bafc42391506`
- **Sender ID**: `289341419891`
- **API Key**: `AIzaSyC7rWoM2MmUHRWyVtqzBbqaUGVlyPPom8k`

### **Firebase Console Access:**
- **URL**: https://console.firebase.google.com/project/albania-engineer-d6b32
- **Account**: kziad551@gmail.com (Albania Engineer project)

## 📋 **Required Mobile Implementation**

### **1. Firebase Configuration File**
You need to download the mobile configuration files from Firebase Console:

**For Android:** Download `google-services.json`
**For iOS:** Download `GoogleService-Info.plist`

**Steps:**
1. Go to Firebase Console → Project Settings → Your apps
2. Add Android/iOS app if not exists
3. Download the respective config file
4. Add to your mobile project

### **2. FCM Token Registration (CRITICAL)**
The mobile app MUST register its FCM token with the backend after user login.

**Endpoint:** `POST /api/EmployeeClients/RegisterToken`

**Required Request:**
```json
{
  "token": "FCM_TOKEN_FROM_MOBILE_DEVICE",
  "deviceType": "android" | "ios",
  "userAgent": "YourMobileApp/1.0"
}
```

**Implementation Flow:**
```
1. User logs in successfully
2. Get FCM token from Firebase
3. Send token to backend via API
4. Backend stores token for user
5. User receives notifications immediately
```

### **3. Backend API Integration**

**Authentication:** Bearer token (same as web app)
**Base URL:** `http://your-server.com/api/`

**Login Endpoint:**
```
POST /api/Employees/login
{
  "username": "string",
  "password": "string"
}
```

**Token Registration Endpoint:**
```
POST /api/EmployeeClients/RegisterToken
Authorization: Bearer YOUR_ACCESS_TOKEN
{
  "token": "string",
  "deviceType": "string", 
  "userAgent": "string"
}
```

## 🚀 **Notification Triggers (Already Working)**

The backend automatically sends notifications for:

1. **Task Assignment** - When user is assigned to a task
2. **Comment Mentions** - When user is mentioned in comments (@username)
3. **Comment Replies** - When someone replies to user's comment
4. **New Comments** - When comments are added to user's tasks

## 📱 **Mobile Code Implementation Examples**

### **React Native Example:**
```typescript
import messaging from '@react-native-firebase/messaging';
import axios from 'axios';

// Initialize Firebase messaging
const initializeFCM = async () => {
  // Request permission
  const authStatus = await messaging().requestPermission();
  
  if (authStatus === messaging.AuthorizationStatus.AUTHORIZED) {
    // Get FCM token
    const token = await messaging().getToken();
    
    // Register with backend
    await registerTokenWithBackend(token);
  }
};

// Register token with backend
const registerTokenWithBackend = async (token: string) => {
  try {
    await axios.post('/api/EmployeeClients/RegisterToken', {
      token: token,
      deviceType: Platform.OS,
      userAgent: `AlbaniApp/${DeviceInfo.getVersion()}`
    }, {
      headers: {
        'Authorization': `Bearer ${accessToken}`
      }
    });
    console.log('FCM token registered successfully');
  } catch (error) {
    console.error('Failed to register FCM token:', error);
  }
};

// Handle foreground notifications
messaging().onMessage(async remoteMessage => {
  console.log('Foreground notification:', remoteMessage);
  // Show local notification or update UI
});

// Handle background/quit state notifications
messaging().setBackgroundMessageHandler(async remoteMessage => {
  console.log('Background notification:', remoteMessage);
});
```

### **Flutter Example:**
```dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;

class FCMService {
  static Future<void> initialize() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    
    // Request permission
    NotificationSettings settings = await messaging.requestPermission();
    
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // Get FCM token
      String? token = await messaging.getToken();
      
      if (token != null) {
        await registerTokenWithBackend(token);
      }
    }
    
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Foreground notification: ${message.notification?.title}');
    });
  }
  
  static Future<void> registerTokenWithBackend(String token) async {
    try {
      final response = await http.post(
        Uri.parse('/api/EmployeeClients/RegisterToken'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: json.encode({
          'token': token,
          'deviceType': Platform.isAndroid ? 'android' : 'ios',
          'userAgent': 'AlbaniApp/1.0',
        }),
      );
      
      if (response.statusCode == 200) {
        print('FCM token registered successfully');
      }
    } catch (error) {
      print('Failed to register FCM token: $error');
    }
  }
}
```

## 🔍 **Testing & Verification**

### **1. Test Token Registration**
After implementing, check backend logs for:
```
📱 RegisterToken called for user: [user-id]
📝 Registering FCM token: [token] for user: [user-id]
✅ FCM token registered successfully for user: [user-id]
```

### **2. Test Notifications**
1. Login with mobile app
2. Assign a task to the logged-in user from web app
3. Mobile device should receive notification
4. Check backend logs for:
```
🚀 Task Assignment Notification - Task: [task-name]
📱 Found 1 FCM tokens for user: [username]
✅ Notification sent successfully to 1 devices
```

## ⚡ **Ready-to-Use Backend Features**

The backend already provides:
- ✅ User authentication
- ✅ FCM token storage and management
- ✅ Automatic notification sending
- ✅ Task management APIs
- ✅ Comment system with mentions
- ✅ File attachments
- ✅ Project and bucket management

## 🎯 **Mobile App Requirements**

**Minimum Implementation:**
1. Firebase SDK integration
2. FCM token retrieval
3. Token registration API call after login
4. Notification handling (foreground/background)

**Optional Enhancements:**
1. Local notification display
2. Notification click handling (deep linking)
3. Notification badges
4. Sound/vibration customization

## 🚨 **Important Notes**

1. **Token Registration is MANDATORY** - Without this, notifications won't work
2. **Call after login** - Always register token after successful authentication
3. **Handle token refresh** - FCM tokens can change, implement token refresh handling
4. **Test thoroughly** - Test on both foreground and background states

The backend is production-ready. You only need to implement the mobile FCM client! 🚀 