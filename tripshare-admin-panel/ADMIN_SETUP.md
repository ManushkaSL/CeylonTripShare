# Admin Dashboard Setup Guide

## Role-Based Access Control

The TripShare Admin Dashboard now includes **role-based access control (RBAC)**. Only users with the **admin** role can access the dashboard.

## Firebase Users Collection Structure

### Creating Admin Users in Firebase Firestore

The admin dashboard queries a `users` collection in Firestore to verify user credentials and roles. You need to create this collection and add admin users with proper role assignments.

### Required Collection: `users`

Create a Firestore collection named `users` with the following document structure:

```json
{
  "email": "admin@example.com",
  "password": "securepassword123",
  "role": "admin",
  "created_at": "2024-03-29T00:00:00Z",
  "updated_at": "2024-03-29T00:00:00Z",
  "permissions": [
    "manage_tours",
    "manage_drivers",
    "view_analytics",
    "delete_content"
  ],
  "status": "active"
}
```

### Field Descriptions:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `email` | string | ✅ | User's email address (should be lowercase) |
| `password` | string | ✅ | User's password (store securely in production) |
| `role` | string | ✅ | User's role - must be `"admin"` for dashboard access |
| `created_at` | timestamp | ⚠️ | User creation date |
| `updated_at` | timestamp | ⚠️ | Last update date |
| `permissions` | array | ⚠️ | Array of permission strings |
| `status` | string | ⚠️ | User status: `"active"`, `"inactive"`, or `"pending"` |

## How to Add Admin Users

### Using Firebase Console:

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your TripShare project
3. Navigate to **Firestore Database**
4. Create a new collection called `users` (if it doesn't exist)
5. Click **Add document** and enter:
   - Document ID: (auto-generate or use email)
   - Add fields with the structure shown above

### Example Admin User:

```json
{
  "email": "admin@tripshare.com",
  "password": "AdminPassword123!",
  "role": "admin",
  "created_at": "2024-03-29",
  "updated_at": "2024-03-29",
  "permissions": ["manage_tours", "manage_drivers", "delete_content"],
  "status": "active"
}
```

## Login Workflow

1. **User enters email and password** on the admin login page
2. **System checks requirements**:
   - ✅ Email matches a user in the `users` collection
   - ✅ Password matches the stored password
   - ✅ User's `role` field equals `"admin"`
3. **Access granted or denied**:
   - ✅ If all checks pass: User is authenticated and granted full admin access
   - ❌ If role is not "admin": Error message: "Unauthorized: Only users with admin role can access this dashboard"
   - ❌ If email/password incorrect: Error message: "Invalid email or password"

## Admin Permissions

Users with admin role receive full permissions including:
- ✅ **Tours Management**: Create, read, update, delete tours
- ✅ **Driver Management**: Add, edit, remove drivers
- ✅ **Full Dashboard Access**: View all sections and analytics

## Security Recommendations

### ⚠️ Important Security Notes:

1. **Password Storage**: In production, use Firebase Authentication instead of storing passwords as plain text
2. **Environment Variables**: Store sensitive data in `.env` files
3. **Firestore Rules**: Set up proper Firestore security rules to prevent unauthorized access
4. **HTTPS Only**: Always use HTTPS in production
5. **Rate Limiting**: Implement rate limiting on login attempts
6. **Audit Logging**: Log all admin activities

### Recommended Firestore Rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection - only authenticated users can read their own role
    match /users/{document=**} {
      allow read, write: if false; // Disable direct access, use backend only
    }
    
    // Tours and Drivers collections
    match /tours/{document=**} {
      allow read, write: if request.auth != null;
    }
    
    match /drivers/{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

## Testing

To test admin access:

1. Create a user in Firebase Firestore with:
   - `email`: "test@admin.com"
   - `password`: "testadmin123"
   - `role`: "admin"

2. On the login page, enter:
   - Email: `test@admin.com`
   - Password: `testadmin123`

3. Click "Sign In"

### Expected Results:

✅ **Success**: Dashboard loads with admin access badge
❌ **Failure**: Error message displayed if role is not "admin"

## Logout

When admin users sign out:
- Session storage is cleared
- All user data is removed from browser
- User returns to login screen

## Troubleshooting

### "Invalid email or password"
- Verify email exists in `users` collection
- Check password matches exactly (case-sensitive)
- Ensure email is lowercase

### "Unauthorized: Only users with admin role can access this dashboard"
- Verify user's `role` field is set to exactly `"admin"`
- Check that role field is not "Admin" or "ADMIN" (must be lowercase)
- Ensure the user document has the `role` field

### Connection Issues
- Verify Firebase configuration in `src/firebase.js`
- Check that Firestore database is initialized
- Ensure API keys are correct in `.env` file

## Future Enhancements

Potential improvements to this system:
- [ ] Integrate with Firebase Authentication
- [ ] Remove plain text password storage
- [ ] Implement role-based permission system
- [ ] Add 2FA (Two-Factor Authentication)
- [ ] Implement OAuth2 integration
- [ ] Add activity audit logs
- [ ] Set up automatic password expiration policies
