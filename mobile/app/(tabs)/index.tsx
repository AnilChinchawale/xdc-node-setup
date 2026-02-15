import { View, Text, StyleSheet, ScrollView, RefreshControl } from 'react-native';
import { useQuery } from '@tanstack/react-query';
import { api } from '@/lib/api';
import { StatusCard } from '@/components/StatusCard';
import { NetworkStats } from '@/components/NetworkStats';
import { QuickActions } from '@/components/QuickActions';

export default function DashboardScreen() {
  const {
    data: overview,
    isLoading,
    refetch,
    isRefetching,
  } = useQuery({
    queryKey: ['dashboard'],
    queryFn: api.getDashboard,
    refetchInterval: 30000, // Auto-refresh every 30s
  });

  return (
    <ScrollView
      style={styles.container}
      refreshControl={
        <RefreshControl
          refreshing={isRefetching}
          onRefresh={refetch}
          tintColor="#4ade80"
        />
      }
    >
      <View style={styles.header}>
        <Text style={styles.title}>XDC Network</Text>
        <Text style={styles.subtitle}>Node Monitoring Dashboard</Text>
      </View>

      {isLoading ? (
        <View style={styles.loading}>
          <Text style={styles.loadingText}>Loading...</Text>
        </View>
      ) : (
        <>
          {/* Overall Status */}
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>Status Overview</Text>
            <View style={styles.statusGrid}>
              <StatusCard
                title="Total Nodes"
                value={overview?.totalNodes ?? 0}
                icon="server"
                color="#3b82f6"
              />
              <StatusCard
                title="Online"
                value={overview?.onlineNodes ?? 0}
                icon="checkmark-circle"
                color="#4ade80"
              />
              <StatusCard
                title="Syncing"
                value={overview?.syncingNodes ?? 0}
                icon="sync"
                color="#fbbf24"
              />
              <StatusCard
                title="Offline"
                value={overview?.offlineNodes ?? 0}
                icon="close-circle"
                color="#ef4444"
              />
            </View>
          </View>

          {/* Network Stats */}
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>Network Statistics</Text>
            <NetworkStats
              blockHeight={overview?.latestBlock ?? 0}
              networkPeers={overview?.totalPeers ?? 0}
              avgSyncTime={overview?.avgSyncTime ?? 'N/A'}
            />
          </View>

          {/* Quick Actions */}
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>Quick Actions</Text>
            <QuickActions />
          </View>
        </>
      )}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0f0f1a',
  },
  header: {
    padding: 20,
    paddingTop: 10,
  },
  title: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#fff',
  },
  subtitle: {
    fontSize: 14,
    color: '#9ca3af',
    marginTop: 4,
  },
  section: {
    padding: 20,
    paddingTop: 0,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: '#fff',
    marginBottom: 12,
  },
  statusGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 12,
  },
  loading: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 40,
  },
  loadingText: {
    color: '#9ca3af',
    fontSize: 16,
  },
});
