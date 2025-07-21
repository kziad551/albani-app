# 📱 Cursor Mobile Development Prompt

## 🎯 **Task: Integrate Firebase Push Notifications**

I need you to add Firebase Cloud Messaging (FCM) push notifications to our mobile app. The backend is **100% ready** and working with Firebase project `albania-engineer-d6b32`.

## 🔥 **What You Need to Do:**

1. **Add Firebase SDK** to the mobile project
2. **Download config files** from Firebase Console (google-services.json / GoogleService-Info.plist)
3. **Get FCM token** from device after user login
4. **Register token** with backend API: `POST /api/EmployeeClients/RegisterToken`
5. **Handle notifications** (foreground/background)

## 📋 **Required API Call After Login:**
```typescript
// After successful login, call this:
POST /api/EmployeeClients/RegisterToken
Authorization: Bearer [ACCESS_TOKEN]
{
  "token": "FCM_TOKEN_FROM_DEVICE",
  "deviceType": "android" | "ios", 
  "userAgent": "AlbaniApp/1.0"
}
```

## 🚀 **Backend is Ready:**
- ✅ Firebase project: `albania-engineer-d6b32`
- ✅ Notification triggers: Task assignments, comments, mentions
- ✅ FCM token storage and management
- ✅ Automatic notification sending

## 📁 **Firebase Config:**
- **Project ID**: `albania-engineer-d6b32`
- **Sender ID**: `289341419891`
- **Console**: https://console.firebase.google.com/project/albania-engineer-d6b32

## ✨ **Expected Result:**
Users receive push notifications when:
- Assigned to tasks
- Mentioned in comments (@username)
- Someone replies to their comments
- New comments on their tasks

**The backend handles everything automatically once you register the FCM token!** 🎉

---

**Files to reference:** 
- `MOBILE_NOTIFICATION_INTEGRATION.md` (detailed implementation guide)
- Backend API endpoints are ready and tested 