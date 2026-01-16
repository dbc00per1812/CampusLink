# Community Forums Setup Guide

## Quick Start

The React Native app now has community forums with two channels: **General** and **Support**. Follow these steps to enable the feature.

## Step 1: Database Migration

1. Open your Supabase dashboard
2. Go to SQL Editor
3. Copy and run the SQL from: `docs/sql/create_forum_messages.sql`

This will create:
- ✅ `forum_messages` table
- ✅ Database indexes for performance
- ✅ Row Level Security (RLS) policies

## Step 2: Verify RLS Policies

After running the migration, verify these policies are active in Supabase:

**Table**: `forum_messages`
- ✅ "Anyone can read forum messages" (SELECT)
- ✅ "Authenticated users can create forum messages" (INSERT)
- ✅ "Users can update their own messages" (UPDATE)
- ✅ "Users can delete their own messages" (DELETE)

## Step 3: Test the Feature

1. Open the app
2. Navigate to the **Messages** tab (bottom navigation)
3. You'll see two tabs at the top: **Direct Messages** and **Community**
4. Tap **Community**
5. Switch between **General** and **Support** channels
6. Send a test message in each channel
7. Verify messages appear in real-time

## Features

### What's Included

✅ **Two Channels**: General (campus chat) and Support (help/questions)  
✅ **Real-time Updates**: Messages appear instantly for all users  
✅ **User Attribution**: Each message shows sender name and avatar  
✅ **Date Headers**: Messages grouped by day  
✅ **Timestamps**: Shows when each message was sent  
✅ **Auto-scroll**: Automatically scrolls to latest message  
✅ **Haptic Feedback**: Tactile feedback on tab/channel switches  
✅ **Empty States**: Helpful messages when channels are empty  
✅ **Type-safe**: Full TypeScript implementation  
✅ **Secure**: Row Level Security enforced

### How It Works

1. **Messages Tab**: Default view shows your direct message conversations
2. **Tap Community**: Switches to community forums view
3. **Select Channel**: Choose between General or Support
4. **Type & Send**: Write a message and tap send
5. **Real-time**: Everyone sees the message instantly

## Architecture

### Files Created

```
mobile/src/
├── types/forum.ts                          # TypeScript types
├── services/forumService.ts                # API service layer
└── screens/messages/
    ├── CommunityForumScreen.tsx            # Community forum UI
    └── ConversationsScreen.tsx (modified)  # Added tab switcher

docs/
├── sql/create_forum_messages.sql           # Database migration
└── features/COMMUNITY_FORUMS.md            # Full documentation
```

### Database Schema

```sql
CREATE TABLE forum_messages (
  id UUID PRIMARY KEY,
  channel TEXT CHECK (channel IN ('general', 'support')),
  sender_id UUID REFERENCES users(id),
  content TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP
);
```

## Troubleshooting

### Messages not appearing?

1. Check Supabase dashboard → Database → Realtime is enabled
2. Verify RLS policies are active on `forum_messages` table
3. Check browser/app console for errors

### Can't send messages?

1. Ensure user is logged in
2. Verify RLS INSERT policy allows authenticated users
3. Check message content is not empty

### Navigation issues?

1. Clear app cache and restart
2. Ensure you're on the latest version
3. Check navigation stack isn't corrupted

## Future Enhancements

Planned features (see `docs/features/COMMUNITY_FORUMS.md` for details):
- Message reactions (👍 ❤️ 😂)
- Edit/delete your own messages
- Rich text formatting (bold, italic, links)
- Image uploads
- @mentions with notifications
- Message search
- Thread replies
- Custom channels
- Moderation tools
- Typing indicators

## Documentation

For complete technical documentation, see:
- **Full docs**: `docs/features/COMMUNITY_FORUMS.md`
- **Database schema**: `docs/databaseinfoforcontext/databaseinfoforcontext.md`
- **Changelog**: `logs/2026-01-03.md`

## Support

If you encounter issues:
1. Check the troubleshooting section above
2. Review the full documentation
3. Check the Supabase dashboard for errors
4. Verify the database migration ran successfully

---

**Version**: 1.0.0  
**Date**: January 3, 2026  
**Status**: Ready for Testing

