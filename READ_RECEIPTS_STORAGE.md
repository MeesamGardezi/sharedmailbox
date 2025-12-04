# Read Receipts & Email Status Storage

## Current Implementation

### 📍 Where Read Status is Stored

**Frontend (Flutter):**
- Read status is stored in the `Email` model as `isRead` property
- Location: `flutter_frontend/lib/core/models/email_model.dart`
- When an email is clicked, `state.markAsRead(email)` is called
- This updates the local state immediately for UI feedback

**Backend API:**
- Endpoint: `POST /api/emails/:id/read`
- Location: `server.js`
- Currently the endpoint exists but doesn't persist to a database
- **Issue**: Read status is NOT being persisted anywhere

### 🔴 Current Problem

**Read receipts are NOT being cached/stored properly:**
- They only exist in-memory on the frontend
- When you refresh the page, all emails appear unread again
- No database persistence

### ✅ Solution: Implement Read Receipt Storage

You have **two options** for storing read receipts:

---

## Option 1: Store in Firestore (Recommended)

### Create a new Firestore collection: `emailReadStatus`

**Structure:**
```javascript
{
  userId: "user123",           // Who read it
  emailId: "email456",          // Which email
  accountId: "account789",      // From which account
  readAt: Timestamp,            // When it was read
  companyId: "company001"       // Company context
}
```

**Update server.js:**
```javascript
// Add this endpoint around line 500 in server.js
app.post('/api/emails/:id/read', async (req, res) => {
  try {
    const { id } = req.params;
    const { userId, accountId, companyId } = req.body;
    
    // Save to Firestore
    await db.collection('emailReadStatus').add({
      userId,
      emailId: id,
      accountId,
      companyId,
      readAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    res.json({ success: true });
  } catch (error) {
    console.error('Error marking email as read:', error);
    res.status(500).json({ error: error.message });
  }
});

// When fetching emails, check read status
app.post('/api/emails', async (req, res) => {
  try {
    const { accounts } = req.body;
    const userId = req.query.userId; // Pass from frontend
    
    // ... fetch emails logic ...
    
    // Get read statuses for this user
    const readStatusDocs = await db.collection('emailReadStatus')
      .where('userId', '==', userId)
      .get();
    
    const readEmailIds = new Set(
      readStatusDocs.docs.map(doc => doc.data().emailId)
    );
    
    // Mark emails as read
    const emailsWithReadStatus = emails.map(email => ({
      ...email,
      isRead: readEmailIds.has(email.id)
    }));
    
    res.json(emailsWithReadStatus);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});
```

**Update Flutter frontend:**
```dart
// In inbox_state.dart, update markAsRead:
Future<void> markAsRead(Email email) async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final response = await http.post(
      Uri.parse('$_baseUrl/emails/${email.id}/read'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': user.uid,
        'accountId': email.accountId,
        'companyId': email.companyId, // You'll need to pass this
      }),
    );
    
    if (response.statusCode == 200) {
      // Update local state
      final index = _emails.indexWhere((e) => e.id == email.id);
      if (index != -1) {
        _emails[index] = Email(
          // ... all email properties
          isRead: true,
        );
        notifyListeners();
      }
    }
  } catch (e) {
    print('Error marking email as read: $e');
  }
}
```

---

## Option 2: Store in Local Browser Storage (Quick Fix)

**Use Flutter's `shared_preferences` package:**

```yaml
# pubspec.yaml
dependencies:
  shared_preferences: ^2.2.2
```

```dart
// In inbox_state.dart
import 'package:shared_preferences/shared_preferences.dart';

Future<void> markAsRead(Email email) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final readEmails = prefs.getStringList('readEmails') ?? [];
    
    if (!readEmails.contains(email.id)) {
      readEmails.add(email.id);
      await prefs.setStringList('readEmails', readEmails);
    }
    
    // Update local state
    final index = _emails.indexWhere((e) => e.id == email.id);
    if (index != -1) {
      _emails[index] = Email(
        // ... all email properties
        isRead: true,
      );
      notifyListeners();
    }
  } catch (e) {
    print('Error marking email as read: $e');
  }
}

Future<void> fetchEmails() async {
  try {
    // ... existing fetch logic ...
    
    // Load read statuses from local storage
    final prefs = await SharedPreferences.getInstance();
    final readEmails = prefs.getStringList('readEmails') ?? [];
    final readEmailsSet = Set<String>.from(readEmails);
    
    // Mark emails as read based on local storage
    final emailsWithReadStatus = emails.map((email) {
      return Email(
        // ... all email properties
        isRead: readEmailsSet.contains(email.id),
      );
    }).toList();
    
    _emails = emailsWithReadStatus;
    notifyListeners();
  } catch (e) {
    // ... error handling
  }
}
```

---

## 🎯 Recommendation

**Use Option 1 (Firestore)** because:
- ✅ Syncs across devices
- ✅ Shared within team
- ✅ More scalable
- ✅ Centralized data
- ✅ Can add analytics (who reads what)

**Use Option 2 (Local Storage)** only if:
- ⚠️ You want a quick prototype
- ⚠️ Don't need cross-device sync
- ⚠️ Don't need team-wide read status

---

## 🔧 Next Steps

1. **Add Firestore Admin SDK** to server.js (if not already)
2. **Create the `emailReadStatus` collection** structure
3. **Update the `/api/emails/:id/read` endpoint** to save to Firestore
4. **Update the `/api/emails` endpoint** to fetch and merge read statuses
5. **Update Flutter's `markAsRead` method** to send proper data
6. **Add Firestore security rules** for the new collection

Would you like me to implement Option 1 (Firestore storage) for you?
