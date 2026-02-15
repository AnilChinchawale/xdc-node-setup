import { View, Text, StyleSheet, FlatList, TouchableOpacity, RefreshControl } from 'react-native';
import { useQuery } from '@tanstack/react-query';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { api } from '@/lib/api';
import type { Node } from '@/types/node';

function NodeItem({ node }: { node: Node }) {
  const router = useRouter();

  const statusColor = {
    online: '#4ade80',
    syncing: '#fbbf24',
    offline: '#ef4444',
  }[node.status] ?? '#6b7280';

  return (
    <TouchableOpacity
      style={styles.nodeCard}
      onPress={() => router.push(`/node/${node.id}`)}
      activeOpacity={0.7}
    >
      <View style={styles.nodeHeader}>
        <View style={styles.nodeInfo}>
          <View style={[styles.statusDot, { backgroundColor: statusColor }]} />
          <Text style={styles.nodeName}>{node.name}</Text>
        </View>
        <Ionicons name="chevron-forward" size={20} color="#6b7280" />
      </View>

      <View style={styles.nodeDetails}>
        <View style={styles.detailRow}>
          <Text style={styles.detailLabel}>Network</Text>
          <Text style={styles.detailValue}>{node.network}</Text>
        </View>
        <View style={styles.detailRow}>
          <Text style={styles.detailLabel}>Block</Text>
          <Text style={styles.detailValue}>#{node.blockHeight.toLocaleString()}</Text>
        </View>
        <View style={styles.detailRow}>
          <Text style={styles.detailLabel}>Peers</Text>
          <Text style={styles.detailValue}>{node.peerCount}</Text>
        </View>
      </View>

      {node.syncProgress !== undefined && node.syncProgress < 100 && (
        <View style={styles.syncBar}>
          <View
            style={[styles.syncProgress, { width: `${node.syncProgress}%` }]}
          />
          <Text style={styles.syncText}>{node.syncProgress.toFixed(1)}% synced</Text>
        </View>
      )}
    </TouchableOpacity>
  );
}

export default function NodesScreen() {
  const {
    data: nodes,
    isLoading,
    refetch,
    isRefetching,
  } = useQuery({
    queryKey: ['nodes'],
    queryFn: api.getNodes,
    refetchInterval: 30000,
  });

  return (
    <View style={styles.container}>
      <FlatList
        data={nodes ?? []}
        keyExtractor={(item) => item.id}
        renderItem={({ item }) => <NodeItem node={item} />}
        contentContainerStyle={styles.list}
        refreshControl={
          <RefreshControl
            refreshing={isRefetching}
            onRefresh={refetch}
            tintColor="#4ade80"
          />
        }
        ListEmptyComponent={
          <View style={styles.empty}>
            <Ionicons name="server-outline" size={48} color="#6b7280" />
            <Text style={styles.emptyText}>
              {isLoading ? 'Loading nodes...' : 'No nodes configured'}
            </Text>
            <Text style={styles.emptySubtext}>
              Add nodes via the SkyNet dashboard
            </Text>
          </View>
        }
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0f0f1a',
  },
  list: {
    padding: 16,
    gap: 12,
  },
  nodeCard: {
    backgroundColor: '#1a1a2e',
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
  },
  nodeHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 12,
  },
  nodeInfo: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  statusDot: {
    width: 10,
    height: 10,
    borderRadius: 5,
  },
  nodeName: {
    fontSize: 18,
    fontWeight: '600',
    color: '#fff',
  },
  nodeDetails: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  detailRow: {
    alignItems: 'center',
  },
  detailLabel: {
    fontSize: 12,
    color: '#6b7280',
    marginBottom: 2,
  },
  detailValue: {
    fontSize: 14,
    color: '#fff',
    fontWeight: '500',
  },
  syncBar: {
    marginTop: 12,
    height: 20,
    backgroundColor: '#2d2d44',
    borderRadius: 10,
    overflow: 'hidden',
    position: 'relative',
  },
  syncProgress: {
    height: '100%',
    backgroundColor: '#4ade80',
    borderRadius: 10,
  },
  syncText: {
    position: 'absolute',
    width: '100%',
    textAlign: 'center',
    lineHeight: 20,
    fontSize: 12,
    color: '#fff',
    fontWeight: '500',
  },
  empty: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 40,
    marginTop: 100,
  },
  emptyText: {
    fontSize: 18,
    color: '#fff',
    marginTop: 16,
  },
  emptySubtext: {
    fontSize: 14,
    color: '#6b7280',
    marginTop: 8,
  },
});
