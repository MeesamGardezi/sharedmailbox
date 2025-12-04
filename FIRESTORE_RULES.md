# Firestore Security Rules

Copy and paste these rules into your Firebase Console → Firestore Database → Rules tab

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Companies collection
    match /companies/{companyId} {
      allow read: if request.auth != null && 
        exists(/databases/$(database)/documents/users/$(request.auth.uid)) &&
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.companyId == companyId;
      
      allow create: if request.auth != null;
      
      allow update, delete: if request.auth != null && 
        resource.data.ownerId == request.auth.uid;
    }
    
    // Users collection
    match /users/{userId} {
      allow read: if request.auth != null && (
        request.auth.uid == userId ||
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.companyId == 
        resource.data.companyId
      );
      
      allow create: if request.auth != null;
      
      allow update: if request.auth != null && request.auth.uid == userId;
    }
    
    // Email Accounts collection
    match /emailAccounts/{accountId} {
      // Users can read email accounts from their company
      allow read: if request.auth != null && 
        exists(/databases/$(database)/documents/users/$(request.auth.uid)) &&
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.companyId == 
        resource.data.companyId;
      
      // Any authenticated user can create an email account for their company
      allow create: if request.auth != null &&
        request.resource.data.companyId == 
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.companyId;
      
      // Users can update/delete email accounts from their company
      allow update, delete: if request.auth != null && 
        exists(/databases/$(database)/documents/users/$(request.auth.uid)) &&
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.companyId == 
        resource.data.companyId;
    }
  }
}
```

## What These Rules Do

### Companies
- ✅ Users can read their own company data
- ✅ Any authenticated user can create a company
- ✅ Only the company owner can update/delete the company

### Users
- ✅ Users can read their own profile
- ✅ Users can read profiles of other users in their company
- ✅ Any authenticated user can create a user profile
- ✅ Users can only update their own profile

### Email Accounts
- ✅ Users can read all email accounts in their company
- ✅ Users can add email accounts to their company
- ✅ Users can update/delete email accounts in their company
- ✅ Users cannot access email accounts from other companies

## How to Apply

1. Go to [Firebase Console](https://console.firebase.com/)
2. Select your project
3. Click **Firestore Database** in the left sidebar
4. Click the **Rules** tab
5. Replace the existing rules with the rules above
6. Click **Publish**

## Testing the Rules

After publishing, test by:
1. Creating a company account in SharedBox
2. Adding an email account
3. Logging in as a different user (different company)
4. Verify you cannot see the first company's email accounts

---

**Important**: These rules assume you're using the data structure created by SharedBox. If you modify the database schema, you'll need to update these rules accordingly.
