export type PulseState = Readonly<{
  count: number;
}>;

export function initialPulseState(): PulseState {
  return { count: 0 };
}

export function recordPulse(state: PulseState): PulseState {
  return { count: state.count + 1 };
}

export function resetPulse(): PulseState {
  return initialPulseState();
}

export function getPulseMessage(count: number): string {
  if (count === 0) {
    return "Ready when you are";
  }
  if (count < 5) {
    return "Nice start";
  }
  if (count < 10) {
    return "Keep the rhythm going";
  }
  return "PocketPulse is working";
}
