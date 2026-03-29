# 🔧 Firestore Security Rules Fix

## Problem
You're getting: `permission-denied: Missing or insufficient permissions. Access denied by rules/policies.`

This means your Firestore security rules don't allow write operations to the `tours` collection.

## Solution: Update Firestore Rules

### Step 1: Go to Firebase Console
1. Open [Firebase Console](https://console.firebase.google.com)
2. Select your project: **ceylon-share-tour**
3. Go to **Firestore Database** → **Rules** tab

### Step 2: Replace ALL Rules with These

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Allow read/write to users collection (for authentication)
    match /users/{document=**} {
      allow read, write: if true;
    }
    
    // Allow read/write to tours collection
    match /tours/{document=**} {
      allow read: if true;        // Anyone can read tours
      allow write: if true;       // Anyone can write tours (change in production)
      allow delete: if true;      // Anyone can delete tours
    }
    
    // Allow read/write to drivers collection
    match /drivers/{document=**} {
      allow read: if true;        // Anyone can read drivers
      allow write: if true;       // Anyone can write drivers
      allow delete: if true;      // Anyone can delete drivers
    }
    
    // Deny everything else
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

### Step 3: Click "Publish" Button

## ⚠️ Security Note

The rules above allow **anyone** to read and write. For production, use this instead:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Users collection - admin only
    match /users/{uid} {
      allow read, write: if request.auth != null;
    }
    
    // Tours - admin only can write
    match /tours/{tourId} {
      allow read: if true;
      allow write, delete: if request.auth != null;
    }
    
    // Drivers - admin only can write
    match /drivers/{driverId} {
      allow read: if true;
      allow write, delete: if request.auth != null;
    }
    
    // Deny everything else
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

## Supabase Storage Rules

Also check your Supabase Storage policies:

1. Go to [Supabase Dashboard](https://supabase.com/dashboard)
2. Select your project
3. Go to **Storage** → **Policies** tab
4. Make sure the `images` bucket has:
   - ✅ **SELECT** policy: `true` (anyone can read)
   - ✅ **INSERT** policy: `true` (anyone can upload)
   - ✅ **DELETE** policy: `true` (anyone can delete)

If you don't see policies, create them with these settings:

**For INSERT:**
```
(storage.foldername = 'tours' or storage.foldername = 'common')
```

**For DELETE:**
```
(storage.foldername = 'tours' or storage.foldername = 'common')
```

## Testing
After updating rules:
1. Refresh your admin dashboard
2. Try adding a tour
3. Should now work! ✅

## Troubleshooting

**Still getting permission error?**
- [ ] Confirm rules are published (look for "All set!" message)
- [ ] Wait 30 seconds and refresh the page
- [ ] Check browser console (F12) for specific error messages
- [ ] Verify `projectId` in firebase.js is `ceylon-share-tour`

**Tours collection doesn't exist?**
- No problem! Firestore will create it automatically when you add the first tour

**Check if Rules are Working:**
Open browser console (F12) and look for error details that might indicate:
- Wrong collection path
- Authentication issues
- Storage bucket issues
