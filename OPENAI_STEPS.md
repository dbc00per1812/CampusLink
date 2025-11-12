# OpenAI Embeddings - Simple Steps

## You're Here: Have OpenAI Key in Vault ✅

Good! You stored it as `OPEN_AI_KEY` in Supabase Vault.

---

## What to Do Now:

### 1. Run This File:

**`USE_VAULT_SECRET.sql`** in Supabase SQL Editor

- Copy entire file
- Paste in SQL Editor
- Click "Run"
- Wait 1-2 minutes

### 2. Watch the Output:

**If you see "✅ SUCCESS!":**
- Great! It's working
- Keep running the same file 3-4 more times
- Each run processes 20 more listings
- Stop when it says "ALL EMBEDDINGS COMPLETE"

**If you see "❌ FAILED":**
- Tell me the exact error
- Most common: Wrong secret name or no credits

### 3. After All Embeddings Done:

Change in your app:
```swift
// AppConfig.swift
static let enableHybridSearch = true  // Change from false to true
```

Build and run!

---

## Quick Summary:

1. ✅ You have OpenAI key in Vault
2. ➡️ Run `USE_VAULT_SECRET.sql` now
3. ➡️ Keep running it until 100% done
4. ➡️ Enable hybrid search in app

**Run the file now and tell me what you see!**

---

## Cost:

71 listings × $0.0004 = ~$0.03 total

Very cheap!
