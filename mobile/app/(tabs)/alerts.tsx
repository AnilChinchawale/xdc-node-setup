import { View, Text, StyleSheet, FlatList, TouchableOpacity, RefreshControl } from 'react-native';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Ionicons } from '@expo/vector-icons';
import { api } from '@/lib/api';
import type { Alert } from '@/types/alert';

function AlertItem({ alert, onDismiss }: { alert: Alert; onDismiss: () => void }) {
  const severityConfig = {
    critical: { color: '#ef4444', icon: 'alert-circle' as const },
    warning: { color: '#fbbf24', icon: 'warning' as const },
    info: { color: '#3b82f6', icon: 'information-circle' as const },
  };

  const config = severityConfig[alert.severity] ?? severityConfig.info;

  return (
    <View style={[styles.alertCard, { borderLeftColor: config.color }]}>
      <View style={styles.alertHeader}>
        <View style={styles.alertTitle}>
          <Ionicons name={config.icon} size={24} color={config.color} />
          <View style={styles.alertTitleText}>
            <Text style={styles.alertName}>{alert.title}</Text>
            <Text style={styles.alertNode}>{alert.nodeName}</Text>
          </View>
        </View>
        <TouchableOpacity onPress={onDismiss} hitSlop={{ top: 10, bottom: 10, left: 10, right: 10 }}>
          <Ionicons name="close" size={20} color="#6b7280" />
        </TouchableOpacity>
      </View>

      <Text style={styles.alertMessage}>{alert.message}</Text>

      <View style={styles.alertFooter}>
        <Text style={styles.alertTime}>
          {new Date(alert.timestamp).toLocaleString()}
        </Text>
        {alert.actionable && (
          <TouchableOpacity style={styles.actionButton}>
            <Text style={styles.actionButtonText}>Take Action</Text>
          </TouchableOpacity>
        )}
      </View>
    </View>
  );
}

export default function AlertsScreen() {
  const queryClient = useQueryClient();

  const {
    data: alerts,
    isLoading,
    refetch,
    isRefetching,
  } = useQuery({
    queryKey: ['alerts'],
    queryFn: api.getAlerts,
    refetchInterval: 30000,
  });

  const dismissMutation = useMutation({
    mutationFn: api.dismissAlert,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['alerts'] });
    },
  });

  const clearAllMutation = useMutation({
    mutationFn: api.clearAllAlerts,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['alerts'] });
    },
  });

  const activeAlerts = alerts?.filter((a) => !a.dismissed) ?? [];

  return (
    <View style={styles.container}>
      {activeAlerts.length > 0 && (
        <View style={styles.header}>
          <Text style={styles.headerText}>
            {activeAlerts.length} active alert{activeAlerts.length !== 1 ? 's' : ''}
          </Text>
          <TouchableOpacity
            style={styles.clearButton}
            onPress={() => clearAllMutation.mutate()}
          >
            <Text style={styles.clearButtonText}>Clear All</Text>
          </TouchableOpacity>
        </View>
      )}

      <FlatList
        data={activeAlerts}
        keyExtractor={(item) => item.id}
        renderItem={({ item }) => (
          <AlertItem
            alert={item}
            onDismiss={() => dismissMutation.mutate(item.id)}
          />
        )}
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
            <Ionicons name="checkmark-circle" size={64} color="#4ade80" />
            <Text style={styles.emptyText}>All Clear!</Text>
            <Text style={styles.emptySubtext}>
              {isLoading ? 'Loading alerts...' : 'No active alerts'}
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
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 16,
    borderBottomWidth: 1,
    borderBottomColor: '#2d2d44',
  },
  headerText: {
    fontSize: 14,
    color: '#9ca3af',
  },
  clearButton: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    backgroundColor: '#2d2d44',
    borderRadius: 6,
  },
  clearButtonText: {
    fontSize: 14,
    color: '#fff',
  },
  list: {
    padding: 16,
  },
  alertCard: {
    backgroundColor: '#1a1a2e',
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
    borderLeftWidth: 4,
  },
  alertHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: 8,
  },
  alertTitle: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  alertTitleText: {
    flex: 1,
  },
  alertName: {
    fontSize: 16,
    fontWeight: '600',
    color: '#fff',
  },
  alertNode: {
    fontSize: 12,
    color: '#6b7280',
    marginTop: 2,
  },
  alertMessage: {
    fontSize: 14,
    color: '#9ca3af',
    lineHeight: 20,
  },
  alertFooter: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginTop: 12,
  },
  alertTime: {
    fontSize: 12,
    color: '#6b7280',
  },
  actionButton: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    backgroundColor: '#3b82f6',
    borderRadius: 6,
  },
  actionButtonText: {
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
    fontSize: 24,
    fontWeight: 'bold',
    color: '#fff',
    marginTop: 16,
  },
  emptySubtext: {
    fontSize: 14,
    color: '#6b7280',
    marginTop: 8,
  },
});
