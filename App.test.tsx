import { fireEvent, render } from "@testing-library/react-native";

import App from "./App";

describe("PocketPulse app", () => {
  let consoleWarning: jest.SpiedFunction<typeof console.warn>;

  beforeEach(() => {
    consoleWarning = jest
      .spyOn(console, "warn")
      .mockImplementation(() => undefined);
  });

  afterEach(() => {
    expect(consoleWarning).not.toHaveBeenCalled();
    consoleWarning.mockRestore();
  });

  test("records a pulse and shows the next milestone message", () => {
    const screen = render(<App />);

    expect(screen.getByText("0")).toBeTruthy();
    expect(screen.getByText("Ready when you are")).toBeTruthy();

    fireEvent.press(screen.getByRole("button", { name: "Log a pulse" }));

    expect(screen.getByText("1")).toBeTruthy();
    expect(screen.getByText("Nice start")).toBeTruthy();
  });

  test("resets the pulse count", () => {
    const screen = render(<App />);

    fireEvent.press(screen.getByRole("button", { name: "Log a pulse" }));
    fireEvent.press(screen.getByRole("button", { name: "Reset" }));

    expect(screen.getByText("0")).toBeTruthy();
    expect(screen.getByText("Ready when you are")).toBeTruthy();
  });

  test("shows that the cloud preview is verified", () => {
    const screen = render(<App />);

    expect(screen.getByText("EXPO GO • CLOUD PREVIEW VERIFIED")).toBeTruthy();
  });
});
