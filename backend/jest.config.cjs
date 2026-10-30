module.exports = {
  testEnvironment: "node",
  extensionsToTreatAsEsm: [".ts"],
  transform: {
    "^.+\\.tsx?$": [
      "ts-jest",
      { useESM: true, tsconfig: "tsconfig.test.json" },
    ],
  },
  moduleNameMapper: { "^(\\.{1,2}/.*)\\.js$": "$1" },
  testMatch: ["**/test/**/*.spec.ts"],
  testTimeout: 30000,
  coverageProvider: "v8",
  collectCoverageFrom: ["src/**/*.ts", "!src/generated/**", "!src/main.ts"],
  coverageReporters: ["json-summary", "lcov", "text-summary"],
};
