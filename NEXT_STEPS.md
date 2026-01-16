# Community Forums - Next Steps

## 🎯 What You Need to Do

The community forums feature is **fully implemented** in the React Native app. You just need to run one SQL migration to enable it.

## Step 1: Run Database Migration ✅

### Option A: Supabase Dashboard (Recommended)

1. Open your [Supabase Dashboard](https://app.supabase.com)
2. Select your CampusLink project
3. Go to **SQL Editor** (left sidebar)
4. Click **New Query**
5. Copy the entire contents of: `docs/sql/create_forum_messages.sql`
6. Paste into the SQL editor
7. Click **Run** or press `Cmd+Enter`

### Option B: Direct SQL

Copy and run this SQL in Supabase:

```sql
-- Create forum_messages table for community channels
CREATE TABLE IF NOT EXISTS public.forum_messages (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  channel text NOT NULL CHECK (channel IN ('general', 'support')),
  sender_id uuid NOT NULL,
  content text NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone,
  CONSTRAINT forum_messages_pkey PRIMARY KEY (id),
  CONSTRAINT forum_messages_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES public.users(id) ON DELETE CASCADE
);

-- Add indexes
CREATE INDEX IF NOT EXISTS idx_forum_messages_channel 
ON public.forum_messages(channel, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_forum_messages_sender 
ON public.forum_messages(sender_id);

-- Enable Row Level Security
ALTER TABLE public.forum_messages ENABLE ROW LEVEL SECURITY;

-- Anyone can read forum messages
CREATE POLICY "Anyone can read forum messages"
ON public.forum_messages FOR SELECT USING (true);

-- Authenticated users can create forum messages
CREATE POLICY "Authenticated users can create forum messages"
ON public.forum_messages FOR INSERT WITH CHECK (auth.uid() = sender_id);

-- Users can update their own messages
CREATE POLICY "Users can update their own messages"
ON public.forum_messages FOR UPDATE 
USING (auth.uid() = sender_id) WITH CHECK (auth.uid() = sender_id);

-- Users can delete their own messages
CREATE POLICY "Users can delete their own messages"
ON public.forum_messages FOR DELETE USING (auth.uid() = sender_id);
```

## Step 2: Verify Setup ✅

After running the migration, verify in Supabase:

### Check Table Exists
1. Go to **Table Editor**
2. You should see `forum_messages` table
3. Columns: `id`, `channel`, `sender_id`, `content`, `created_at`, `updated_at`

### Check RLS Policies
1. Go to **Authentication** → **Policies**
2. Select `forum_messages` table
3. You should see 4 policies:
   - ✅ Anyone can read forum messages
   - ✅ Authenticated users can create forum messages
   - ✅ Users can update their own messages
   - ✅ Users can delete their own messages

## Step 3: Test the Feature 🧪

1. **Open the app** on your device/simulator
2. **Navigate to Messages tab** (bottom navigation)
3. **Look for the tabs at the top**: "Direct Messages" and "Community"
4. **Tap "Community"**
5. **You'll see two channel tabs**: General and Support
6. **Send a test message** in General channel
7. **Switch to Support** and send another message
8. **Open a second device/browser** (if available) and verify messages appear in real-time

### Expected Behavior

✅ Messages appear instantly in real-time  
✅ Your messages show on the right (blue)  
✅ Other users' messages show on the left (gray) with avatar  
✅ Date headers appear (Today/Yesterday)  
✅ Timestamps show for each message  
✅ Auto-scrolls to latest message  
✅ Haptic feedback when switching tabs/channels  

## Troubleshooting

### "Cannot read messages"
- **Fix**: Verify RLS SELECT policy is enabled
- **Command**: Check Supabase → Policies → forum_messages

### "Cannot send messages"
- **Fix**: Ensure you're logged in
- **Fix**: Verify RLS INSERT policy allows authenticated users

### "Table doesn't exist"
- **Fix**: Re-run the migration SQL
- **Check**: Supabase → Table Editor for `forum_messages`

### "No real-time updates"
- **Fix**: Supabase → Database → Settings → Enable Realtime for `forum_messages`

## What's Included

### React Native Code ✅
- ✅ TypeScript types (`types/forum.ts`)
- ✅ API service (`services/forumService.ts`)
- ✅ Community UI (`screens/messages/CommunityForumScreen.tsx`)
- ✅ Tab switcher (updated `ConversationsScreen.tsx`)

### Database Schema ✅
- ✅ SQL migration ready (`docs/sql/create_forum_messages.sql`)
- ✅ RLS policies defined
- ✅ Indexes for performance

### Documentation ✅
- ✅ Setup guide (`COMMUNITY_FORUMS_SETUP.md`)
- ✅ Full documentation (`docs/features/COMMUNITY_FORUMS.md`)
- ✅ Implementation summary (`COMMUNITY_FORUMS_SUMMARY.md`)
- ✅ Changelog entry (`logs/2026-01-03.md`)

## You're Done! 🎉

After running the SQL migration, the feature is **live and ready to use**. No app rebuild required!

---

**Questions?** Check the documentation:
- Quick setup: `COMMUNITY_FORUMS_SETUP.md`
- Full docs: `docs/features/COMMUNITY_FORUMS.md`
- Summary: `COMMUNITY_FORUMS_SUMMARY.md`

---

*Ready to test: January 3, 2026*

