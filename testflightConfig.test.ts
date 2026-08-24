/// <reference types="node" />

import { readFileSync } from "node:fs";
import { resolve } from "node:path";

type JsonObject = Record<string, any>;

function readJson(path: string): JsonObject {
  return JSON.parse(readFileSync(resolve(__dirname, path), "utf8"));
}

describe("TestFlight release configuration", () => {
  it("defines a pinned, committed production EAS build", () => {
    const eas = readJson("eas.json");

    expect(eas.cli).toMatchObject({
      version: "22.2.0",
      appVersionSource: "remote",
      requireCommit: true,
    });
    expect(eas.build.production).toMatchObject({
      distribution: "store",
      autoIncrement: true,
    });
    expect(eas.submit.production).toEqual({});
  });

  it("defines a private registered-device build with no submission profile", () => {
    const eas = readJson("eas.json");

    expect(eas.build.internal).toMatchObject({
      distribution: "internal",
      autoIncrement: true,
      ios: {
        simulator: false,
      },
    });
    expect(eas.submit.internal).toBeUndefined();
  });

  it("uses an opaque 1024-square App Store icon", () => {
    const icon = readFileSync(resolve(__dirname, "assets/icon.png"));

    expect(icon.subarray(0, 8).toString("hex")).toBe("89504e470d0a1a0a");
    expect(icon.readUInt32BE(16)).toBe(1024);
    expect(icon.readUInt32BE(20)).toBe(1024);
    expect(icon[25]).toBe(2);
    expect(icon.includes(Buffer.from("tRNS"))).toBe(false);
  });

  it("documents only supported pinned EAS initialization syntax", () => {
    const readme = readFileSync(resolve(__dirname, "README.md"), "utf8");

    expect(readme).toContain("npx --yes eas-cli@22.2.0 project:init");
    expect(readme).not.toContain("project:init --icon");
    expect(readme).toContain("Apple Developer Program");
    expect(readme).toContain('git commit -m "chore: link Expo EAS project"');
    expect(readme).toContain("eas-cli@22.2.0 device:create");
    expect(readme).toContain("--profile internal");
  });

  it("uses a stable iOS identity and declares exempt encryption", () => {
    const app = readJson("app.json").expo;

    expect(app.name).toBe("PocketPulse");
    expect(app.version).toBe("1.0.0");
    expect(app.icon).toBe("./assets/icon.png");
    expect(app.extra?.eas?.projectId).toBe(
      "cf088113-045c-436d-bb33-2996c048eea1",
    );
    expect(app.ios).toMatchObject({
      bundleIdentifier: "com.evokedreem.pocketpulse",
      supportsTablet: false,
      config: {
        usesNonExemptEncryption: false,
      },
    });
  });
});
