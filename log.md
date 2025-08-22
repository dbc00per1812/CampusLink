# CampusLink Development Log

## Sprint 1

### p1: Setup

#### s1: Initialize Xcode project (SwiftUI for speed)
- User has already completed this step.

#### s2: Connect project to Supabase (set up environment keys securely)
- I will add the Supabase dependency information to the user.
- I will then initialize the Supabase client in `CampusLinkTestApp.swift` using the credentials from `Secrets.swift`. This will make the client available throughout the application.
- **Completed**: Initialized Supabase client in `CampusLinkTestApp.swift`.

#### s3: Configure Auth & Database in Supabase (users, listings, messages tables)
- Instructed the user to create `users`, `listings`, and `messages` tables in the Supabase dashboard as per the schema in `Plan.md`. Waiting for user to complete this step.
- **Completed**: Database tables and triggers set up successfully.

### p2: Auth & Profiles

#### s1: Implement Supabase auth (signup/login with email & password)
- **Completed**: Full authentication flow implemented with reactive session management.

#### s2: Restrict to .edu emails
- **Completed**: Email validation ensures only .edu addresses can sign up.

#### s3: Create basic profile screen (name, email, profile picture upload)
- **Completed**: Comprehensive profile customization page with photo upload to Supabase Storage.

## Repository Maintenance

### Git Reset (Current Session)
- **Action**: Reset repository to last commit (origin/main) due to unfixable state
- **Commands executed**:
  - `git reset --hard origin/main` - Reset to HEAD commit 28ab6e0
  - `git clean -fd` - Removed untracked files (InputValidation.swift, PaginationHelper.swift, audit.md)
- **Result**: Repository restored to clean state matching remote main branch
- **Next**: User to reopen Xcode project

## Current Status
- ✅ **Authentication System**: Complete sign-up/sign-in flow with automatic redirect
- ✅ **Profile Management**: Users can edit name, bio, and upload profile pictures
- ✅ **Security**: RLS policies, .edu email validation, secure credential storage
- ✅ **Navigation**: Reactive UI that responds to authentication state changes
- ✅ **Database Integration**: Automatic profile creation via triggers

## Next Steps
Ready to move on to **p3: Marketplace Listings** - building the core marketplace functionality for buying and selling items on campus.

## Phase 5: Messaging (Realtime) Implementation

### Database Setup
- **Completed**: Converted conversation participant IDs from text to UUID with proper foreign keys
- **Completed**: Added unique constraint on (buyer_id, seller_id, listing_id) to prevent duplicate conversations
- **Completed**: Added index on messages (conversation_id, created_at) for performance
- **Completed**: Enabled Row Level Security with participant-only access policies
- **Completed**: Enabled Realtime publication for messages table
- **Completed**: Added trigger to update conversation timestamps on new messages

### iOS Implementation

#### Task 5.1: Swift Models
- **Completed**: Created `MessagingModels.swift` with Conversation and Message structs
- **Features**: 
  - Full Codable/Identifiable conformance for Supabase integration
  - Helper methods for participant identification
  - Display name and preview text generation

#### Task 5.2: ViewModels
- **Completed**: Created `ConversationListViewModel` for managing conversations
  - Fetches all conversations for current user
  - Implements getOrCreateConversation for starting new chats
  - Handles both RPC and fallback manual creation
- **Completed**: Created `ChatViewModel` for individual chat management
  - Loads messages for conversation
  - Sends new messages with optimistic UI updates
  - Implements Supabase Realtime subscription for live updates
  - Proper cleanup of subscriptions on deinit

#### Task 5.3: UI Views
- **Completed**: Built `ConversationListView` with:
  - List of all user conversations
  - Empty state for no conversations
  - Pull-to-refresh functionality
  - Navigation to individual chats
- **Completed**: Built `ChatView` with:
  - Message bubbles with sender differentiation
  - Listing info bar showing item details
  - Real-time message updates
  - Auto-scrolling to latest messages
  - Message input with send button

#### Task 5.4: Integration
- **Completed**: Wired "Contact Seller" button in `ListingDetailView`
  - Creates or finds existing conversation
  - Opens ChatView in sheet presentation
  - Handles errors gracefully
- **Completed**: Added Messages tab to `MainTabView`
  - Replaced unused Search tab with Messages
  - Users can now access all conversations from main navigation

#### Task 5.5: Realtime Features
- **Completed**: Implemented Supabase Realtime subscriptions
  - Live message updates in active chats
  - Automatic UI refresh on new messages
  - Proper subscription cleanup to prevent memory leaks

### Technical Highlights
- **Architecture**: MVVM pattern with clear separation of concerns
- **Security**: All operations respect RLS policies, sender_id enforced as auth.uid()
- **Performance**: Optimistic UI updates, indexed queries, pagination-ready
- **UX**: Haptic feedback, loading states, error handling, empty states

### Ready for Testing
The messaging system is fully implemented and ready for end-to-end testing. Users can:
1. Contact sellers from listing detail pages
2. View all conversations in the Messages tab
3. Send and receive messages in real-time
4. See listing context within conversations 

## Phase 7: Compliance & Settings

### Task 7.1 — Implement Delete Account flow
- Implemented `SettingsView` with Sign Out and Delete Account actions behind a gear button in `ProfileTabView`.
- Refactored `AuthManager.deleteCurrentUser()` to call Supabase Edge Function `delete_user` with Bearer token; removed body user_id.
- Created secure Edge Function `supabase/functions/delete_user/index.ts`:
  - Verifies caller using `SUPABASE_ANON_KEY` and the provided JWT.
  - Allows only self-deletion (uses token's `sub`).
  - Uses service role client solely to `admin.auth.admin.deleteUser()` and to clean up `users` table rows.
  - Robust error handling and consistent JSON responses.
- Deleted obsolete `ProfileView.swift`; consolidated profile UI into `ProfileTabView.swift` and migrated needed models.
- Fixed duplicate `SignUpView.swift` issue and ensured exhaustive error handling.
- Verified UX: on successful deletion, app signs out and returns to `WelcomeView` via session change in `ContentView`.

Status: Completed and deployed. Ready for review and push.

### Task 7.2 — Add basic Report User UI
- Created `ReportModels.swift` with comprehensive report types and status enums
- Implemented `ReportUserView` with:
  - Report type selection (inappropriate content, scam, harassment, spam, fake profile, other)
  - Detailed description field with validation (minimum 10 characters)
  - Clear display of what's being reported (user and/or listing)
  - Important information about anonymous reporting and review timeframes
  - Success/error handling with user feedback
- Added report buttons to:
  - `ListingDetailView`: Flag icon in toolbar for reporting listings/sellers (hidden for own listings)
  - `ChatView`: Flag icon in toolbar for reporting users in conversations
- Both views present `ReportUserView` as a sheet with proper context
- Reports are submitted to Supabase `reports` table with reporter ID, reported user/listing, type, and description

Status: Completed. Database table already exists in Supabase.

## Phase 8: QA & Performance

### Task 8.1 — Implement pagination in HomeTabView
- Added pagination state variables: `currentPage`, `hasMorePages`, `isLoadingMore`, `pageSize` (10 items)
- Implemented Supabase `.range()` queries to fetch listings in batches
- Added infinite scroll: loads more when user reaches last 3 items
- Added pull-to-refresh functionality with `.refreshable` modifier
- Added visual indicators:
  - Loading spinner at bottom when fetching more
  - "You've reached the end" message when no more pages
- Three main functions:
  - `loadListings()`: Initial load of first page
  - `loadMoreListings()`: Fetches next page when scrolling
  - `refreshListings()`: Resets and reloads from start
- Prevents duplicate requests with `isLoadingMore` guard

Status: Completed. Pagination fully functional with smooth UX. 