# Debug Campus Filter

## Test Right Now:

1. **Build and run the app** (I just added logging)
2. **Search for "Purdue"** 
3. **Look at Xcode console**

## What You Should See in Console:

```
📱 SearchService: Received X results from database
📱 SearchService: Before campus filter: X results
🔍 Search Campus Filter: ENABLED, filtering X results...
🔍 Search Campus Filter: Current user campus: Indiana University Bloomington
🔍 Search Campus Filter: Filtered X search results to Y for campus Indiana University...
📱 SearchService: After campus filter: Y results
```

---

## If You See That:

The filter IS running. The issue might be:
- Your user profile has wrong campus
- The Purdue tickets somehow have IU campus set

---

## If You DON'T See Those Messages:

The filter isn't running. Could be:
- AppConfig.enableCampusFilter is false
- Filter is crashing silently
- Search isn't going through SearchService

---

**Run the app, search "Purdue", send me the FULL Xcode console output and I'll fix it!**

