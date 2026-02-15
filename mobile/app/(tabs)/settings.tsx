import { View, Text, StyleSheet, ScrollView, Switch, TouchableOpacity, Alert } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import * as LocalAuthentication from 'expo-local-authentication';
import { useAuthStore } from '@/store/auth';
import { useSettingsStore } from '@/store/settings';

type SettingItemProps = {
  icon: keyof typeof Ionicons.glyphMap;
  title: string;
  subtitle?: string;
  onPress?: () => void;
  rightElement?: React.ReactNode;
};

function SettingItem({ icon, title, subtitle, onPress, rightElement }: SettingItemProps) {
  return (
    <TouchableOpacity
      style={styles.settingItem}
      onPress={onPress}
      disabled={!onPress && !rightElement}
      activeOpacity={onPress ? 0.7 : 1}
    >
      <View style={styles.settingIcon}>
        <Ionicons name={icon} size={22} color="#4ade80" />
      </View>
      <View style={styles.settingContent}>
        <Text style={styles.settingTitle}>{title}</Text>
        {subtitle && <Text style={styles.settingSubtitle}>{subtitle}</Text>}
      </View>
      {rightElement ?? (onPress && <Ionicons name="chevron-forward" size={20} color="#6b7280" />)}
    </TouchableOpacity>
  );
}

function SettingSection({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <View style={styles.section}>
      <Text style={styles.sectionTitle}>{title}</Text>
      <View style={styles.sectionContent}>{children}</View>
    </View>
  );
}

export default function SettingsScreen() {
  const { biometricEnabled, setBiometricEnabled } = useAuthStore();
  const {
    pushNotifications,
    setPushNotifications,
    refreshInterval,
    setRefreshInterval,
    apiEndpoint,
    setApiEndpoint,
  } = useSettingsStore();

  const handleBiometricToggle = async (value: boolean) => {
    if (value) {
      const hasHardware = await LocalAuthentication.hasHardwareAsync();
      const isEnrolled = await LocalAuthentication.isEnrolledAsync();

      if (!hasHardware || !isEnrolled) {
        Alert.alert(
          'Biometric Not Available',
          'Please set up biometric authentication in your device settings first.'
        );
        return;
      }

      const result = await LocalAuthentication.authenticateAsync({
        promptMessage: 'Confirm to enable biometric authentication',
      });

      if (result.success) {
        setBiometricEnabled(true);
      }
    } else {
      setBiometricEnabled(false);
    }
  };

  const handleRefreshIntervalChange = () => {
    Alert.alert(
      'Refresh Interval',
      'How often should data auto-refresh?',
      [
        { text: '15 seconds', onPress: () => setRefreshInterval(15) },
        { text: '30 seconds', onPress: () => setRefreshInterval(30) },
        { text: '1 minute', onPress: () => setRefreshInterval(60) },
        { text: '5 minutes', onPress: () => setRefreshInterval(300) },
        { text: 'Cancel', style: 'cancel' },
      ]
    );
  };

  const handleApiEndpointChange = () => {
    Alert.prompt(
      'API Endpoint',
      'Enter your SkyNet API endpoint URL',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Save',
          onPress: (value) => {
            if (value) setApiEndpoint(value);
          },
        },
      ],
      'plain-text',
      apiEndpoint
    );
  };

  const formatRefreshInterval = (seconds: number) => {
    if (seconds < 60) return `${seconds} seconds`;
    return `${seconds / 60} minute${seconds > 60 ? 's' : ''}`;
  };

  return (
    <ScrollView style={styles.container}>
      <SettingSection title="Security">
        <SettingItem
          icon="finger-print"
          title="Biometric Authentication"
          subtitle="Use Face ID or fingerprint to unlock"
          rightElement={
            <Switch
              value={biometricEnabled}
              onValueChange={handleBiometricToggle}
              trackColor={{ false: '#2d2d44', true: '#4ade80' }}
              thumbColor="#fff"
            />
          }
        />
      </SettingSection>

      <SettingSection title="Notifications">
        <SettingItem
          icon="notifications"
          title="Push Notifications"
          subtitle="Receive alerts for node issues"
          rightElement={
            <Switch
              value={pushNotifications}
              onValueChange={setPushNotifications}
              trackColor={{ false: '#2d2d44', true: '#4ade80' }}
              thumbColor="#fff"
            />
          }
        />
        <SettingItem
          icon="options"
          title="Notification Settings"
          subtitle="Configure alert preferences"
          onPress={() => {}}
        />
      </SettingSection>

      <SettingSection title="Data">
        <SettingItem
          icon="refresh"
          title="Auto-Refresh Interval"
          subtitle={formatRefreshInterval(refreshInterval)}
          onPress={handleRefreshIntervalChange}
        />
        <SettingItem
          icon="server"
          title="API Endpoint"
          subtitle={apiEndpoint || 'Not configured'}
          onPress={handleApiEndpointChange}
        />
      </SettingSection>

      <SettingSection title="About">
        <SettingItem
          icon="information-circle"
          title="Version"
          subtitle="1.0.0"
        />
        <SettingItem
          icon="document-text"
          title="Documentation"
          onPress={() => {}}
        />
        <SettingItem
          icon="logo-github"
          title="Source Code"
          onPress={() => {}}
        />
      </SettingSection>

      <View style={styles.footer}>
        <Text style={styles.footerText}>XDC Node Monitor</Text>
        <Text style={styles.footerSubtext}>Part of XDC-Node-Setup</Text>
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0f0f1a',
  },
  section: {
    marginTop: 24,
  },
  sectionTitle: {
    fontSize: 13,
    fontWeight: '600',
    color: '#6b7280',
    textTransform: 'uppercase',
    letterSpacing: 0.5,
    paddingHorizontal: 16,
    marginBottom: 8,
  },
  sectionContent: {
    backgroundColor: '#1a1a2e',
    borderTopWidth: 1,
    borderBottomWidth: 1,
    borderColor: '#2d2d44',
  },
  settingItem: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 16,
    borderBottomWidth: 1,
    borderBottomColor: '#2d2d44',
  },
  settingIcon: {
    width: 36,
    height: 36,
    borderRadius: 8,
    backgroundColor: 'rgba(74, 222, 128, 0.1)',
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 12,
  },
  settingContent: {
    flex: 1,
  },
  settingTitle: {
    fontSize: 16,
    color: '#fff',
  },
  settingSubtitle: {
    fontSize: 13,
    color: '#6b7280',
    marginTop: 2,
  },
  footer: {
    alignItems: 'center',
    padding: 32,
  },
  footerText: {
    fontSize: 14,
    color: '#6b7280',
  },
  footerSubtext: {
    fontSize: 12,
    color: '#4b5563',
    marginTop: 4,
  },
});
