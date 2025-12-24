# UnifiedHeader Usage Guide

A consistent, reusable header component for all screens in the CampusLink app.

## Features
- ✅ Blue back arrow on the left
- ✅ Centered title/content
- ✅ Optional three-dot menu on the right
- ✅ Haptic feedback on interactions
- ✅ Fully customizable with custom components
- ✅ Subtitle support
- ✅ Consistent styling across the app

## Basic Usage

### 1. Simple Header with Back Button and Title

```tsx
import { UnifiedHeader } from '../../components';

const MyScreen = () => {
  return (
    <View style={{ flex: 1 }}>
      <UnifiedHeader title="Order Details" />
      {/* Rest of your screen content */}
    </View>
  );
};
```

### 2. Header with Back Button and Menu

```tsx
<UnifiedHeader
  title="Chat"
  showMenu={true}
  onMenuPress={() => {
    // Open menu/options
  }}
/>
```

### 3. Header with Subtitle

```tsx
<UnifiedHeader
  title="Abhi D"
  subtitle="Active now"
/>
```

### 4. Header with Custom Right Component (Avatar)

```tsx
import { UserAvatar } from '../../components';

<UnifiedHeader
  title="Abhi D"
  showBackButton={true}
  rightComponent={
    <View style={{ flexDirection: 'row', gap: 12 }}>
      <UserAvatar userId={userId} size={32} />
      <Pressable onPress={() => {}}>
        <Ionicons name="ellipsis-horizontal" size={24} />
      </Pressable>
    </View>
  }
/>
```

### 5. Header with Custom Center Component

```tsx
<UnifiedHeader
  title="Chat" // fallback
  centerComponent={
    <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
      <UserAvatar userId={userId} size={36} />
      <View>
        <Text style={{ fontSize: 17, fontWeight: '600' }}>Abhi D</Text>
        <Text style={{ fontSize: 12, color: '#666' }}>Active now</Text>
      </View>
    </View>
  }
/>
```

### 6. No Back Button (For Root Screens)

```tsx
<UnifiedHeader
  title="Settings"
  showBackButton={false}
/>
```

## Using with React Navigation

### Option 1: Custom Screen Component (Recommended)

```tsx
import { SafeAreaView } from 'react-native-safe-area-context';
import { UnifiedHeader } from '../../components';

const OrderDetailScreen = () => {
  return (
    <SafeAreaView style={{ flex: 1 }} edges={['top']}>
      <UnifiedHeader title="Order Details" />
      <ScrollView>
        {/* Your content */}
      </ScrollView>
    </SafeAreaView>
  );
};
```

### Option 2: Navigation headerShown: false (Clean)

In your navigator:

```tsx
<Stack.Screen
  name="OrderDetail"
  component={OrderDetailScreen}
  options={{ headerShown: false }} // Hide default header
/>
```

Then in your screen:

```tsx
const OrderDetailScreen = () => {
  return (
    <SafeAreaView style={{ flex: 1 }} edges={['top']}>
      <UnifiedHeader title="Order Details" />
      {/* Content */}
    </SafeAreaView>
  );
};
```

### Option 3: Custom Navigation Header

```tsx
<Stack.Screen
  name="OrderDetail"
  component={OrderDetailScreen}
  options={{
    header: ({ navigation }) => (
      <SafeAreaView edges={['top']}>
        <UnifiedHeader 
          title="Order Details"
          onBackPress={() => navigation.goBack()}
        />
      </SafeAreaView>
    ),
  }}
/>
```

## Props Reference

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `title` | `string` | Required | Main title text |
| `subtitle` | `string` | `undefined` | Optional subtitle below title |
| `showBackButton` | `boolean` | `true` | Show/hide back arrow |
| `showMenu` | `boolean` | `false` | Show/hide three-dot menu |
| `onBackPress` | `() => void` | `navigation.goBack()` | Custom back button handler |
| `onMenuPress` | `() => void` | `undefined` | Menu button press handler |
| `leftComponent` | `React.ReactNode` | `undefined` | Custom left side component |
| `rightComponent` | `React.ReactNode` | `undefined` | Custom right side component |
| `centerComponent` | `React.ReactNode` | `undefined` | Custom center component |

## Examples by Screen Type

### Chat Screen
```tsx
<UnifiedHeader
  title="Abhi D"
  subtitle="Active now"
  showMenu={true}
  onMenuPress={() => showChatOptions()}
/>
```

### Order Details Screen
```tsx
<UnifiedHeader title="Order Details" />
```

### Profile Screen (No Back Button)
```tsx
<UnifiedHeader
  title="Profile"
  showBackButton={false}
  rightComponent={
    <Pressable onPress={() => navigation.navigate('Settings')}>
      <Ionicons name="settings-outline" size={24} />
    </Pressable>
  }
/>
```

### Listing Detail Screen with Share
```tsx
<UnifiedHeader
  title="Listing"
  rightComponent={
    <Pressable onPress={() => shareListing()}>
      <Ionicons name="share-outline" size={24} />
    </Pressable>
  }
/>
```

## Styling Notes

- Header height: 56px
- Back arrow: Blue (#007AFF - Colors.primary)
- Title: Bold, centered
- Consistent padding and spacing
- Haptic feedback on iOS/Android
- Border bottom for visual separation

