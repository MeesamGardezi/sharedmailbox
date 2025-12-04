# 🚀 Quick Start Guide

## 1️⃣ Install Dependencies
```bash
npm install
```

## 2️⃣ Configure Firebase
1. Open `FIREBASE_CONFIG_TEMPLATE.md` for detailed instructions
2. Create a Firebase project at https://console.firebase.google.com/
3. Enable Authentication (Email/Password) and Firestore
4. Update `public/core/firebase.js` with your config:
```javascript
const firebaseConfig = {
    apiKey: "YOUR_API_KEY",
    authDomain: "YOUR_PROJECT_ID.firebaseapp.com",
    projectId: "YOUR_PROJECT_ID",
    storageBucket: "YOUR_PROJECT_ID.appspot.com",
    messagingSenderId: "YOUR_SENDER_ID",
    appId: "YOUR_APP_ID"
};
```

## 3️⃣ Configure Email (Optional for testing auth)
Update `.env`:
```env
IMAP_USER=your-email@example.com
IMAP_PASSWORD=your-password
IMAP_HOST=imap.example.com
IMAP_PORT=993
IMAP_TLS=true
```

## 4️⃣ Run the App
```bash
npm start
```
Visit: http://localhost:3000

## 5️⃣ Test the Features

### Create Company Account
1. Click "Create Company"
2. Enter company name, email, password
3. Click "Create Account"

### Add Employees (Owner Only)
1. Login as owner
2. Click "Team" in sidebar
3. Click "Add Employee"
4. Enter email and password
5. Click "Create Account"

### View Emails
1. Emails auto-load on login
2. Click any email to read
3. Click refresh to sync

## 📁 File Structure
```
public/
├── core/           # Core app files
│   ├── app.js      # Main orchestrator
│   ├── firebase.js # Firebase config (⚠️ UPDATE THIS)
│   └── styles.css  # Global styles
└── features/       # Feature modules
    ├── auth/       # Login/signup
    ├── inbox/      # Email management
    └── company/    # Team management
```

## 🔑 Key Files to Update
- ✅ `public/core/firebase.js` - Add your Firebase config
- ✅ `.env` - Add your email credentials

## 🎯 What's New
- ✨ Modern, premium UI design
- 🔐 Firebase authentication system
- 👥 Company & team management
- 📧 Role-based access (Owner/Employee)
- 🏗️ Modular architecture (features in separate folders)
- 📱 Responsive design

## 📚 Documentation
- `README.md` - Full documentation
- `IMPLEMENTATION_SUMMARY.md` - Technical details
- `FIREBASE_CONFIG_TEMPLATE.md` - Firebase setup guide

## ⚡ Quick Commands
```bash
npm start              # Start the server
npm install            # Install dependencies
```

## 🆘 Need Help?
1. Check `README.md` for detailed instructions
2. See `FIREBASE_CONFIG_TEMPLATE.md` for Firebase setup
3. Review `IMPLEMENTATION_SUMMARY.md` for architecture details

---
**Note**: You MUST configure Firebase before the auth system will work!
