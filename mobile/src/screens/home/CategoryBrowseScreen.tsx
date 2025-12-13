// Category Browse Screen - Placeholder
import React from 'react';
import { View, Text, StyleSheet, SafeAreaView } from 'react-native';
import { HomeScreenProps } from '../../navigation/types';
import Colors from '../../utils/colors';

type Props = HomeScreenProps<'CategoryBrowse'>;

const CategoryBrowseScreen: React.FC<Props> = ({ route }) => {
  const { category } = route.params;

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.content}>
        <Text style={styles.title}>{category}</Text>
        <Text style={styles.placeholder}>Category listings coming soon...</Text>
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
    marginBottom: 16,
  },
  placeholder: {
    fontSize: 16,
    color: Colors.textSecondary,
  },
});

export default CategoryBrowseScreen;

