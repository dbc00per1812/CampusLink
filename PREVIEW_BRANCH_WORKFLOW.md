# Preview Branch Workflow

## Overview

You're now set up to work on the **Supabase Preview Branch** for developing seek, smart search, recommendations, and performance features. The preview branch lets you test and iterate without affecting production data.

---

## 🔄 Switching Between Preview & Production

### Current Environment

The app is currently set to: **PREVIEW** ✅

To check or change the environment, open:
```
CampusLink/App/Secrets.swift
```

Find line 10:
```swift
static let current: SupabaseEnvironment = .preview  // 👈 Change this
```

### To Switch to Preview (Development)
```swift
static let current: SupabaseEnvironment = .preview
```

### To Switch to Production
```swift
static let current: SupabaseEnvironment = .production
```

---

## 📋 Preview Branch Details

**Supabase URL**: https://ctuzzmrtzrzghdpavpau.supabase.co

**Anon Key**: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...YY_SkletIaF_JZUdFG3E5nimRCfZDrV-6VkiRNQD5Xo`

**Service Role Key**: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...R9r235rXrSE8_-c_Lt2fR_Q7tBA9l2TA0Pc34_MyiYM`

*(Full keys stored in `databaseinfoforcontext/previewbranchkeys.md`)*

---

## 🛠️ Development Workflow

### 1. Working on Preview Branch

1. **Ensure preview environment is active**:
   - Check `Secrets.swift` line 10: `static let current: SupabaseEnvironment = .preview`

2. **Make your changes**:
   - Work on seek features
   - Implement smart search
   - Add recommendations
   - Performance optimizations

3. **Test thoroughly**:
   - All data writes go to preview database
   - Safe to experiment and break things
   - Use test users freely

4. **Commit regularly**:
   ```bash
   git add .
   git commit -m "feat: add smart search filtering"
   ```

### 2. Syncing Preview Branch Database

When you need to update the preview database schema:

1. Make changes in Supabase dashboard for preview project
2. Export SQL if needed
3. Document changes in migration files

### 3. Moving Features to Production

When a feature is ready for production:

#### Step 1: Verify Feature Completeness
- ✅ Feature fully tested on preview
- ✅ No breaking bugs
- ✅ User feedback incorporated
- ✅ Performance validated

#### Step 2: Prepare Database Migration
If your feature requires database changes:

1. Export schema/migration from preview branch
2. Create migration SQL file:
   ```sql
   -- migrations/YYYY-MM-DD_feature_name.sql
   ```
3. Test migration on a copy first

#### Step 3: Switch to Production (Code)
1. Update code to production environment:
   ```swift
   // In Secrets.swift
   static let current: SupabaseEnvironment = .production
   ```

2. Run full test suite against production

3. If tests pass, deploy to production

#### Step 4: Apply Database Migration
1. Run migration on production Supabase:
   - Go to SQL Editor in Supabase dashboard
   - Paste and run migration SQL
   - Verify tables/functions created

2. Test production app with new schema

#### Step 5: Deploy App Update
1. Build production app
2. Test thoroughly
3. Submit to App Store (when ready)

---

## 🔍 Current Preview Branch Features

Working on:
- ✅ **Seek Mode**: Buy/sell posts with budget validation
- 🚧 **Smart Search**: Advanced search and filtering
- 🚧 **Recommendations**: User-based recommendations
- 🚧 **Performance**: Caching, pagination, optimization

---

## 📊 Database Differences

### Preview Branch Has:
- Test users and data
- Experimental schema changes
- Safe for breaking changes

### Production Has:
- Real user data
- Stable schema
- Must maintain backwards compatibility

---

## ⚠️ Important Reminders

1. **Never push production keys to Git**
   - `Secrets.swift` is in `.gitignore`
   - Keep it that way!

2. **Always verify environment before testing**
   - Check console logs show "Preview" environment
   - Double-check before destructive operations

3. **Document all schema changes**
   - Keep migration files
   - Update schema documentation
   - Note breaking changes

4. **Test migrations before production**
   - Try on a copy of production data first
   - Have rollback plan ready

5. **Commit often on preview branch**
   - Small, focused commits
   - Clear commit messages
   - Easy to cherry-pick to production later

---

## 🚀 Quick Commands

### Check Current Environment (in Xcode)
Add this to any view temporarily:
```swift
.onAppear {
    print("🌍 Environment: \(Secrets.currentEnvironmentName)")
    print("📍 Supabase URL: \(Secrets.supabaseURL)")
}
```

### Git Workflow
```bash
# Working on preview branch locally
git add .
git commit -m "feat: smart search implementation"

# Push to remote preview branch
git push origin HEAD:smart-search-performance

# When ready to integrate to production
git checkout main
git merge smart-search-performance
git push origin main
```

---

## 📱 Testing Checklist

Before moving feature from preview to production:

- [ ] Feature works on preview branch
- [ ] Database migration tested
- [ ] No errors in Xcode console
- [ ] User flows validated
- [ ] Performance acceptable
- [ ] Edge cases handled
- [ ] Error handling robust
- [ ] Code reviewed
- [ ] Documentation updated
- [ ] Migration SQL prepared

---

## 🆘 Troubleshooting

### "Network Error" or "Connection Failed"
- Check `Secrets.swift` environment setting
- Verify preview branch is active in Supabase dashboard
- Check internet connection

### "Database Error" or "RPC Failed"
- Ensure database function exists in preview branch
- Check Supabase logs in dashboard
- Verify service role key if using RPC

### "Auth Error"
- Clear app data and reinstall
- Verify anon key is correct for preview
- Check auth settings in Supabase dashboard

---

## 📝 Notes

- Preview branch URL: https://ctuzzmrtzrzghdpavpau.supabase.co
- Production URL: https://vnmzijluyctlufnzxast.supabase.co
- Current Git branch: `smart-search-performance`
- Local environment: **PREVIEW** (set in Secrets.swift)

---

**Remember**: The goal is to build and test features safely on preview, then integrate the polished, tested code into production when ready!

Happy coding! 🚀

Darragh

