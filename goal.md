# goal.md

## 🎯 North-Star Objective  
Build and maintain a **production-grade iOS Campus Marketplace** that lets college students safely buy and sell goods & services on-campus with **zero friction**—from sign-up to checkout—in under **60 seconds** on a fresh install.

---

### What Cursor Should Always Optimize For
1. **Student Trust & Safety**  
   - .edu-only sign-up, clear identity cues, and rock-solid data privacy.
2. **Speed to Value**  
   - First listing posted or first purchase completed within one minute.
3. **Production Quality**  
   - Tested, lint-clean, crash-free; CI must pass on every commit.
4. **Scalable Architecture**  
   - Modular MVVM (Swift) + Supabase with RLS + Stripe Checkout that can scale from 10 to 10 000 users without rewrites.
5. **Low Cognitive Load**  
   - Minimal UI; black screen with five key actions max on any flow.
6. **Iterability**  
   - Clear boundaries between Core, Data, Domain, and UI layers so features can ship in small pull requests.
7. **Secure Payments**  
   - Stripe-hosted Checkout first; upgrade to Connect when peer-to-peer volume justifies it.

> **If a proposed change doesn’t make the user safer, faster, or happier—skip it.**
