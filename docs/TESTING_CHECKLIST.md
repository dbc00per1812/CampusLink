# Performance Testing Checklist
## React Native - Lightning Fast Optimizations

---

## 🧪 Manual Testing Checklist

### Home Screen Performance
- [ ] App launches in < 1 second
- [ ] Home feed loads instantly
- [ ] Blurhash placeholders appear immediately
- [ ] Images fade in smoothly (200ms transition)
- [ ] Scrolling is butter smooth (60 FPS)
- [ ] No stuttering or jank while scrolling
- [ ] Images appear before they're fully on screen (prefetch working)
- [ ] Memory stays under 150 MB during extended scrolling
- [ ] Scrolling back up shows cached images instantly

### Image Loading
- [ ] First image loads in < 300ms
- [ ] Subsequent images from cache < 100ms
- [ ] Blurhash placeholders look professional
- [ ] No broken image icons
- [ ] Images don't flicker or jump
- [ ] Image transitions are smooth
- [ ] Gallery images load progressively
- [ ] Thumbnails load instantly

### Navigation Performance
- [ ] Screen transitions are instant
- [ ] Back button is responsive
- [ ] Tab switching is immediate
- [ ] Detail screen opens quickly
- [ ] Cached screens appear instantly
- [ ] No loading spinners on cached data

### Data Fetching
- [ ] Pull to refresh works smoothly
- [ ] New listings appear instantly
- [ ] Infinite scroll is seamless
- [ ] No duplicate items in feed
- [ ] Filter changes are instant
- [ ] Search is responsive (debounced)
- [ ] Offline mode shows cached data

### Memory & Battery
- [ ] Memory usage < 150 MB during normal use
- [ ] Memory doesn't keep growing
- [ ] App doesn't crash after extended use
- [ ] Battery drain is reasonable
- [ ] No excessive heat generation
- [ ] App is responsive during background tasks

---

## 📊 Performance Metrics Testing

### Target Metrics:
```
✅ Initial Load Time: < 1 second
✅ Image Load Time: < 300ms
✅ Scroll FPS: 55-60 fps
✅ Memory Usage: < 150 MB
✅ Network Requests: < 20 per session
✅ Cache Hit Rate: > 80%
```

### Testing Tools:

#### 1. React DevTools Profiler
```bash
# Enable profiler
npm start -- --devtools

# Test Actions:
- Record scroll performance
- Check component render times
- Identify slow components
- Verify memoization working
```

**Pass Criteria:**
- [ ] No component takes > 16ms to render
- [ ] List items render in < 5ms
- [ ] Memoized components don't re-render unnecessarily

#### 2. Flipper Performance Monitor
```bash
# Install Flipper Desktop
# Connect to running app
# Enable Performance plugin

# Monitor:
- FPS during scroll
- Memory usage over time
- Network requests
- Image cache hits
```

**Pass Criteria:**
- [ ] FPS stays 55-60 during scroll
- [ ] Memory is stable (no leaks)
- [ ] Cache hit rate > 80%
- [ ] Network requests < 20 per session

#### 3. Xcode Instruments (iOS)
```bash
# Build release version
npx react-native run-ios --configuration Release

# Use Instruments to profile:
- Time Profiler
- Allocations
- Network
- Energy Log
```

**Pass Criteria:**
- [ ] No excessive CPU usage
- [ ] Memory allocations are stable
- [ ] Network usage is minimal
- [ ] Energy impact is low

#### 4. Android Profiler
```bash
# Build release version
npx react-native run-android --variant=release

# Use Android Studio Profiler:
- CPU Profiler
- Memory Profiler
- Network Profiler
- Energy Profiler
```

**Pass Criteria:**
- [ ] CPU usage < 20% during scroll
- [ ] Memory is stable
- [ ] Network calls are batched
- [ ] Battery usage is normal

---

## 🔍 Code Quality Checklist

### Components Using expo-image
- [ ] `ListingCardModern.tsx` uses expo-image
- [ ] `ListingCard.tsx` uses expo-image
- [ ] `ImageGallery.tsx` uses expo-image
- [ ] `UserAvatar.tsx` uses expo-image
- [ ] All other image components updated

### Cache Policies Set
- [ ] All images have `cachePolicy` prop
- [ ] Listing images use `memory-disk`
- [ ] Avatars use `memory-disk`
- [ ] Gallery images use `memory-disk`
- [ ] Temporary images use appropriate policy

### Blurhash Placeholders
- [ ] All images have blurhash placeholders
- [ ] Placeholders match image type
- [ ] Placeholders look professional
- [ ] Transitions are smooth

### FlatList Optimizations
- [ ] `removeClippedSubviews={true}` set
- [ ] `windowSize` configured
- [ ] `maxToRenderPerBatch` set
- [ ] `initialNumToRender` set
- [ ] `getItemLayout` implemented (if applicable)
- [ ] `keyExtractor` uses unique IDs

### React Query Setup
- [ ] QueryClient configured in App.tsx
- [ ] Cache times are appropriate
- [ ] Stale times are set
- [ ] Retry logic is configured
- [ ] Refetch strategies are set

### Image Prefetching
- [ ] Listings prefetch on load
- [ ] Next page prefetches before scroll
- [ ] Detail images prefetch on tap
- [ ] Prefetch doesn't block UI

### Performance Utilities
- [ ] Search uses debounce
- [ ] Scroll uses throttle
- [ ] Expensive calculations use memoization
- [ ] Background tasks use runAfterInteractions

---

## 🐛 Edge Cases Testing

### Network Conditions
- [ ] Works on fast WiFi
- [ ] Works on slow 3G
- [ ] Works on edge/2G
- [ ] Handles offline gracefully
- [ ] Recovers from network errors
- [ ] Shows appropriate loading states

### Device Variations
- [ ] Works on latest iPhone (15 Pro)
- [ ] Works on older iPhone (XR)
- [ ] Works on latest Android (Pixel 8)
- [ ] Works on older Android (Samsung S9)
- [ ] Works on tablets
- [ ] Works on different screen sizes

### Data Variations
- [ ] Handles empty feed
- [ ] Handles single item
- [ ] Handles 100+ items
- [ ] Handles missing images
- [ ] Handles broken image URLs
- [ ] Handles very long titles

### Memory Pressure
- [ ] Handles low memory warnings
- [ ] Clears cache when needed
- [ ] Doesn't crash on memory pressure
- [ ] Recovers gracefully
- [ ] Shows appropriate warnings

---

## 📱 Device Testing Matrix

### iOS Devices:
- [ ] iPhone 15 Pro (iOS 17)
- [ ] iPhone 14 (iOS 17)
- [ ] iPhone 12 (iOS 16)
- [ ] iPhone XR (iOS 15)
- [ ] iPad Pro (latest)
- [ ] iPad (9th gen)

### Android Devices:
- [ ] Pixel 8 (Android 14)
- [ ] Samsung S23 (Android 14)
- [ ] OnePlus 11 (Android 13)
- [ ] Samsung S10 (Android 12)
- [ ] Budget device (< $300)

---

## 🎯 User Experience Testing

### Perceived Performance
- [ ] App feels instant
- [ ] No waiting for images
- [ ] Smooth transitions
- [ ] No jank or stuttering
- [ ] Professional appearance
- [ ] Matches Instagram quality

### Visual Polish
- [ ] Blurhash placeholders look good
- [ ] Image transitions are smooth
- [ ] No flickering
- [ ] No layout shifts
- [ ] Loading states are subtle
- [ ] Error states are helpful

### Interaction Quality
- [ ] Taps are immediate
- [ ] Scrolling is smooth
- [ ] Pull-to-refresh is satisfying
- [ ] Infinite scroll is seamless
- [ ] Search is responsive
- [ ] Navigation is instant

---

## 📈 Benchmark Comparisons

### Compare Against:
1. **Instagram** - Photo feed performance
2. **OfferUp** - Marketplace listings
3. **Facebook Marketplace** - Image loading
4. **Poshmark** - Feed scrolling

### Metrics to Compare:
- [ ] Initial load time
- [ ] Image load time
- [ ] Scroll smoothness
- [ ] Transition speed
- [ ] Memory usage
- [ ] Battery impact

**Target**: Match or exceed these apps

---

## ✅ Sign-Off Checklist

### Development Complete:
- [ ] All files updated to expo-image
- [ ] All cache policies configured
- [ ] All blurhash placeholders added
- [ ] FlatList optimizations enabled
- [ ] React Query configured
- [ ] Prefetching implemented
- [ ] Performance utilities integrated
- [ ] Documentation complete

### Testing Complete:
- [ ] Manual testing passed
- [ ] Performance metrics met
- [ ] Code quality verified
- [ ] Edge cases handled
- [ ] Device matrix covered
- [ ] User experience validated
- [ ] Benchmarks competitive

### Production Ready:
- [ ] No linter errors
- [ ] No console warnings
- [ ] No memory leaks
- [ ] No crashes
- [ ] Performance targets met
- [ ] Documentation updated
- [ ] Team trained

---

## 🚀 Release Checklist

### Pre-Release:
- [ ] Increment version number
- [ ] Update changelog
- [ ] Run full test suite
- [ ] Profile on real devices
- [ ] Check analytics setup
- [ ] Verify error tracking

### Release:
- [ ] Build release version
- [ ] Test release build
- [ ] Submit to TestFlight (iOS)
- [ ] Submit to Internal Testing (Android)
- [ ] Monitor crash reports
- [ ] Monitor performance metrics

### Post-Release:
- [ ] Monitor user feedback
- [ ] Track performance metrics
- [ ] Watch for crashes
- [ ] Check memory usage
- [ ] Verify improvements
- [ ] Gather analytics

---

## 📊 Success Criteria

### Must Have (P0):
- ✅ All images use expo-image
- ✅ Cache policies configured
- ✅ FlatList optimized
- ✅ No crashes
- ✅ Scroll FPS > 50

### Should Have (P1):
- ✅ Blurhash placeholders
- ✅ React Query caching
- ✅ Image prefetching
- ✅ Memory < 150 MB
- ✅ Load time < 1s

### Nice to Have (P2):
- ⚡ Image load < 200ms
- ⚡ Cache hit rate > 90%
- ⚡ Network requests < 15
- ⚡ Battery usage minimal
- ⚡ Matches Instagram quality

---

## 📝 Notes

### Known Issues:
- None currently

### Future Improvements:
- WebP support
- CDN integration
- Code splitting
- Virtual lists

### Feedback:
- [ ] Collect user feedback
- [ ] Monitor analytics
- [ ] Track performance
- [ ] Iterate improvements

---

**Last Updated**: January 3, 2026  
**Version**: 1.0.0  
**Status**: Ready for Testing ✅

