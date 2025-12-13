// Public Profile Screen - Placeholder
import React from 'react';
import { View, Text, StyleSheet, SafeAreaView } from 'react-native';
import { HomeScreenProps } from '../../navigation/types';
import Colors from '../../utils/colors';

type Props = HomeScreenProps<'PublicProfile'>;

const PublicProfileScreen: React.FC<Props> = ({ route }) => {
  const { userId } = route.params;

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.content}>
        <Text style={styles.title}>User Profile</Text>
        <Text style={styles.userId}>ID: {userId}</Text>
        <Text style={styles.placeholder}>Profile details coming soon...</Text>
      </View>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.background,
  },
  content: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 24,
  },
  title: {
    fontSize: 24,
    fontWeight: '700',
    color: Colors.textPrimary,
    marginBottom: 8,
  },
  userId: {
    fontSize: 14,
    color: Colors.textTertiary,
    marginBottom: 16,
  },
  placeholder: {
    fontSize: 16,
    color: Colors.textSecondary,
  },
});

export default PublicProfileScreen;

