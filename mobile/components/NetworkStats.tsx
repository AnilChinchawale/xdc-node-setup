import { View, Text, StyleSheet } from 'react-native';
import { Ionicons } from '@expo/vector-icons';

interface NetworkStatsProps {
  blockHeight: number;
  networkPeers: number;
  avgSyncTime: string;
}

export function NetworkStats({ blockHeight, networkPeers, avgSyncTime }: NetworkStatsProps) {
  return (
    <View style={styles.container}>
      <View style={styles.stat}>
        <Ionicons name="cube-outline" size={24} color="#3b82f6" />
        <View style={styles.statInfo}>
          <Text style={styles.statValue}>{blockHeight.toLocaleString()}</Text>
          <Text style={styles.statLabel}>Latest Block</Text>
        </View>
      </View>

      <View style={styles.divider} />

      <View style={styles.stat}>
        <Ionicons name="git-network-outline" size={24} color="#8b5cf6" />
        <View style={styles.statInfo}>
          <Text style={styles.statValue}>{networkPeers}</Text>
          <Text style={styles.statLabel}>Network Peers</Text>
        </View>
      </View>

      <View style={styles.divider} />

      <View style={styles.stat}>
        <Ionicons name="time-outline" size={24} color="#f59e0b" />
        <View style={styles.statInfo}>
          <Text style={styles.statValue}>{avgSyncTime}</Text>
          <Text style={styles.statLabel}>Avg Sync Time</Text>
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    backgroundColor: '#1a1a2e',
    borderRadius: 12,
    padding: 16,
  },
  stat: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    paddingVertical: 8,
  },
  statInfo: {
    flex: 1,
  },
  statValue: {
    fontSize: 18,
    fontWeight: '600',
    color: '#fff',
  },
  statLabel: {
    fontSize: 12,
    color: '#6b7280',
    marginTop: 2,
  },
  divider: {
    height: 1,
    backgroundColor: '#2d2d44',
    marginVertical: 8,
  },
});
