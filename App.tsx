import { useState } from "react";
import {
  Animated,
  Pressable,
  StyleSheet,
  Text,
  Vibration,
  View,
} from "react-native";
import { StatusBar } from "expo-status-bar";
import { SafeAreaView } from "react-native-safe-area-context";

import {
  getPulseMessage,
  initialPulseState,
  recordPulse,
  resetPulse,
} from "./src/pulseCounter";

export default function App() {
  const [pulse, setPulse] = useState(initialPulseState);
  const [scale] = useState(() => new Animated.Value(1));

  const handlePulse = () => {
    setPulse((current) => recordPulse(current));
    Vibration.vibrate(20);
    Animated.sequence([
      Animated.spring(scale, {
        toValue: 1.1,
        useNativeDriver: true,
        speed: 35,
        bounciness: 12,
      }),
      Animated.spring(scale, {
        toValue: 1,
        useNativeDriver: true,
        speed: 24,
        bounciness: 8,
      }),
    ]).start();
  };

  const handleReset = () => {
    setPulse(resetPulse());
    Vibration.vibrate([0, 25, 45, 25]);
  };

  return (
    <SafeAreaView style={styles.safeArea}>
      <StatusBar style="light" />
      <View style={styles.backgroundOrbTop} />
      <View style={styles.backgroundOrbBottom} />

      <View style={styles.container}>
        <View style={styles.heading}>
          <Text style={styles.eyebrow}>POCKETPULSE</Text>
          <Text style={styles.title}>Tap Check</Text>
          <Text style={styles.subtitle}>
            Live from GitHub through your cloud Expo server
          </Text>
        </View>

        <Animated.View
          accessible
          accessibilityLabel="Pulse count"
          accessibilityValue={{ text: String(pulse.count) }}
          style={[styles.pulseOuter, { transform: [{ scale }] }]}
        >
          <View style={styles.pulseMiddle}>
            <View style={styles.pulseInner}>
              <Text style={styles.count}>{pulse.count}</Text>
              <Text style={styles.countLabel}>
                {pulse.count === 1 ? "pulse" : "pulses"}
              </Text>
            </View>
          </View>
        </Animated.View>

        <Text style={styles.message}>{getPulseMessage(pulse.count)}</Text>

        <Pressable
          accessibilityRole="button"
          accessibilityLabel="Log a pulse"
          accessibilityHint="Increases the pulse count by one"
          onPress={handlePulse}
          style={({ pressed }) => [
            styles.primaryButton,
            pressed && styles.buttonPressed,
          ]}
        >
          <Text style={styles.primaryButtonText}>♥ Log a pulse</Text>
        </Pressable>

        <Pressable
          accessibilityRole="button"
          accessibilityLabel="Reset"
          accessibilityHint="Returns the pulse count to zero"
          disabled={pulse.count === 0}
          onPress={handleReset}
          style={({ pressed }) => [
            styles.resetButton,
            pressed && styles.buttonPressed,
          ]}
        >
          <Text
            style={[
              styles.resetText,
              pulse.count === 0 && styles.resetTextDisabled,
            ]}
          >
            Reset
          </Text>
        </Pressable>

        <Text style={styles.footer}>EXPO GO • CLOUD PREVIEW VERIFIED</Text>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: "#120b28",
    overflow: "hidden",
  },
  container: {
    flex: 1,
    alignItems: "center",
    justifyContent: "space-between",
    paddingHorizontal: 28,
    paddingBottom: 24,
    paddingTop: 20,
  },
  backgroundOrbTop: {
    position: "absolute",
    width: 320,
    height: 320,
    borderRadius: 160,
    backgroundColor: "#56216f",
    opacity: 0.42,
    top: -130,
    right: -110,
  },
  backgroundOrbBottom: {
    position: "absolute",
    width: 290,
    height: 290,
    borderRadius: 145,
    backgroundColor: "#173f61",
    opacity: 0.32,
    bottom: -120,
    left: -130,
  },
  heading: {
    alignItems: "center",
    gap: 7,
  },
  eyebrow: {
    color: "#d9b8ff",
    fontSize: 12,
    fontWeight: "800",
    letterSpacing: 3.5,
  },
  title: {
    color: "#ffffff",
    fontSize: 38,
    fontWeight: "800",
    letterSpacing: -1,
  },
  subtitle: {
    color: "#b9abc8",
    fontSize: 13,
    maxWidth: 290,
    textAlign: "center",
  },
  pulseOuter: {
    alignItems: "center",
    backgroundColor: "#f05ba8",
    borderRadius: 132,
    height: 264,
    justifyContent: "center",
    shadowColor: "#ec5eac",
    shadowOffset: { width: 0, height: 12 },
    shadowOpacity: 0.38,
    shadowRadius: 28,
    width: 264,
  },
  pulseMiddle: {
    alignItems: "center",
    backgroundColor: "#8f5bd7",
    borderRadius: 122,
    height: 244,
    justifyContent: "center",
    width: 244,
  },
  pulseInner: {
    alignItems: "center",
    backgroundColor: "#1b1234",
    borderRadius: 112,
    height: 224,
    justifyContent: "center",
    width: 224,
  },
  count: {
    color: "#ffffff",
    fontSize: 76,
    fontVariant: ["tabular-nums"],
    fontWeight: "800",
    letterSpacing: -3,
  },
  countLabel: {
    color: "#bcaecb",
    fontSize: 17,
    fontWeight: "600",
  },
  message: {
    color: "#f3e9ff",
    fontSize: 18,
    fontWeight: "700",
    textAlign: "center",
  },
  primaryButton: {
    alignItems: "center",
    alignSelf: "stretch",
    backgroundColor: "#ffffff",
    borderRadius: 18,
    paddingVertical: 17,
    shadowColor: "#000000",
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.22,
    shadowRadius: 16,
  },
  primaryButtonText: {
    color: "#24133d",
    fontSize: 17,
    fontWeight: "800",
  },
  buttonPressed: {
    opacity: 0.78,
    transform: [{ scale: 0.98 }],
  },
  resetButton: {
    paddingHorizontal: 28,
    paddingVertical: 8,
  },
  resetText: {
    color: "#d9c8e8",
    fontSize: 15,
    fontWeight: "700",
  },
  resetTextDisabled: {
    color: "#625670",
  },
  footer: {
    color: "#746882",
    fontSize: 10,
    fontWeight: "800",
    letterSpacing: 1.5,
  },
});
