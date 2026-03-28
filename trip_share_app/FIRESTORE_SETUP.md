# Firestore Setup Guide for Tripshare Chat

## Firestore Collection Structure

```
firestore/
├── users/
│   └── {userId}/
│       ├── email: string
│       ├── displayName: string
│       ├── photoURL: string
│       └── createdAt: timestamp
│
├── messages/ (ROOT LEVEL - ALL TOUR MESSAGES HERE)
│   └── {messageId}/
│       ├── tourId: string (which tour this message belongs to)
│       ├── senderId: string
│       ├── senderName: string
│       ├── text: string
│       └── timestamp: timestamp
│
├── tours/
│   └── {tourId}/
│       ├── name: string
│       ├── description: string
│       ├── location: string
│       ├── price: number
│       ├── totalSeats: number
│       ├── remainingSeats: number
│       ├── guideId: string
│       ├── imageUrl: string
│       ├── startDate: timestamp
│       ├── duration: number
│       ├── lastJoiningTime: timestamp
│       ├── createdAt: timestamp
│       │
│       ├── bookings/ (subcollection)
│       │   └── {bookingId}/
│       │       ├── userId: string
│       │       ├── seatsBooked: number
│       │       ├── status: string (completed, cancelled, pending)
│       │       └── bookedAt: timestamp
│       │
│       └── participants/ (optional)
│           └── {userId}/
│               └── joinedAt: timestamp
│
└── joinedTours/ (user's booking records)
    └── {joinedTourId}/
        ├── userId: string
        ├── tourId: string
        ├── tour: object (denormalized tour data)
        ├── seatsBooked: number
        ├── isChatAvailable: boolean
        └── bookedAt: timestamp
```

## Chat Collection Details - ROOT LEVEL

**The messages collection is at the ROOT level**, not nested under tours!

**Collection Path:** `messages/{messageId}`

**Document Structure:**
```json
{
  "tourId": "tour-id-string",
  "senderId": "user-uid-of-sender",
  "senderName": "User Display Name",
  "text": "Message content here",
  "timestamp": "Firestore Timestamp"
}
```

**This means:**
- ✅ The `messages` collection is visible in Firestore Console
- ✅ All tour messages are in ONE place for easy management
- ✅ Query messages by `tourId` to get a specific tour's chat
- ✅ Scales better than subcollections for high message volume

## How Chat Works

1. **Message Sending:** When a user sends a message:
   ```
   messages/{messageId}
   {
     tourId: "tour123",
     senderId: "user456",
     ...
   }
   ```

2. **Real-time Sync:** The app listens and filters by tourId:
   ```dart
   collection('messages')
     .where('tourId', isEqualTo: tourId)
     .orderBy('timestamp', descending: true)
     .snapshots()
   ```

3. **Multiple Users:** Any authenticated user in the tour can:
   - View all messages filtered by that tour's tourId
   - Send new messages (added automatically with tourId)
   - See messages from other users in real-time

## Setup Steps

### 1. Deploy Firestore Security Rules

Run these commands in your project root:

```bash
# Install Firebase CLI (if not already installed)
npm install -g firebase-tools

# Login to Firebase
firebase login

# Deploy the firestore rules
firebase deploy --only firestore:rules
```

### 2. Verify Collection in Firestore Console

Go to **Firebase Console** → **Firestore Database**:

1. You should see these collections:
   - ✅ `bookings`
   - ✅ `tours`
   - ❓ `messages` (will appear after first message is sent)
   - ✅ `joinedTours`

2. The `messages` collection will appear automatically when the first message is sent

### 3. Test the Chat

1. Open the app
2. Have at least 2 users (different accounts)
3. Both users join the same tour
4. Navigate to **Chats** → Select the tour
5. Send a message
6. Verify:
   - Message appears in Firestore Console under `messages/` collection
   - Message has `tourId` field set correctly
   - Other user sees the message in real-time

## Troubleshooting

### Messages collection doesn't appear

✅ **This is normal!** Firestore only shows collections that have documents. Once you send a message, the collection will appear.

### Messages not appearing in chat screen?

1. **Check Firestore Rules:** Go to Firebase Console → Firestore → Rules
   - Ensure the rules from `firestore.rules` are deployed
   - Check authentication is working

2. **Check Message Document:** In Firestore Console
   ```
   Go to: messages/ collection
   Each message should have:
   - tourId: "correct-tour-id"
   - senderId: "user-id"
   - text: "message content"
   - timestamp: valid timestamp
   ```

3. **Check Console Logs:** Look at Flutter console output
   - Look for: `✅ Message sent to tour...`
   - Look for: `❌ Error...` messages

4. **Verify Authentication:** Make sure user is logged in:
   ```dart
   final userId = AuthService().userId;
   print('Logged in as: $userId'); // Should not be empty
   ```

### "Permission denied" error?

→ **Solution:** Your firestore.rules might not be deployed. Run:
```bash
firebase deploy --only firestore:rules
```

Then restart the app.

### Development: Using Test Mode (30-day access)

If you want to quickly test without deploying rules:

1. In **Firebase Console** → **Firestore Database** → **Rules tab**
2. Click **"Start in test mode"**
3. This allows all reads/writes for 30 days

⚠️ **IMPORTANT:** Switch to proper rules from `firestore.rules` before production!

## Indexing

For better query performance with large datasets, you can create a composite index:

**Index needed:**
- Collection: `messages`
- Fields: `tourId` (Ascending), `timestamp` (Descending)

Firebase will prompt you to create this index automatically when you first run a query with these fields.

## File Locations

- **Firestore Rules:** `firestore.rules`
- **Chat Service:** `lib/services/chat_service.dart`
- **Security Doc:** This file (`FIRESTORE_SETUP.md`)

