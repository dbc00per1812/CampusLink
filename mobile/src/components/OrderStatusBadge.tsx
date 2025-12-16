// OrderStatusBadge Component - Status indicator for orders
import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { OrderStatus, OrderStatusDisplay, OrderStatusColor, OrderStatusIcon } from '../types';
import Colors from '../utils/colors';

interface OrderStatusBadgeProps {
  status: OrderStatus;
  size?: 'small' | 'medium' | 'large';
  showIcon?: boolean;
}

const OrderStatusBadge: React.FC<OrderStatusBadgeProps> = ({
  status,
  size = 'medium',
  showIcon = true,
}) => {
  const backgroundColor = OrderStatusColor[status];
  const displayName = OrderStatusDisplay[status];

  const getIconName = (): keyof typeof Ionicons.glyphMap => {
    switch (status) {
      case 'placed':
        return 'cart-outline';
      case 'seller_confirmed':
        return 'checkmark-circle-outline';
      case 'in_progress':
        return 'time-outline';
      case 'completed':
        return 'checkmark-done-outline';
      case 'disputed':
        return 'warning-outline';
      case 'cancelled':
        return 'close-circle-outline';
      case 'refunded':
        return 'arrow-undo-outline';
      default:
        return 'ellipse-outline';
    }
  };

  const getPadding = () => {
    switch (size) {
      case 'small':
        return { paddingVertical: 4, paddingHorizontal: 8 };
      case 'medium':
        return { paddingVertical: 6, paddingHorizontal: 12 };
      case 'large':
        return { paddingVertical: 8, paddingHorizontal: 16 };
    }
  };

  const getFontSize = () => {
    switch (size) {
      case 'small':
        return 11;
      case 'medium':
        return 13;
      case 'large':
        return 15;
    }
  };

  const getIconSize = () => {
    switch (size) {
      case 'small':
        return 12;
      case 'medium':
        return 14;
      case 'large':
        return 18;
    }
  };

  return (
    <View
      style={[
        styles.badge,
        { backgroundColor: `${backgroundColor}20` },
        getPadding(),
      ]}
    >
      {showIcon && (
        <Ionicons
          name={getIconName()}
          size={getIconSize()}
          color={backgroundColor}
          style={styles.icon}
        />
      )}
      <Text style={[styles.text, { color: backgroundColor, fontSize: getFontSize() }]}>
        {displayName}
      </Text>
    </View>
  );
};

const styles = StyleSheet.create({
  badge: {
    flexDirection: 'row',
    alignItems: 'center',
    borderRadius: 20,
    alignSelf: 'flex-start',
  },
  icon: {
    marginRight: 4,
  },
  text: {
    fontWeight: '600',
  },
});

export default OrderStatusBadge;

