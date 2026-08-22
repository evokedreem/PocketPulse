import {
  getPulseMessage,
  initialPulseState,
  recordPulse,
  resetPulse,
} from "./pulseCounter";

describe("pulse counter", () => {
  test("starts at zero with the ready message", () => {
    expect(initialPulseState()).toEqual({ count: 0 });
    expect(getPulseMessage(0)).toBe("Ready when you are");
  });

  test("records one pulse without mutating the previous state", () => {
    const previous = initialPulseState();
    const next = recordPulse(previous);

    expect(previous).toEqual({ count: 0 });
    expect(next).toEqual({ count: 1 });
  });

  test.each([
    [1, "Nice start"],
    [5, "Keep the rhythm going"],
    [10, "PocketPulse is working"],
  ])("returns the milestone message for %i pulses", (count, message) => {
    expect(getPulseMessage(count)).toBe(message);
  });

  test("reset returns a fresh zero state", () => {
    expect(resetPulse()).toEqual({ count: 0 });
  });
});
