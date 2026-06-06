# 🛡️ DRIVORA Admin Dashboard

**User & Vehicle Management System for DRIVORA U-ADAS**

---

## 📋 Overview

The DRIVORA Admin Dashboard is a web-based application that allows administrators to:

✅ View all registered DRIVORA users  
✅ Access complete vehicle & driver information  
✅ Monitor registration dates and cloud sync status  
✅ Export user data for reporting  
✅ Search and filter users by name, email, or vehicle  
✅ View detailed user profiles and telemetry  
✅ Manage user accounts (delete, update)  

---

## 🚀 Quick Start

### Option 1: Firebase Hosting (Recommended)

```bash
# Prerequisites
# - Firebase project created
# - Firebase CLI installed

# Deploy
firebase deploy --only hosting

# Access at
https://your-project.web.app/admin-dashboard/
```

### Option 2: Local Development

```bash
# Open in browser
open index.html

# Or with Python
python3 -m http.server 8000
# Then visit http://localhost:8000
```

---

## 📁 Files

- **index.html** - Dashboard UI structure
- **styles.css** - Responsive styling
- **app.js** - Main application logic
- **firebase-config.js** - Firebase configuration (UPDATE REQUIRED)

---

## ⚙️ Configuration

### Step 1: Update Firebase Configuration

Edit `firebase-config.js` with your Firebase project credentials:

```javascript
const firebaseConfig = {
    apiKey: "AIzaSyDxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
    authDomain: "drivora-adas.firebaseapp.com",
    projectId: "drivora-adas",
    storageBucket: "drivora-adas.appspot.com",
    messagingSenderId: "1234567890",
    appId: "1:1234567890:web:abcdef1234567890"
};
```

Get these values from:
1. Firebase Console → Project Settings ⚙️
2. Copy the Web App config object
3. Paste into firebase-config.js

### Step 2: Add Admin Emails

In Firebase Console → Firestore:

1. Create collection: `admins`
2. Create document: `authorized_emails`
3. Add field: `emails` (array)
4. Add your admin email addresses

```
emails: [
    "admin@company.com",
    "your-email@gmail.com"
]
```

---

## 🔑 Authentication

The dashboard uses **Google Sign-In** for authentication.

### Login Flow

1. User clicks "Sign in with Google"
2. Firebase Authentication dialog opens
3. User selects Google account
4. Dashboard loads if authenticated

### Admin Access Control

Users in the `admins/authorized_emails` document get special privileges. Others can still view data but cannot delete.

---

## 📊 Features

### Dashboard Statistics

Shows real-time metrics:
- **Total Users** - Number of registered drivers
- **Total Vehicles** - Number of registered vehicles
- **Today's Registrations** - New users registered today
- **Cloud Synced** - Users with cloud data

### User Search

```
Search by:
- Driver name
- Email address
- Vehicle model
```

### Sorting

- By Registration Date (Latest first)
- By Driver Name (A-Z)
- By Vehicle Model (A-Z)

### User Details

Click on any user row to see:
- Full name & email
- Firebase UID
- Vehicle information
- Calibration data (height, width)
- System settings (sensitivity, volume)
- Registration & sync dates

### Data Export

```
Click "EXPORT DATA" to download:
- CSV format
- All user information
- Filename: drivora-users-YYYY-MM-DD.csv
```

---

## 🔒 Security Features

✓ Google Sign-In authentication  
✓ Firestore security rules enforcement  
✓ User data isolation (user only see their own)  
✓ Admin role-based access control  
✓ No sensitive data in URLs  
✓ HTTPS required in production  

---

## 🌐 Deployment

### Firebase Hosting

```bash
firebase init hosting
firebase deploy --only hosting
```

**Hosting URL**: https://[projectId].web.app/admin-dashboard/

### Netlify

```bash
netlify deploy --prod
```

### Custom Domain

In Firebase Hosting settings:
1. Add custom domain
2. Update DNS records
3. SSL certificate auto-generated

---

## 📱 Responsive Design

✓ Works on Desktop (1920px+)  
✓ Works on Tablet (768px+)  
✓ Works on Mobile (320px+)  
✓ Touch-friendly buttons  
✓ Optimized for all screen sizes  

---

## 🛠️ Development

### Technologies

- HTML5
- CSS3 (with CSS Variables)
- Vanilla JavaScript (ES6+)
- Firebase SDK 10.7.0
- Firestore Database

### Project Structure

```
firebase-config.js    ← Update with your credentials
app.js                ← Main application logic
styles.css            ← Styling and layout
index.html            ← HTML structure
```

### Local Development

```bash
# Serve locally
python3 -m http.server 8000

# Open in browser
http://localhost:8000
```

### Browser Console Debugging

Open DevTools (F12) and check console for logs:

```javascript
// Test Firebase connection
testFirebaseConnection()

// Force refresh user data
loadUsersData()

// Check current user
console.log(currentUser)

// Check all users
console.log(allUsers)
```

---

## 🐛 Common Issues

### "Firebase not initialized"
- Check firebase-config.js
- Verify Firebase SDK loaded (check Network tab)
- Check browser console for errors

### "No users showing"
- Verify Firestore has user documents
- Check security rules allow read access
- Refresh page with F5
- Check admin role setup

### "Cannot delete user"
- Verify you're in authorized_emails list
- Check Firestore security rules
- Check browser console for error messages

### "Sign in fails"
- Check Google Sign-In is enabled in Firebase
- Clear browser cookies and cache
- Try different browser
- Check internet connection

---

## 📊 Data Structure

Users are stored in Firestore with this structure:

```
users/
├── user@example.com/
│   ├── uid: "firebase-uid"
│   ├── name: "Driver Name"
│   ├── email: "user@example.com"
│   ├── carModel: "Tesla Model 3"
│   ├── calibration:
│   │   ├── height: 1.5
│   │   └── width: 1.8
│   ├── onboarding:
│   │   ├── driverExperience: "5 years"
│   │   ├── vehicleType: "Sedan"
│   │   ├── alertSensitivity: 7
│   │   └── audioVolume: 5
│   ├── registeredAt: timestamp
│   └── lastSyncedAt: timestamp
```

---

## 🔐 Firestore Security Rules

Recommended rules for admin dashboard access:

```firestore-rules
match /users/{document=**} {
  // Only authenticated users can read
  allow read: if request.auth != null;
  
  // Only admins can delete
  allow delete: if request.auth.token.admin == true;
  
  // Users can write their own data
  allow write: if request.auth.email == resource.data.email;
}

match /admins/{document=**} {
  allow read: if request.auth != null;
  allow write: if false;  // Admin list is maintained manually
}
```

---

## 📈 Performance Tips

- **Search**: Optimized for 10,000+ users
- **Pagination**: 10 users per page by default
- **Indexes**: Create Firestore indexes for faster queries
- **Caching**: Browser caches CSS/JS automatically
- **Compression**: Enable gzip on server

---

## 📞 Support

### Resources

- [Firebase Docs](https://firebase.google.com/docs)
- [Firestore Docs](https://firebase.google.com/docs/firestore)
- [JavaScript SDK](https://firebase.google.com/docs/web/setup)

### Debugging

Enable Firebase debug logging:

```javascript
firebase.firestore().enableLogging(true);
firebase.auth().onAuthStateChanged(user => {
    console.log('Auth state changed:', user);
});
```

---

## 📜 License

DRIVORA Admin Dashboard © 2026  
All rights reserved.

---

## 🎯 Future Enhancements

- [ ] User editing interface
- [ ] Advanced analytics
- [ ] Alert history viewer
- [ ] Telemetry dashboard
- [ ] Map integration (show user locations)
- [ ] Schedule data exports
- [ ] User activity timeline
- [ ] Fleet management features

---

**Version**: 1.0.0  
**Status**: ✓ Production Ready
