import { View, Text, StyleSheet, TouchableOpacity } from 'react-native';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';

type IconName = keyof typeof Ionicons.glyphMap;

interface ActionItem {
  icon: IconName;
  label: string;
  color: string;
  route?: string;
  onPress?: () => void;
}

const actions: ActionItem[] = [
  { icon: 'server', label: 'View Nodes', color: '#3b82f6', route: '/nodes' },
  { icon: 'notifications', label: 'Alerts', color: '#ef4444', route: '/alerts' },
  { icon: 'analytics', label: 'Analytics', color: '#8b5cf6', route: '/analytics' },
  { icon: 'settings', label: 'Settings', color: '#6b7280', route: '/settings' },
];

export function QuickActions() {
  const router = useRouter();

  return (
    <View style={styles.container}>
      {actions.map((action, index) => (
        <TouchableOpacity
          key={index}
          style={styles.actionButton}
          onPress={() => {
            if (action.route) {
              router.push(action.route as any);
            } else if (action.onPress) {
              action.onPress();
            }
          }}
          activeOpacity={0.7}
        >
          <View style={[styles.iconContainer, { backgroundColor: `${action.color}20` }]}>
            <Ionicons name={action.icon} size={24} color={action.color} />
          </View>
          <Text style={styles.label}>{action.label}</Text>
        </TouchableOpacity>
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 12,
  },
  actionButton: {
    flex: 1,
    minWidth: '45%',
    backgroundColor: '#1a1a2e',
    borderRadius: 12,
    padding: 16,
    alignItems: 'center',
  },
  iconContainer: {
    width: 48,
    height: 48,
    borderRadius: 24,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 8,
  },
  label: {
    fontSize: 14,
    color: '#fff',
    fontWeight: '500',
  },
});
