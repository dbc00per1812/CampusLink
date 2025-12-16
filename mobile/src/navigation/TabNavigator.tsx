// Main Tab Navigator
import React from 'react';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { Ionicons } from '@expo/vector-icons';
import { MainTabParamList, PostStackParamList, MessagesStackParamList, WalletStackParamList, ProfileStackParamList } from './types';
import Colors from '../utils/colors';
import { useOrderMonitor } from '../context/OrderMonitorContext';

// Navigators
import HomeNavigator from './HomeNavigator';

// Screens (will be imported as we create them)
import CreateListingScreen from '../screens/post/CreateListingScreen';
import ConversationsScreen from '../screens/messages/ConversationsScreen';
import ChatScreen from '../screens/messages/ChatScreen';
import OrdersScreen from '../screens/orders/OrdersScreen';
import OrderDetailScreen from '../screens/orders/OrderDetailScreen';
import ProfileScreen from '../screens/profile/ProfileScreen';
import SettingsScreen from '../screens/profile/SettingsScreen';
import MyListingsScreen from '../screens/profile/MyListingsScreen';
import EditProfileScreen from '../screens/profile/EditProfileScreen';
import WalletScreen from '../screens/wallet/WalletScreen';
import PayoutRequestScreen from '../screens/wallet/PayoutRequestScreen';
import PayoutHistoryScreen from '../screens/wallet/PayoutHistoryScreen';

const Tab = createBottomTabNavigator<MainTabParamList>();

// Post Stack
const PostStack = createNativeStackNavigator<PostStackParamList>();
const PostNavigator: React.FC = () => (
  <PostStack.Navigator screenOptions={{ headerShown: false }}>
    <PostStack.Screen name="CreateListing" component={CreateListingScreen} />
  </PostStack.Navigator>
);

// Messages Stack
const MessagesStack = createNativeStackNavigator<MessagesStackParamList>();
const MessagesNavigator: React.FC = () => (
  <MessagesStack.Navigator
    screenOptions={{
      headerStyle: { backgroundColor: Colors.background },
      headerTintColor: Colors.textPrimary,
      headerShadowVisible: false,
      headerBackTitle: 'back',
    }}
  >
    <MessagesStack.Screen
      name="ConversationsList"
      component={ConversationsScreen}
      options={{ headerShown: false }}
    />
    <MessagesStack.Screen
      name="Chat"
      component={ChatScreen}
      options={{ headerShown: false }}
    />
  </MessagesStack.Navigator>
);

// Wallet Stack
const WalletStack = createNativeStackNavigator<WalletStackParamList>();
const WalletNavigator: React.FC = () => (
  <WalletStack.Navigator
    screenOptions={{
      headerStyle: { backgroundColor: Colors.background },
      headerTintColor: Colors.textPrimary,
      headerShadowVisible: false,
      headerBackTitle: 'back',
    }}
  >
    <WalletStack.Screen
      name="WalletMain"
      component={WalletScreen}
      options={{ title: 'Wallet', headerShown: false }}
    />
    <WalletStack.Screen
      name="PayoutRequest"
      component={PayoutRequestScreen}
      options={{ title: 'Request Payout' }}
    />
    <WalletStack.Screen
      name="PayoutHistory"
      component={PayoutHistoryScreen}
      options={{ title: 'Payout History' }}
    />
    <WalletStack.Screen
      name="OrdersList"
      component={OrdersScreen}
      options={{ title: 'Orders' }}
    />
    <WalletStack.Screen
      name="OrderDetail"
      component={OrderDetailScreen}
      options={{ title: 'Order Details' }}
    />
  </WalletStack.Navigator>
);

// Profile Stack
const ProfileStack = createNativeStackNavigator<ProfileStackParamList>();
const ProfileNavigator: React.FC = () => (
  <ProfileStack.Navigator
    screenOptions={{
      headerStyle: { backgroundColor: Colors.background },
      headerTintColor: Colors.textPrimary,
      headerShadowVisible: false,
      headerBackTitle: 'back',
    }}
  >
    <ProfileStack.Screen
      name="ProfileMain"
      component={ProfileScreen}
      options={{ headerShown: false }}
    />
    <ProfileStack.Screen
      name="Settings"
      component={SettingsScreen}
      options={{ headerShown: false }}
    />
    <ProfileStack.Screen
      name="MyListings"
      component={MyListingsScreen}
      options={{ title: 'My Listings' }}
    />
    <ProfileStack.Screen
      name="EditProfile"
      component={EditProfileScreen}
      options={{ title: 'Edit Profile' }}
    />
  </ProfileStack.Navigator>
);

// Tab icon helper
type IconName = keyof typeof Ionicons.glyphMap;
const getTabIcon = (routeName: keyof MainTabParamList, focused: boolean): IconName => {
  const icons: Record<keyof MainTabParamList, { active: IconName; inactive: IconName }> = {
    Home: { active: 'home', inactive: 'home-outline' },
    Messages: { active: 'chatbubbles', inactive: 'chatbubbles-outline' },
    Post: { active: 'add-circle', inactive: 'add-circle-outline' },
    Wallet: { active: 'wallet', inactive: 'wallet-outline' },
    Profile: { active: 'person', inactive: 'person-outline' },
  };
  return focused ? icons[routeName].active : icons[routeName].inactive;
};

export const TabNavigator: React.FC = () => {
  const { activeOrderCount } = useOrderMonitor();
  
  return (
    <Tab.Navigator
      screenOptions={({ route }) => ({
        headerShown: false,
        tabBarIcon: ({ focused, color, size }) => {
          const iconName = getTabIcon(route.name, focused);
          return <Ionicons name={iconName} size={size} color={color} />;
        },
        tabBarActiveTintColor: Colors.tabActive,
        tabBarInactiveTintColor: Colors.tabInactive,
        tabBarShowLabel: false,
        tabBarStyle: {
          backgroundColor: Colors.background,
          borderTopColor: Colors.border,
          paddingTop: 8,
          height: 70,
        },
      })}
    >
      <Tab.Screen name="Home" component={HomeNavigator} />
      <Tab.Screen name="Messages" component={MessagesNavigator} />
      <Tab.Screen name="Post" component={PostNavigator} options={{ title: 'Sell' }} />
      <Tab.Screen 
        name="Wallet" 
        component={WalletNavigator}
        options={{
          tabBarBadge: activeOrderCount > 0 ? activeOrderCount : undefined,
          tabBarBadgeStyle: {
            backgroundColor: Colors.primary,
            color: '#FFFFFF',
            fontSize: 10,
            minWidth: 18,
            height: 18,
            borderRadius: 9,
            marginTop: 2,
          },
        }}
      />
      <Tab.Screen name="Profile" component={ProfileNavigator} />
    </Tab.Navigator>
  );
};

export default TabNavigator;

