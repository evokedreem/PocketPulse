/// <reference types="node" />

import { spawnSync } from "node:child_process";

const checker = "scripts/check-production-audit.cjs";
const advisoryEntries = [
  {
    source: 1138808,
    url: "https://github.com/advisories/GHSA-w3rx-r6r6-pgpr",
    name: "image-size",
    dependency: "image-size",
    severity: "high",
  },
  {
    source: 1138809,
    url: "https://github.com/advisories/GHSA-5p2g-fcmc-qvqq",
    name: "image-size",
    dependency: "image-size",
    severity: "high",
  },
];

function vulnerability(
  name: string,
  nodes: string[],
  via: (string | (typeof advisoryEntries)[number])[],
  effects: string[],
  isDirect = false,
) {
  return { name, nodes, via, effects, isDirect, severity: "high" };
}

function validReport() {
  return {
    auditReportVersion: 2,
    vulnerabilities: {
      "@expo/cli": vulnerability(
        "@expo/cli",
        ["node_modules/expo/node_modules/@expo/cli"],
        ["@expo/metro", "@expo/metro-config"],
        [],
      ),
      "@expo/metro": vulnerability(
        "@expo/metro",
        ["node_modules/@expo/metro"],
        ["metro", "metro-config", "metro-transform-worker"],
        ["@expo/cli", "@expo/metro-config", "expo"],
      ),
      "@expo/metro-config": vulnerability(
        "@expo/metro-config",
        ["node_modules/expo/node_modules/@expo/metro-config"],
        ["@expo/metro"],
        ["@expo/cli", "expo"],
      ),
      expo: vulnerability(
        "expo",
        ["node_modules/expo"],
        ["@expo/cli", "@expo/metro", "@expo/metro-config"],
        [],
        true,
      ),
      "image-size": vulnerability(
        "image-size",
        ["node_modules/image-size"],
        advisoryEntries,
        ["metro"],
      ),
      metro: vulnerability(
        "metro",
        ["node_modules/metro"],
        ["image-size", "metro-config", "metro-transform-worker"],
        ["@expo/metro", "metro-config", "metro-transform-worker"],
      ),
      "metro-config": vulnerability(
        "metro-config",
        ["node_modules/metro-config"],
        ["metro"],
        ["metro"],
      ),
      "metro-transform-worker": vulnerability(
        "metro-transform-worker",
        ["node_modules/metro-transform-worker"],
        ["metro"],
        ["@expo/metro", "metro"],
      ),
    },
    metadata: {
      vulnerabilities: {
        info: 0,
        low: 0,
        moderate: 0,
        high: 8,
        critical: 0,
        total: 8,
      },
    },
  };
}

function check(input: object | string) {
  return spawnSync(process.execPath, [checker], {
    cwd: __dirname,
    input: typeof input === "string" ? input : JSON.stringify(input),
    encoding: "utf8",
  });
}

describe("production dependency audit policy", () => {
  test("allows the exact known SDK 54 image-size advisory graph", () => {
    expect(check(validReport()).status).toBe(0);
  });

  test("allows a structurally valid report after upstream fixes everything", () => {
    const report = validReport();
    report.vulnerabilities = {} as typeof report.vulnerabilities;
    report.metadata.vulnerabilities.high = 0;
    report.metadata.vulnerabilities.total = 0;

    expect(check(report).status).toBe(0);
  });

  test("rejects an unsupported audit schema", () => {
    const report = validReport();
    report.auditReportVersion = 3;
    expect(check(report).status).toBe(1);
  });

  test("rejects a missing vulnerabilities object", () => {
    const { vulnerabilities: _, ...report } = validReport();
    expect(check(report).status).toBe(1);
  });

  test("rejects a mismatched dependency node path", () => {
    const report = validReport();
    report.vulnerabilities.metro.nodes = ["node_modules/not-metro"];
    expect(check(report).status).toBe(1);
  });

  test("rejects allowlisted advisories attached to the wrong package", () => {
    const report = validReport();
    report.vulnerabilities.expo.via = advisoryEntries;
    expect(check(report).status).toBe(1);
  });

  test("rejects an empty dependency edge list", () => {
    const report = validReport();
    report.vulnerabilities.metro.via = [];
    expect(check(report).status).toBe(1);
  });

  test("rejects metadata count mismatches", () => {
    const report = validReport();
    report.metadata.vulnerabilities.high = 7;
    expect(check(report).status).toBe(1);
  });

  test("rejects operational output that is not audit JSON", () => {
    expect(check("npm registry unavailable").status).toBe(1);
  });
});
