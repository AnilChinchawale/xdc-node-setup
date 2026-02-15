import { View, Text, StyleSheet, ScrollView, TouchableOpacity, Alert, RefreshControl } from 'react-native';
import { useLocalSearchParams } from 'expo-router';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Ionicons } from '@expo/vector-icons';
import { api } from '@/lib/api';

export default function NodeDetailScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const queryClient = useQueryClient();

  const {
    data: node,
    isLoading,
    refetch,
    isRefetching,
  } = useQuery({
    queryKey: ['node', id],
    queryFn: () => api.getNode(id!),
    enabled: !!id,
    refetchInterval: 15000,
  });

  const restartMutation = useMutation({
    mutationFn: () => api.restartNode(id!),
    onSuccess: () => {
      Alert.alert('Success', 'Node restart initiated');
      queryClient.invalidateQueries({ queryKey: ['node', id] });
    },
    onError: () => {
      Alert.alert('Error', 'Failed to restart node');
    },
  });

  const addPeerMutation = useMutation({
    mutationFn: (enode: string) => api.addPeer(id!, enode),
    onSuccess: () => {
      Alert.alert('Success', 'Peer added successfully');
      queryClient.invalidateQueries({ queryKey: ['node', id] });
    },
    onError: () => {
      Alert.alert('Error', 'Failed to add peer');
    },
  });

  const handleRestart = () => {
    Alert.alert(
      'Restart Node',
      'Are you sure you want to restart this node?',
      [
        { text: 'Cancel', style: 'cancel' },
        { text: 'Restart', style: 'destructive', onPress: () => restartMutation.mutate() },
      ]
    );
  };

  const handleAddPeer = () => {
    Alert.prompt(
      'Add Peer',
      'Enter the enode URL of the peer',
      [
        { text: 'Cancel', style: 'cancel' },
        { text: 'Add', onPress: (enode) => enode && addPeerMutation.mutate(enode) },
      ],
      'plain-text'
    );
  };

  if (isLoading) {
    return (
      <View style={styles.loading}>
        <Text style={styles.loadingText}>Loading node details...</Text>
      </View>
    );
  }

  if (!node) {
    return (
      <View style={styles.loading}>
        <Text style={styles.loadingText}>Node not found</Text>
      </View>
    );
  }

  const statusColor = {
    online: '#4ade80',
    syncing: '#fbbf24',
    offline: '#ef4444',
  }[node.status] ?? '#6b7280';

  return (
    <ScrollView
      style={styles.container}
      refreshControl={
        <RefreshControl refreshing={isRefetching} onRefresh={refetch} tintColor="#4ade80" />
      }
    >
      {/* Status Header */}
      <View style={styles.header}>
        <View style={styles.statusRow}>
          <View style={[styles.statusBadge, { backgroundColor: statusColor }]}>
            <Text style={styles.statusText}>{node.status.toUpperCase()}</Text>
          </View>
          <Text style={styles.networkBadge}>{node.network}</Text>
        </View>
        <Text style={styles.nodeName}>{node.name}</Text>
        <Text style={styles.nodeHost}>{node.host}</Text>
      </View>

      {/* Sync Progress */}
      {node.syncProgress !== undefined && node.syncProgress < 100 && (
        <View style={styles.syncSection}>
          <View style={styles.syncHeader}>
            <Text style={styles.syncTitle}>Sync Progress</Text>
            <Text style={styles.syncPercent}>{node.syncProgress.toFixed(2)}%</Text>
          </View>
          <View style={styles.syncBar}>
            <View style={[styles.syncFill, { width: `${node.syncProgress}%` }]} />
          </View>
          <Text style={styles.syncInfo}>
            Block {node.currentBlock?.toLocaleString()} of {node.highestBlock?.toLocaleString()}
          </Text>
        </View>
      )}

      {/* Stats Grid */}
      <View style={styles.statsGrid}>
        <View style={styles.statCard}>
          <Ionicons name="cube" size={24} color="#3b82f6" />
          <Text style={styles.statValue}>{node.blockHeight.toLocaleString()}</Text>
          <Text style={styles.statLabel}>Block Height</Text>
        </View>
        <View style={styles.statCard}>
          <Ionicons name="people" size={24} color="#8b5cf6" />
          <Text style={styles.statValue}>{node.peerCount}</Text>
          <Text style={styles.statLabel}>Peers</Text>
        </View>
        <View style={styles.statCard}>
          <Ionicons name="time" size={24} color="#f59e0b" />
          <Text style={styles.statValue}>{node.uptime || 'N/A'}</Text>
          <Text style={styles.statLabel}>Uptime</Text>
        </View>
        <View style={styles.statCard}>
          <Ionicons name="hardware-chip" size={24} color="#ec4899" />
          <Text style={styles.statValue}>{node.cpuUsage ?? 'N/A'}%</Text>
          <Text style={styles.statLabel}>CPU</Text>
        </View>
      </View>

      {/* Node Info */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Node Information</Text>
        <View style={styles.infoCard}>
          <InfoRow label="Version" value={node.version || 'Unknown'} />
          <InfoRow label="Chain ID" value={node.chainId?.toString() || 'Unknown'} />
          <InfoRow label="Protocol" value={node.protocol || 'XDPoS'} />
          <InfoRow label="Data Directory" value={node.dataDir || '/xdcchain'} />
          <InfoRow label="RPC Port" value={node.rpcPort?.toString() || '8545'} />
          <InfoRow label="P2P Port" value={node.p2pPort?.toString() || '30303'} />
        </View>
      </View>

      {/* Quick Actions */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Quick Actions</Text>
        <View style={styles.actionGrid}>
          <TouchableOpacity
            style={[styles.actionButton, styles.actionRestart]}
            onPress={handleRestart}
            disabled={restartMutation.isPending}
          >
            <Ionicons name="refresh" size={24} color="#fff" />
            <Text style={styles.actionButtonText}>Restart Node</Text>
          </TouchableOpacity>
          <TouchableOpacity
            style={[styles.actionButton, styles.actionPeer]}
            onPress={handleAddPeer}
            disabled={addPeerMutation.isPending}
          >
            <Ionicons name="add-circle" size={24} color="#fff" />
            <Text style={styles.actionButtonText}>Add Peer</Text>
          </TouchableOpacity>
        </View>
      </View>

      {/* Recent Logs Preview */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Recent Logs</Text>
        <View style={styles.logsCard}>
          {node.recentLogs?.slice(0, 5).map((log, i) => (
            <Text key={i} style={styles.logLine} numberOfLines={1}>
              {log}
            </Text>
          )) ?? (
            <Text style={styles.noLogs}>No recent logs available</Text>
          )}
        </View>
      </View>
    </ScrollView>
  );
}

function InfoRow({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.infoRow}>
      <Text style={styles.infoLabel}>{label}</Text>
      <Text style={styles.infoValue}>{value}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0f0f1a',
  },
  loading: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#0f0f1a',
  },
  loadingText: {
    color: '#9ca3af',
    fontSize: 16,
  },
  header: {
    padding: 20,
    backgroundColor: '#1a1a2e',
    borderBottomWidth: 1,
    borderBottomColor: '#2d2d44',
  },
  statusRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    marginBottom: 8,
  },
  statusBadge: {
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: 12,
  },
  statusText: {
    color: '#fff',
    fontSize: 12,
    fontWeight: '600',
  },
  networkBadge: {
    color: '#9ca3af',
    fontSize: 12,
    backgroundColor: '#2d2d44',
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: 12,
  },
  nodeName: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#fff',
  },
  nodeHost: {
    fontSize: 14,
    color: '#6b7280',
    marginTop: 4,
  },
  syncSection: {
    margin: 16,
    padding: 16,
    backgroundColor: '#1a1a2e',
    borderRadius: 12,
  },
  syncHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  syncTitle: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
  syncPercent: {
    color: '#4ade80',
    fontSize: 16,
    fontWeight: '600',
  },
  syncBar: {
    height: 8,
    backgroundColor: '#2d2d44',
    borderRadius: 4,
    overflow: 'hidden',
  },
  syncFill: {
    height: '100%',
    backgroundColor: '#4ade80',
  },
  syncInfo: {
    color: '#6b7280',
    fontSize: 12,
    marginTop: 8,
  },
  statsGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    padding: 8,
    gap: 8,
  },
  statCard: {
    flex: 1,
    minWidth: '45%',
    backgroundColor: '#1a1a2e',
    padding: 16,
    borderRadius: 12,
    alignItems: 'center',
  },
  statValue: {
    color: '#fff',
    fontSize: 20,
    fontWeight: 'bold',
    marginTop: 8,
  },
  statLabel: {
    color: '#6b7280',
    fontSize: 12,
    marginTop: 4,
  },
  section: {
    padding: 16,
  },
  sectionTitle: {
    color: '#fff',
    fontSize: 18,
    fontWeight: '600',
    marginBottom: 12,
  },
  infoCard: {
    backgroundColor: '#1a1a2e',
    borderRadius: 12,
    overflow: 'hidden',
  },
  infoRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    padding: 14,
    borderBottomWidth: 1,
    borderBottomColor: '#2d2d44',
  },
  infoLabel: {
    color: '#6b7280',
    fontSize: 14,
  },
  infoValue: {
    color: '#fff',
    fontSize: 14,
    fontWeight: '500',
  },
  actionGrid: {
    flexDirection: 'row',
    gap: 12,
  },
  actionButton: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 8,
    padding: 16,
    borderRadius: 12,
  },
  actionRestart: {
    backgroundColor: '#f59e0b',
  },
  actionPeer: {
    backgroundColor: '#3b82f6',
  },
  actionButtonText: {
    color: '#fff',
    fontSize: 14,
    fontWeight: '600',
  },
  logsCard: {
    backgroundColor: '#1a1a2e',
    borderRadius: 12,
    padding: 12,
  },
  logLine: {
    color: '#9ca3af',
    fontSize: 11,
    fontFamily: 'monospace',
    marginBottom: 4,
  },
  noLogs: {
    color: '#6b7280',
    fontSize: 14,
    textAlign: 'center',
    padding: 20,
  },
});
