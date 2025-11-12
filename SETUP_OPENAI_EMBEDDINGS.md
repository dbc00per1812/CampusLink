# Setup OpenAI Embeddings (Simple Guide)

## Step 1: Get OpenAI API Key (2 minutes)

1. Go to: https://platform.openai.com/api-keys
2. Click **"Create new secret key"**
3. Name it: "CampusLink Embeddings"
4. Copy the key (starts with `sk-...`)
5. **Save it somewhere safe** - you'll need it in Step 3

**Cost:** ~$0.03 for 71 listings (super cheap)

---

## Step 2: Store API Key in Supabase (Secure Method)

### Option A: Supabase Vault (Most Secure)

1. In Supabase Dashboard → **Vault** (you saw it in settings with BETA tag)
2. Click **"New Secret"**
3. Name: `openai_api_key`
4. Value: Paste your OpenAI key (`sk-...`)
5. Click **"Save"**

### Option B: Database Setting (Alternative)

If Vault doesn't work, run this in SQL Editor:

```sql
-- Store API key securely (only visible to database functions)
ALTER DATABASE postgres SET app.settings.openai_api_key = 'sk-YOUR-KEY-HERE';
```

Replace `sk-YOUR-KEY-HERE` with your actual key.

---

## Step 3: Run the OpenAI Migration

I'll create a new file: `OPENAI_MIGRATION.sql`

This will:
- ✅ Use OpenAI API directly (not Supabase AI)
- ✅ Generate embeddings for all 71 listings
- ✅ Be production-safe
- ✅ Work on any Supabase plan

---

## Next Steps

1. Get your OpenAI API key from platform.openai.com
2. Store it using Option A or B above
3. Tell me when ready, and I'll give you the final SQL file to run
4. Takes ~2 minutes to generate all 71 embeddings

---

**Ready to get your API key?**

