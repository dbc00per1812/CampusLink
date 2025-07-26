# Campus Marketplace – Development Plan

## 1. **Project Overview**
A one-stop mobile platform for college students to buy and sell products & services on-campus.  
Built using **Swift (iOS)** for the frontend and **Supabase** for backend services (auth, database, storage).  

---

## 2. **Core Features (MVP)**
- **User Authentication**  
  - Sign up / Login using Supabase Auth  
  - Email & password (MVP)  
- **Marketplace Listings**  
  - Create listings (title, description, price, category, photo upload)  
  - Browse and search listings (filter by category & price)  
- **Messaging**  
  - Direct messaging between buyers & sellers (basic text chat)  
- **Profile Management**  
  - Update profile info (name, bio, profile photo)  
- **Safety & Verification**  
  - Only .edu emails allowed for sign-up
- **Payments**  
  - Integrate **Stripe Checkout** for transactions  
  - Collect payments into a central marketplace account (Phase 1)  

---

## 3. **Tech Stack**
- **Frontend:** Swift (UIKit/SwiftUI)
- **Backend:** Supabase (PostgreSQL, Auth, Storage, Realtime)
- **Payments:** Stripe (Checkout for simple hosted payments)
- **APIs:** OpenAI (optional future feature for listing recommendations)
- **Tools:** Cursor for development, Xcode for build/simulation

---

## 4. **Sprint 1 ()**
### p1: **Setup**
- s1. Initialize Xcode project (SwiftUI for speed).
- s2. Connect project to Supabase (set up environment keys securely).
- s3. Configure Auth & Database in Supabase (users, listings, messages tables).

### p2: **Auth & Profiles**
- s1. Implement Supabase auth (signup/login with email & password).
- s2. estrict to .edu emails.
- s3. Create basic profile screen (name, email, profile picture upload).

### p3: **Marketplace Listings**
- s1. Build create listing form (title, description, price, category, photo upload).
- s2. Create listing feed (pull from Supabase).
- s3. Add search and filter functionality.

### p4: **Payments (Stripe Checkout)**
- s1. Set up Stripe account and test keys.
- s2. Implement Stripe Checkout for hosted payment flow (link from listing details).
- s3. Store payment metadata (transaction IDs, status) in Supabase.
- s4. Add a "mark as sold" flag for completed transactions.

### p5: **Messaging**
- s1. Set up database schema for messages.
- s2. Build basic chat interface between users.
- s3. Enable real-time messaging with Supabase Realtime.

### p6: **Polish & QA**
- s1. Ensure smooth navigation & error handling.
- s2. Test on multiple devices using Cursor’s simulator & Xcode.

### p7: **Review & Deploy**
- s1. Review UX & fix bugs.
- s2. Prepare for TestFlight deployment for beta testing.

---

## 5. **Database Schema (Supabase)**
**Users Table**
- id (UUID)
- email (text)
- name (text)
- bio (text)
- profile_pic (url)
- created_at (timestamp)

**Listings Table**
- id (UUID)
- user_id (UUID → users.id)
- title (text)
- description (text)
- price (numeric)
- category (text)
- photo (url)
- is_sold (boolean)
- created_at (timestamp)

**Messages Table**
- id (UUID)
- sender_id (UUID → users.id)
- receiver_id (UUID → users.id)
- content (text)
- created_at (timestamp)

**Payments Table**
- id (UUID)
- listing_id (UUID → listings.id)
- buyer_id (UUID → users.id)
- stripe_payment_id (text)
- amount (numeric)
- status (text)
- created_at (timestamp)

---

## 6. **Next Steps (Post-MVP)**
- Push notifications for messages.
- AI-driven pricing suggestions & search optimization.
- Ratings/reviews for buyers & sellers.
- Stripe Connect for direct peer-to-peer payouts (Phase 2).
- Escrow-like transaction flow for improved security.
- Payment dispute resolution system.

---
