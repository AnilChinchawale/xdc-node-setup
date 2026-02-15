/**
 * Authentication store using Zustand
 */

import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';
import AsyncStorage from '@react-native-async-storage/async-storage';

interface AuthState {
  isAuthenticated: boolean;
  biometricEnabled: boolean;
  setAuthenticated: (value: boolean) => void;
  setBiometricEnabled: (value: boolean) => void;
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set) => ({
      isAuthenticated: false,
      biometricEnabled: false,
      setAuthenticated: (value) => set({ isAuthenticated: value }),
      setBiometricEnabled: (value) => set({ biometricEnabled: value }),
    }),
    {
      name: 'auth-storage',
      storage: createJSONStorage(() => AsyncStorage),
      partialize: (state) => ({ biometricEnabled: state.biometricEnabled }),
    }
  )
);
