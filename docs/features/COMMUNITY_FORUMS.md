# Community Forums Feature

## Overview

Community Forums is an open messaging feature that allows all users to participate in public channels. Unlike direct messages which are private between two users, community forums are visible to everyone and enable campus-wide conversations.

## Channels

The system includes two community channels:

1. **General** - General campus discussions, announcements, and social chat
2. **Support** - Help requests, questions about using CampusLink, troubleshooting

## Features

### User Experience

- **Tab-based Navigation**: Users can switch between "Direct Messages" and "Community" tabs in the Messages screen
- **Channel Switcher**: Within the Community tab, users can toggle between General and Support channels
- **Real-time Updates**: Messages appear instantly for all users via Supabase real-time subscriptions
- **User Attribution**: Each message shows the sender's name and avatar (except for own messages)
- **Date Headers**: Messages are grouped by date for better readability
- **Timestamp Display**: Each message shows the time it was sent
- **Empty States**: Helpful messages when no messages exist in a channel
- **Auto-scroll**: Automatically scrolls to the latest message when new messages arrive

### Technical Implementation

#### Database Schema

**Table**: `forum_messages`

```sql
CREATE TABLE public.forum_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  channel text NOT NULL CHECK (channel IN ('general', 'support')),
  sender_id uuid NOT NULL REFERENCES users(id),
  content text NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone
);
```

**Indexes**:
- `idx_forum_messages_channel` - Optimizes channel-based queries
- `idx_forum_messages_sender` - Optimizes sender lookups

#### Row Level Security (RLS)

1. **Read**: Anyone can read forum messages (public access)
2. **Create**: Only authenticated users can post messages
3. **Update**: Users can update their own messages (future edit feature)
4. **Delete**: Users can delete their own messages (future delete feature)

#### React Native Components

**Files Created**:
- `mobile/src/types/forum.ts` - TypeScript types for forum messages
- `mobile/src/services/forumService.ts` - Service layer for forum API calls
- `mobile/src/screens/messages/CommunityForumScreen.tsx` - Main community forum UI
- `mobile/src/screens/messages/ConversationsScreen.tsx` - Updated with tab switcher

**Key Components**:

1. **CommunityForumScreen**
   - Channel tabs (General/Support)
   - Message list with date headers
   - Message input with send button
   - Real-time message subscription
   - Auto-scroll to latest message

2. **ConversationsScreen** (Updated)
   - Tab switcher for Messages/Community
   - Conditional rendering based on active tab
   - Haptic feedback on tab changes

#### Service Layer

**forumService.ts** provides:
- `getForumMessages(channel, limit)` - Fetch messages for a channel
- `sendForumMessage(channel, content)` - Send a new message
- `subscribeToForumMessages(channel, callback)` - Real-time subscription

#### Type Safety

**ForumMessage Interface**:
```typescript
interface ForumMessage {
  id: string;
  channel: ForumChannel;
  sender_id: string;
  content: string;
  created_at: string;
  updated_at: string | null;
  sender?: User | null;
}
```

**ForumChannel Type**:
```typescript
type ForumChannel = 'general' | 'support';
```

## Setup Instructions

### 1. Database Migration

Run the SQL migration in Supabase SQL Editor:

```bash
# File: docs/sql/create_forum_messages.sql
```

This creates:
- `forum_messages` table
- Indexes for performance
- RLS policies for security

### 2. Verify RLS Policies

Ensure the following policies are active:
- ✅ Anyone can read forum messages
- ✅ Authenticated users can create forum messages
- ✅ Users can update their own messages
- ✅ Users can delete their own messages

### 3. Test the Feature

1. Open the app
2. Navigate to Messages tab
3. Tap "Community" at the top
4. Switch between General and Support channels
5. Send a test message
6. Verify messages appear in real-time

## UI/UX Design

### Layout

```
┌─────────────────────────────┐
│ Community              [↻]  │ ← Header
├─────────────────────────────┤
│ [General] [Support]         │ ← Channel tabs
├─────────────────────────────┤
│                             │
│     Today                   │
│                             │
│  ┌──────────────┐          │
│  │ John Doe     │          │ ← Other user message
│  │ Hey everyone!│          │
│  │ 10:15 AM     │          │
│  └──────────────┘          │
│                             │
│          ┌──────────────┐  │
│          │ Hello there! │  │ ← Own message
│          │ 10:16 AM     │  │
│          └──────────────┘  │
│                             │
├─────────────────────────────┤
│ [Type message...      ] [↑] │ ← Input bar
└─────────────────────────────┘
```

### Color Scheme

- **Own messages**: Primary blue background (#007AFF)
- **Other messages**: Light gray background
- **Active tab**: Primary blue text and underline
- **Inactive tab**: Gray text
- **Send button**: Enabled = blue, Disabled = gray

### Interactions

- **Tap channel tab**: Switch channel with haptic feedback
- **Tap send**: Send message with haptic feedback
- **New message arrives**: Auto-scroll to bottom
- **Long press message**: (Future) Show options to edit/delete

## Future Enhancements

### Planned Features

1. **Message Reactions**
   - Add emoji reactions to messages
   - Show reaction counts

2. **Message Editing**
   - Allow users to edit their own messages
   - Show "edited" indicator

3. **Message Deletion**
   - Allow users to delete their own messages
   - Soft delete with "Message deleted" placeholder

4. **Rich Text**
   - Support markdown formatting
   - Display links as clickable

5. **Media Support**
   - Allow image uploads
   - Support GIFs and emojis

6. **Notifications**
   - Push notifications for @mentions
   - Notification badges for unread messages

7. **Moderation**
   - Report inappropriate messages
   - Admin tools to delete/ban users

8. **Search**
   - Search messages within channels
   - Filter by user or date

9. **Thread Replies**
   - Reply to specific messages
   - Show threaded conversations

10. **Custom Channels**
    - Allow admins to create new channels
    - Channel-specific permissions

### Technical Improvements

1. **Pagination**
   - Load older messages on scroll
   - Limit initial message load

2. **Caching**
   - Cache messages locally
   - Reduce API calls

3. **Typing Indicators**
   - Show when users are typing
   - Real-time presence

4. **Message Delivery Status**
   - Show sent/delivered/read status
   - Retry failed messages

## Security Considerations

### Current Implementation

- **Authentication Required**: Users must be logged in to send messages
- **User Verification**: Email verification required before posting
- **Rate Limiting**: (Planned) Prevent spam by limiting messages per minute
- **Content Filtering**: (Planned) Block offensive content

### Best Practices

1. Always validate user authentication before posting
2. Sanitize message content to prevent XSS attacks
3. Implement rate limiting to prevent spam
4. Add content moderation for inappropriate messages
5. Log all message activity for audit trails

## Performance Optimization

### Current Optimizations

1. **Database Indexes**: Fast queries on channel and created_at
2. **Message Limit**: Load only last 100 messages by default
3. **Real-time Subscriptions**: Efficient WebSocket connections
4. **Auto-scroll**: Only scroll on new messages

### Recommended Improvements

1. **Virtual List**: Use FlatList with `windowSize` optimization
2. **Message Pagination**: Implement load-more for older messages
3. **Image Optimization**: Compress uploaded images
4. **Debouncing**: Debounce typing indicators

## Troubleshooting

### Common Issues

**Issue**: Messages not appearing in real-time
- **Solution**: Check Supabase real-time settings are enabled
- **Solution**: Verify RLS policies allow SELECT for all users

**Issue**: Can't send messages
- **Solution**: Verify user is authenticated
- **Solution**: Check RLS policy allows INSERT for authenticated users

**Issue**: Old messages not loading
- **Solution**: Increase limit in getForumMessages call
- **Solution**: Implement pagination

**Issue**: Messages appear out of order
- **Solution**: Ensure database query orders by created_at ASC
- **Solution**: Check device time zone settings

## API Reference

### getForumMessages(channel, limit)

Fetches messages for a specific channel.

**Parameters**:
- `channel` (ForumChannel): 'general' or 'support'
- `limit` (number): Maximum messages to fetch (default: 100)

**Returns**: `Promise<ForumMessage[]>`

**Example**:
```typescript
const messages = await getForumMessages('general', 50);
```

### sendForumMessage(channel, content)

Sends a new message to a channel.

**Parameters**:
- `channel` (ForumChannel): 'general' or 'support'
- `content` (string): Message content

**Returns**: `Promise<ForumMessage>`

**Example**:
```typescript
const newMessage = await sendForumMessage('support', 'How do I reset my password?');
```

### subscribeToForumMessages(channel, callback)

Subscribes to real-time messages in a channel.

**Parameters**:
- `channel` (ForumChannel): 'general' or 'support'
- `callback` (function): Called when a new message arrives

**Returns**: `() => void` (unsubscribe function)

**Example**:
```typescript
const unsubscribe = subscribeToForumMessages('general', (message) => {
  console.log('New message:', message);
});

// Later: unsubscribe()
```

## Related Documentation

- [Messaging System](./MESSAGING_SYSTEM.md)
- [Real-time Features](./REALTIME_FEATURES.md)
- [Database Schema](../databaseinfoforcontext/databaseinfoforcontext.md)
- [Security & RLS](../guides/SECURITY.md)

---

**Version**: 1.0.0  
**Last Updated**: January 3, 2025  
**Author**: CampusLink Team

