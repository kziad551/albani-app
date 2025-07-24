# 📱 Mobile Firebase Push Notification Setup Guide

## 1. Firebase Project Information

- **Project Name:** Albania Engineer (or your actual Firebase project name)
- **Project ID:** `albania-engineer-d6b32`
- **Web API Key:** `AIzaSyC7rWoM2MmUHRWyVtqzBbqaUGVlyPPom8k`
- **Messaging Sender ID:** `289341419891`
- **App ID:** `1:289341419891:web:1b9cbe1a74bafc42391506`
- **Database URL:** `https://albania-engineer-d6b32-default-rtdb.firebaseio.com`
- **Storage Bucket:** `albania-engineer-d6b32.appspot.com`

---

## 2. Firebase Console Setup

- Go to [Firebase Console](https://console.firebase.google.com/).
- Select the project: **albania-engineer-d6b32**.
- Add your Android and iOS apps if not already added.
- Download the following files:
  - **Android:** `google-services.json`
  - **iOS:** `GoogleService-Info.plist`

---

## 3. API Endpoints for Push Notification Registration

- **Register FCM Token:**  
  `POST /api/EmployeeClients/RegisterToken`
  ```json
  {
    "token": "<FCM_TOKEN>",
    "deviceType": "mobile",
    "userAgent": "<user-agent-string>"
  }
  ```
- **(Optional) Get User Info:**  
  `GET /api/Employees/info`

---

## 4. FCM VAPID Key (Web Only, for reference)

- **VAPID Key (Web):**  
  `BGeTOFV8Kd2_Fm0cSvOwK4-8FiU3ZcVlDynkotCbyM4BAieIbzXnGw8ER4ctvdB8PzKCDLtOH6z5mncIcxjfNlQ`
- *Not needed for mobile, but included for completeness.*

---

## 5. Firebase Service Account (for Server, not mobile)

- **Service Account JSON:**  
  `project_manager.Server/Infrastructure/Files/albania-engineer-d6b32-firebase-adminsdk.json`
- *Not needed for mobile, but if you need to send messages from your own backend, use this file.*

---

## 6. Flutter Firebase Setup Checklist

- Add `firebase_core`, `firebase_messaging`, and (optionally) `flutter_local_notifications` to `pubspec.yaml`.
- Place `google-services.json` in `android/app/`.
- Place `GoogleService-Info.plist` in `ios/Runner/`.
- Initialize Firebase in your `main.dart`:
  ```dart
  await Firebase.initializeApp();
  ```
- Request notification permissions on iOS and Android.
- Listen for FCM token and register it with your backend using the API above.
- Handle foreground/background push notifications.

---

## 7. Credentials and IDs Summary

| Key/ID                | Value                                                      |
|-----------------------|------------------------------------------------------------|
| Project ID            | albania-engineer-d6b32                                     |
| Web API Key           | AIzaSyC7rWoM2MmUHRWyVtqzBbqaUGVlyPPom8k                    |
| Messaging Sender ID   | 289341419891                                               |
| App ID                | 1:289341419891:web:1b9cbe1a74bafc42391506                  |
| Database URL          | https://albania-engineer-d6b32-default-rtdb.firebaseio.com |
| Storage Bucket        | albania-engineer-d6b32.appspot.com                         |
| VAPID Key (Web Only)  | BGeTOFV8Kd2_Fm0cSvOwK4-8FiU3ZcVlDynkotCbyM4BAieIbzXnGw8ER4ctvdB8PzKCDLtOH6z5mncIcxjfNlQ |

---

## 8. What the Mobile Developer Needs to Do

1. Add the app to Firebase Console (if not already).
2. Download and add `google-services.json` (Android) and `GoogleService-Info.plist` (iOS).
3. Add the required Flutter packages.
4. Initialize Firebase in the app.
5. Request notification permissions.
6. Listen for and handle FCM token.
7. Register the token with the backend using the provided API.
8. Handle push notifications in foreground/background.

---

## 9. Extra Notes

- The backend expects the FCM token to be registered via `/api/EmployeeClients/RegisterToken`.
- The backend will send push notifications to the registered tokens when a user is assigned to a task.
- If you need to test, you can use the same credentials as the web app.

---

**Give this file to your mobile developer. They will have everything needed to set up Firebase push notifications and integrate with your backend.** 