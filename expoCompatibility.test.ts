const packageJson = require("./package.json") as {
  dependencies: Record<string, string>;
};

describe("Expo Go compatibility", () => {
  test("targets the SDK supported by the current iOS App Store client", () => {
    expect(packageJson.dependencies.expo).toMatch(/^~54\./);
    expect(packageJson.dependencies.react).toBe("19.1.0");
    expect(packageJson.dependencies["react-native"]).toBe("0.81.5");
  });
});
