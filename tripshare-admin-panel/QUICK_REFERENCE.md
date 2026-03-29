# 🔐 Admin Dashboard - Quick Reference

## 🔑 Required Firebase Setup

**Collection Name:** `users`

**Required Document Fields:**
```
email      → admin@example.com
password   → securepassword123
role       → admin  (MUST BE "admin")
status     → active
```

## ✅ Login Requirements

All three must be true:
1. ✅ Email exists in `users` collection
2. ✅ Password matches exactly 
3. ✅ Role = `"admin"` (case-sensitive)

## 🚫 Rejection Messages

| Condition | Error Message |
|-----------|---------------|
| Email not found | "Invalid email or password" |
| Wrong password | "Invalid email or password" |
| Role ≠ "admin" | "Unauthorized: Only users with admin role can access this dashboard" |

## 🎯 Admin Privileges

- ✅ Create/Edit/Delete Tours
- ✅ Manage Drivers
- ✅ View Analytics
- ✅ Full Dashboard Access

## 🔄 Session Info Stored

```
sessionStorage {
  admin_auth    → "true"
  admin_role    → "admin"
  admin_email   → user's email
  admin_user_id → document ID from users collection
}
```

## 📋 Quick Setup Checklist

- [ ] Create `users` collection in Firestore
- [ ] Add admin user with `role: "admin"`
- [ ] Test login with admin credentials
- [ ] Verify admin badge appears on dashboard
- [ ] Test logout clears all data

## 🔒 Security Tips

⚠️ **Important:**
- Never use plain text passwords in production
- Migrate to Firebase Authentication
- Set up Firestore security rules
- Enable HTTPS only
- Use environment variables for sensitive data

## 🆘 Troubleshooting

**Can't login?**
- Check email is in `users` collection
- Verify password matches exactly
- Ensure `role` field = `"admin"` (lowercase)
- Check Firestore connection

**Getting "Unauthorized" error?**
- Confirm user's `role` field is `"admin"`
- Not "Admin" or "ADMIN" - must be lowercase

---

**Status:** ✅ Role-Based Access Control Active
