import { useEffect } from 'react';
import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { useAuthStore } from '@/store/auth';
import * as LocalAuthentication from 'expo-local-authentication';

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 30000,
      retry: 2,
    },
  },
});

export default function RootLayout() {
  const { isAuthenticated, setAuthenticated, biometricEnabled } = useAuthStore();

  useEffect(() => {
    const authenticate = async () => {
      if (!biometricEnabled) {
        setAuthenticated(true);
        return;
      }

      const hasHardware = await LocalAuthentication.hasHardwareAsync();
      const isEnrolled = await LocalAuthentication.isEnrolledAsync();

      if (hasHardware && isEnrolled) {
        const result = await LocalAuthentication.authenticateAsync({
          promptMessage: 'Authenticate to access XDC Node Monitor',
          fallbackLabel: 'Use passcode',
        });
        setAuthenticated(result.success);
      } else {
        setAuthenticated(true);
      }
    };

    authenticate();
  }, [biometricEnabled, setAuthenticated]);

  if (!isAuthenticated) {
    return null; // Show nothing until authenticated
  }

  return (
    <QueryClientProvider client={queryClient}>
      <StatusBar style="light" />
      <Stack
        screenOptions={{
          headerStyle: { backgroundColor: '#1a1a2e' },
          headerTintColor: '#fff',
          contentStyle: { backgroundColor: '#0f0f1a' },
        }}
      >
        <Stack.Screen name="(tabs)" options={{ headerShown: false }} />
        <Stack.Screen
          name="node/[id]"
          options={{ title: 'Node Details', presentation: 'card' }}
        />
      </Stack>
    </QueryClientProvider>
  );
}
