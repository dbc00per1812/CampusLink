// Theme Context - Dark mode support with system preference sync
import React, {
  createContext,
  useContext,
  useState,
  useEffect,
  useCallback,
  useMemo,
  ReactNode,
} from 'react';
import { useColorScheme, StatusBar, Platform } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import Colors, { DarkColors, ColorScheme } from '../utils/colors';

// Theme storage key
const THEME_STORAGE_KEY = '@campuslink_theme';

// Theme mode options
export type ThemeMode = 'light' | 'dark' | 'system';

// Theme context type
interface ThemeContextType {
  // Current theme mode setting
  themeMode: ThemeMode;
  
  // Actual resolved theme (light or dark)
  isDarkMode: boolean;
  
  // Current color palette
  colors: ColorScheme;
  
  // Toggle between light and dark
  toggleTheme: () => void;
  
  // Set specific theme mode
  setThemeMode: (mode: ThemeMode) => void;
}

// Create context with undefined default
const ThemeContext = createContext<ThemeContextType | undefined>(undefined);

// Theme provider props
interface ThemeProviderProps {
  children: ReactNode;
}

// Theme Provider Component
export const ThemeProvider: React.FC<ThemeProviderProps> = ({ children }) => {
  const systemColorScheme = useColorScheme();
  const [themeMode, setThemeModeState] = useState<ThemeMode>('system');
  const [isLoading, setIsLoading] = useState(true);

  // Load saved theme preference on mount
  useEffect(() => {
    const loadTheme = async () => {
      try {
        const savedTheme = await AsyncStorage.getItem(THEME_STORAGE_KEY);
        if (savedTheme && ['light', 'dark', 'system'].includes(savedTheme)) {
          setThemeModeState(savedTheme as ThemeMode);
        }
      } catch (error) {
        console.warn('Failed to load theme preference:', error);
      } finally {
        setIsLoading(false);
      }
    };
    loadTheme();
  }, []);

  // Resolve actual dark mode state
  const isDarkMode = useMemo(() => {
    if (themeMode === 'system') {
      return systemColorScheme === 'dark';
    }
    return themeMode === 'dark';
  }, [themeMode, systemColorScheme]);

  // Get current color palette
  const colors = useMemo(() => {
    return isDarkMode ? DarkColors : Colors;
  }, [isDarkMode]);

  // Update status bar based on theme
  useEffect(() => {
    StatusBar.setBarStyle(isDarkMode ? 'light-content' : 'dark-content', true);
    if (Platform.OS === 'android') {
      StatusBar.setBackgroundColor(colors.background);
    }
  }, [isDarkMode, colors.background]);

  // Set theme mode and persist
  const setThemeMode = useCallback(async (mode: ThemeMode) => {
    setThemeModeState(mode);
    try {
      await AsyncStorage.setItem(THEME_STORAGE_KEY, mode);
    } catch (error) {
      console.warn('Failed to save theme preference:', error);
    }
  }, []);

  // Toggle between light and dark (skips system)
  const toggleTheme = useCallback(() => {
    const newMode = isDarkMode ? 'light' : 'dark';
    setThemeMode(newMode);
  }, [isDarkMode, setThemeMode]);

  // Context value
  const value = useMemo(
    () => ({
      themeMode,
      isDarkMode,
      colors,
      toggleTheme,
      setThemeMode,
    }),
    [themeMode, isDarkMode, colors, toggleTheme, setThemeMode]
  );

  // Show nothing while loading (prevents flash)
  if (isLoading) {
    return null;
  }

  return (
    <ThemeContext.Provider value={value}>
      {children}
    </ThemeContext.Provider>
  );
};

// Custom hook to use theme context
export const useTheme = (): ThemeContextType => {
  const context = useContext(ThemeContext);
  if (context === undefined) {
    throw new Error('useTheme must be used within a ThemeProvider');
  }
  return context;
};

// Hook to get just the colors (convenient shorthand)
export const useColors = (): ColorScheme => {
  const { colors } = useTheme();
  return colors;
};

// Hook to check dark mode state
export const useIsDarkMode = (): boolean => {
  const { isDarkMode } = useTheme();
  return isDarkMode;
};

// Helper hook for creating themed styles
export const useThemedStyles = <T extends object>(
  styleFactory: (colors: ColorScheme, isDark: boolean) => T
): T => {
  const { colors, isDarkMode } = useTheme();
  return useMemo(
    () => styleFactory(colors, isDarkMode),
    [colors, isDarkMode, styleFactory]
  );
};

export default ThemeContext;

