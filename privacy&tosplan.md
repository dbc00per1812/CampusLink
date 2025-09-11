You are Product Counsel + App Store Compliance for a student P2P marketplace iOS app (Swift + Supabase + Stripe Connect). You have read-only access to this repo. Produce two lean, launch-ready legal docs that match what the code actually does and what Apple requires:

GOAL
1) Generate /docs/TERMS.md  (Terms of Service)
2) Generate /docs/PRIVACY.md (Privacy Policy)
3) Generate /docs/APPSTORE_PRIVACY_DIFF.md (delta report between PrivacyInfo.xcprivacy and real data flows)
4) Add links to these in an in-app Settings/About view if not present (SwiftUI), and print the file(s)/paths changed.

BEFORE WRITING
- Scan code for data flows:
  - Supabase schemas (tables, columns, RLS), auth, storage, logs.
  - Stripe/Stripe Connect SDK usage (account types, KYC, payouts, webhooks).
  - Analytics/telemetry/crash reporting (if any).
  - Location, contacts, photos, camera, push notifications.
  - Messaging/DMs and any moderation/reporting endpoints.
- Parse `Info.plist` permissions and `PrivacyInfo.xcprivacy`. List exact keys and purposes.
- Extract the prohibited categories enforced in code (if any) and enumerate missing ones we should add.

DELTA CHECK
- Create /docs/APPSTORE_PRIVACY_DIFF.md summarizing:
  - Data types collected, linked, tracked.
  - Purposes (App Functionality, Fraud Prevention, Analytics, etc.).
  - Any APIs accessed (e.g., location, camera) vs. what’s declared in PrivacyInfo.xcprivacy.
  - Concrete FIXME items to make the manifest and code match.

TERMS.md — REQUIRED SECTIONS (write in concise, plain English)
- Overview: Platform facilitates student-to-student sales of physical goods and services (e.g., tutoring). We are not the seller or employer.
- Eligibility: 18+ only (or verified parental consent flow if detected; default 18+). Campus email may be used for verification.
- Account & Verification: identity/KYC handled by Stripe Connect for sellers; you must keep info accurate.
- Independent Contractors: service providers are independent, not employees/agents. We don’t control prices, schedules, or outcomes.
- Payments & Fees: Stripe Connect as PSP; timing of payouts; our platform fees; chargebacks; refunds are between buyer/seller except where required by law.
- Taxes: sellers are responsible for sales/income taxes; Stripe may issue 1099-K per thresholds.
- Prohibited Items/Services: include (and allow us to expand) → alcohol, tobacco/vapes, drugs/controlled substances, weapons, stolen goods, counterfeit goods, financial instruments, tickets where prohibited by university policy, academic dishonesty/cheating services, explicit content, hazardous materials, medical services/devices, prescription drugs, multi-level marketing, any illegal activity.
- User Conduct & Meetups: safety guidance for in-person exchanges; use campus-approved public spaces; we are not responsible for meetups.
- Listings & Content: you own your content; you grant us a limited license to host/display; DMCA policy and takedown process.
- Disputes Between Users: we are not a party; limited role in payments; Stripe dispute process governs chargebacks.
- Suspension/Termination: our right to remove listings, suspend accounts, or geo-restrict.
- Disclaimer & Limitation of Liability: no warranties; cap liability to the greater of fees paid in last 6 months or $100.
- Indemnity: users agree to defend/indemnify platform for violations.
- Governing Law; Arbitration; Class-Action Waiver: provide toggles/placeholders.
- Changes to Terms; Contact.
- Placeholders to auto-fill:
  - COMPANY_LEGAL_NAME, STATE_OF_ORG, REGISTERED_ADDRESS, SUPPORT_EMAIL, EFFECTIVE_DATE.

PRIVACY.md — REQUIRED SECTIONS (must align to code + manifest)
- Controller: COMPANY_LEGAL_NAME, contact SUPPORT_EMAIL, mailing address.
- What We Collect (bullet list mapped to code): identifiers (name, email, phone), campus email, auth tokens, profile photo, messages/DMs, listing photos, location (if used), device/IP, payment-related identifiers via Stripe (we don’t store full card/bank), logs/analytics.
- Sources of Data: you, your device, Stripe, antifraud tools, crash reporter (if any).
- How We Use Data: account/auth, fraud prevention, payments/payouts, messaging, moderation, safety, support, legal compliance, product analytics (only if detected).
- Sharing: with processors (Supabase, Stripe, analytics/crash tools), with other users (public profile/listings), with law enforcement when required, business transfers. State we do not sell data and do not use it for third-party advertising.
- Data Retention: concrete periods (e.g., messages/listings as long as account active; logs 12–24 months; payout records per tax law).
- Security: RLS, encryption at rest/in transit, least-privilege, webhook secrets.
- Your Rights: access, delete, correct; opt-out of marketing emails; how to exercise rights.
- Children: not intended for under-18; if we learn of a minor, we delete/disable account absent verified consent flow.
- International Transfers (if any); U.S. focus note.
- Changes to Policy; Contact.
- App Store Privacy “Nutrition Label” mapping (table) — declare collected data categories, link/track status, purposes.

IMPLEMENTATION DETAILS
- Auto-insert COMPANY_LEGAL_NAME = "CampusLink Labs, LLC" (changeable), STATE_OF_ORG = "Indiana", REGISTERED_ADDRESS = "TBD", SUPPORT_EMAIL = "support@campuslink.app", EFFECTIVE_DATE = today’s date (ISO).
- Write docs in clean Markdown with H2/H3 sections, bullets, and short paragraphs.
- Where you are uncertain, include a clearly labeled **ASSUMPTIONS** block and **FIXME** tags with the exact file/line(s) to verify.
- At the end of each doc, add a short “Change Log” with version v1.0 and today’s date.

CODE CHANGES
- If Settings/About screen lacks policy links, add:
  - “Terms of Service” → in-app Safari to https://campuslink.app/legal/terms
  - “Privacy Policy” → https://campuslink.app/legal/privacy
  - “Contact Support” → mailto:SUPPORT_EMAIL
- Print a unified diff of any files you modify and list new files created.

OUTPUT
- Commit-style summary listing all created/edited files.
- Then render the full contents of /docs/TERMS.md and /docs/PRIVACY.md and the diff report.
