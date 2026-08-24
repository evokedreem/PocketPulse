const packageJson = require("./package.json") as {
  packageManager: string;
  dependencies: Record<string, string>;
};

describe("Expo Go compatibility", () => {
  test("targets the SDK supported by the current iOS App Store client", () => {
    expect(packageJson.dependencies.expo).toMatch(/^~54\./);
    expect(packageJson.dependencies.react).toBe("19.1.0");
    expect(packageJson.dependencies["react-native"]).toBe("0.81.5");
    expect(packageJson.packageManager).toBe("npm@10.9.8");
  });
});
