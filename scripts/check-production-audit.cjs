const fs = require("node:fs");

const expectedGraph = {
  "@expo/cli": {
    direct: false,
    nodes: ["node_modules/expo/node_modules/@expo/cli"],
    via: ["@expo/metro", "@expo/metro-config"],
    effects: [],
  },
  "@expo/metro": {
    direct: false,
    nodes: ["node_modules/@expo/metro"],
    via: ["metro", "metro-config", "metro-transform-worker"],
    effects: ["@expo/cli", "@expo/metro-config", "expo"],
  },
  "@expo/metro-config": {
    direct: false,
    nodes: ["node_modules/expo/node_modules/@expo/metro-config"],
    via: ["@expo/metro"],
    effects: ["@expo/cli", "expo"],
  },
  expo: {
    direct: true,
    nodes: ["node_modules/expo"],
    via: ["@expo/cli", "@expo/metro", "@expo/metro-config"],
    effects: [],
  },
  "image-size": {
    direct: false,
    nodes: ["node_modules/image-size"],
    viaAdvisories: [
      {
        source: 1138808,
        url: "https://github.com/advisories/GHSA-w3rx-r6r6-pgpr",
      },
      {
        source: 1138809,
        url: "https://github.com/advisories/GHSA-5p2g-fcmc-qvqq",
      },
    ],
    effects: ["metro"],
  },
  metro: {
    direct: false,
    nodes: ["node_modules/metro"],
    via: ["image-size", "metro-config", "metro-transform-worker"],
    effects: ["@expo/metro", "metro-config", "metro-transform-worker"],
  },
  "metro-config": {
    direct: false,
    nodes: ["node_modules/metro-config"],
    via: ["metro"],
    effects: ["metro"],
  },
  "metro-transform-worker": {
    direct: false,
    nodes: ["node_modules/metro-transform-worker"],
    via: ["metro"],
    effects: ["@expo/metro", "metro"],
  },
};

function sorted(values) {
  return [...values].sort();
}

function sameStrings(actual, expected) {
  return (
    Array.isArray(actual) &&
    actual.every((value) => typeof value === "string") &&
    JSON.stringify(sorted(actual)) === JSON.stringify(sorted(expected))
  );
}

function validateMetadata(metadata, vulnerabilities) {
  const counts = metadata?.vulnerabilities;
  const severities = ["info", "low", "moderate", "high", "critical"];
  if (!counts || typeof counts !== "object") {
    return ["missing metadata.vulnerabilities"];
  }

  const expectedCounts = Object.fromEntries(
    severities.map((severity) => [
      severity,
      Object.values(vulnerabilities).filter(
        (entry) => entry?.severity === severity,
      ).length,
    ]),
  );
  expectedCounts.total = Object.keys(vulnerabilities).length;

  return [...severities, "total"]
    .filter((key) => counts[key] !== expectedCounts[key])
    .map(
      (key) =>
        `metadata ${key}=${String(counts[key])}, expected ${expectedCounts[key]}`,
    );
}

function validateReport(report) {
  const errors = [];
  if (!report || typeof report !== "object" || Array.isArray(report)) {
    return ["report must be an object"];
  }
  if (report.auditReportVersion !== 2) {
    errors.push(`unsupported auditReportVersion ${report.auditReportVersion}`);
  }
  if (
    !Object.prototype.hasOwnProperty.call(report, "vulnerabilities") ||
    !report.vulnerabilities ||
    typeof report.vulnerabilities !== "object" ||
    Array.isArray(report.vulnerabilities)
  ) {
    errors.push("missing or invalid vulnerabilities object");
    return errors;
  }
  if (report.error) {
    errors.push(`npm audit error ${JSON.stringify(report.error)}`);
  }

  const vulnerabilities = report.vulnerabilities;
  errors.push(...validateMetadata(report.metadata, vulnerabilities));

  const actualPackages = Object.keys(vulnerabilities);
  if (actualPackages.length === 0) {
    return errors;
  }

  const expectedPackages = Object.keys(expectedGraph);
  if (!sameStrings(actualPackages, expectedPackages)) {
    errors.push(
      `package set ${JSON.stringify(sorted(actualPackages))} does not match the exact SDK 54 allowlist`,
    );
    return errors;
  }

  for (const packageName of expectedPackages) {
    const actual = vulnerabilities[packageName];
    const expected = expectedGraph[packageName];

    if (actual.name !== packageName) {
      errors.push(`${packageName} has mismatched name ${String(actual.name)}`);
    }
    if (actual.severity !== "high") {
      errors.push(`${packageName} severity is not high`);
    }
    if (actual.isDirect !== expected.direct) {
      errors.push(`${packageName} has unexpected isDirect`);
    }
    if (!sameStrings(actual.nodes, expected.nodes)) {
      errors.push(`${packageName} has unexpected nodes`);
    }
    if (!sameStrings(actual.effects, expected.effects)) {
      errors.push(`${packageName} has unexpected effects`);
    }

    if (packageName === "image-size") {
      if (
        !Array.isArray(actual.via) ||
        actual.via.length !== expected.viaAdvisories.length ||
        actual.via.some(
          (advisory) =>
            !advisory ||
            typeof advisory !== "object" ||
            advisory.name !== "image-size" ||
            advisory.dependency !== "image-size" ||
            advisory.severity !== "high",
        )
      ) {
        errors.push("image-size has malformed advisory entries");
      } else {
        const actualAdvisories = actual.via
          .map(({ source, url }) => ({ source, url }))
          .sort((a, b) => a.source - b.source);
        const expectedAdvisories = [...expected.viaAdvisories].sort(
          (a, b) => a.source - b.source,
        );
        if (
          JSON.stringify(actualAdvisories) !==
          JSON.stringify(expectedAdvisories)
        ) {
          errors.push("image-size advisory IDs or URLs do not match");
        }
      }
    } else if (!sameStrings(actual.via, expected.via)) {
      errors.push(`${packageName} has unexpected dependency edges`);
    }
  }

  return errors;
}

function main() {
  let report;
  try {
    report = JSON.parse(fs.readFileSync(0, "utf8"));
  } catch (error) {
    process.stderr.write(
      `Production audit rejected: invalid npm audit JSON (${error.message})\n`,
    );
    process.exitCode = 1;
    return;
  }

  const errors = validateReport(report);
  if (errors.length > 0) {
    process.stderr.write(`Production audit rejected: ${errors.join("; ")}\n`);
    process.exitCode = 1;
    return;
  }

  const count = Object.keys(report.vulnerabilities).length;
  if (count === 0) {
    process.stdout.write("Production audit passed with no findings.\n");
  } else {
    process.stdout.write(
      `Production audit accepted the exact ${count}-package SDK 54 chain rooted only in the two allowlisted, currently unfixed image-size advisories.\n`,
    );
  }
}

main();
