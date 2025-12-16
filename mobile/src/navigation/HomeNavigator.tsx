// Home Stack Navigator
import React from 'react';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { HomeStackParamList } from './types';
import Colors from '../utils/colors';

// Screens
import HomeScreen from '../screens/home/HomeScreen';
import ListingDetailScreen from '../screens/home/ListingDetailScreen';
import PublicProfileScreen from '../screens/home/PublicProfileScreen';
import CategoryBrowseScreen from '../screens/home/CategoryBrowseScreen';
import SearchScreen from '../screens/home/SearchScreen';
import TransactionGuideScreen from '../screens/home/TransactionGuideScreen';

const Stack = createNativeStackNavigator<HomeStackParamList>();

export const HomeNavigator: React.FC = () => {
  return (
    <Stack.Navigator
      screenOptions={{
        headerStyle: {
          backgroundColor: Colors.background,
        },
        headerTintColor: Colors.textPrimary,
        headerTitleStyle: {
          fontWeight: '600',
        },
        headerShadowVisible: false,
        headerBackTitleVisible: false,
      }}
    >
      <Stack.Screen
        name="HomeMain"
        component={HomeScreen}
        options={{ headerShown: false }}
      />
      <Stack.Screen
        name="ListingDetail"
        component={ListingDetailScreen}
        options={{ headerShown: false }}
      />
      <Stack.Screen
        name="PublicProfile"
        component={PublicProfileScreen}
        options={{ title: 'Profile' }}
      />
      <Stack.Screen
        name="CategoryBrowse"
        component={CategoryBrowseScreen}
        options={{ headerShown: false }}
      />
      <Stack.Screen
        name="Search"
        component={SearchScreen}
        options={{ title: 'Search' }}
      />
      <Stack.Screen
        name="TransactionGuide"
        component={TransactionGuideScreen}
        options={{ headerShown: false }}
      />
    </Stack.Navigator>
  );
};

export default HomeNavigator;

