// Navigation Types

import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import type { BottomTabScreenProps } from '@react-navigation/bottom-tabs';
import type { CompositeScreenProps, NavigatorScreenParams } from '@react-navigation/native';

// Legal Document Type
export type LegalDocumentType = 'terms' | 'privacy' | 'community';

// Auth Stack
export type AuthStackParamList = {
  Welcome: undefined;
  SignIn: undefined;
  SignUp: undefined;
  OTPVerification: { email: string; name: string; campus: string };
  InterestSelection: undefined;
  ForgotPassword: undefined;
  ResetPassword: { email: string };
  LegalDocument: { documentType: LegalDocumentType };
};

// Home Stack
export type HomeStackParamList = {
  HomeMain: undefined;
  ListingDetail: { 
    listingId: string;
    returnTo?: 'Chat';
    returnParams?: { conversationId: string };
  };
  PublicProfile: { 
    userId: string;
    returnTo?: 'Chat';
    returnParams?: { conversationId: string };
  };
  CategoryBrowse: { category?: string };
  Search: undefined;
  TransactionGuide: undefined;
};

// Post Stack
export type PostStackParamList = {
  CreateListing: undefined;
  EditListing: { listingId: string };
};

// Messages Stack
export type MessagesStackParamList = {
  ConversationsList: undefined;
  Chat: { 
    conversationId: string;
    returnScreen?: 'ListingDetail' | 'ConversationsList' | 'OrderDetail';
    returnParams?: { listingId?: string; orderId?: string };
  };
};

// Wallet Stack
export type WalletStackParamList = {
  WalletMain: undefined;
  PayoutRequest: undefined;
  PayoutHistory: undefined;
  OrdersList: undefined;
  OrderDetail: { orderId: string };
  PurchaseConfirmation: { orderId: string };
};

// Profile Stack
export type ProfileStackParamList = {
  ProfileMain: undefined;
  Settings: undefined;
  MyListings: undefined;
  MyOffers: undefined;
  OfferDetail: { offerId: string };
  EditProfile: undefined;
  EditInterests: undefined;
  Notifications: undefined;
  BlockedUsers: undefined;
  LegalDocument: { documentType: LegalDocumentType };
};

// Main Tab Navigator
export type MainTabParamList = {
  Home: NavigatorScreenParams<HomeStackParamList>;
  Messages: NavigatorScreenParams<MessagesStackParamList>;
  Post: NavigatorScreenParams<PostStackParamList>;
  Wallet: NavigatorScreenParams<WalletStackParamList>;
  Profile: NavigatorScreenParams<ProfileStackParamList>;
};

// Root Navigator (Auth + Main Tabs)
export type RootStackParamList = {
  Auth: NavigatorScreenParams<AuthStackParamList>;
  Main: NavigatorScreenParams<MainTabParamList>;
};

// Screen Props Types
export type AuthScreenProps<T extends keyof AuthStackParamList> = NativeStackScreenProps<
  AuthStackParamList,
  T
>;

export type HomeScreenProps<T extends keyof HomeStackParamList> = CompositeScreenProps<
  NativeStackScreenProps<HomeStackParamList, T>,
  BottomTabScreenProps<MainTabParamList>
>;

export type PostScreenProps<T extends keyof PostStackParamList> = CompositeScreenProps<
  NativeStackScreenProps<PostStackParamList, T>,
  BottomTabScreenProps<MainTabParamList>
>;

export type MessagesScreenProps<T extends keyof MessagesStackParamList> = CompositeScreenProps<
  NativeStackScreenProps<MessagesStackParamList, T>,
  BottomTabScreenProps<MainTabParamList>
>;

export type WalletScreenProps<T extends keyof WalletStackParamList> = CompositeScreenProps<
  NativeStackScreenProps<WalletStackParamList, T>,
  BottomTabScreenProps<MainTabParamList>
>;

export type ProfileScreenProps<T extends keyof ProfileStackParamList> = CompositeScreenProps<
  NativeStackScreenProps<ProfileStackParamList, T>,
  BottomTabScreenProps<MainTabParamList>
>;

// Utility type for navigation
declare global {
  namespace ReactNavigation {
    interface RootParamList extends RootStackParamList {}
  }
}

