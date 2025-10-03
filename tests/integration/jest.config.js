module.exports = {
  // Test environment
  testEnvironment: 'node',
  
  // Test file patterns
  testMatch: [
    '**/tests/integration/**/*.test.js'
  ],
  
  // Setup files
  setupFilesAfterEnv: ['<rootDir>/tests/integration/setup.js'],
  
  // Test timeout (10 minutes for integration tests)
  testTimeout: 600000,
  
  // Coverage configuration
  collectCoverage: false, // Disable for integration tests
  
  // Module paths
  moduleDirectories: ['node_modules', '<rootDir>'],
  
  // Transform configuration
  transform: {},
  
  // Test environment variables
  testEnvironment: 'node',
  
  // Global setup and teardown
  globalSetup: '<rootDir>/tests/integration/global-setup.js',
  globalTeardown: '<rootDir>/tests/integration/global-teardown.js',
  
  // Reporter configuration
  reporters: [
    'default',
    [
      'jest-junit',
      {
        outputDirectory: 'test-results/integration',
        outputName: 'integration-test-results.xml',
        suiteName: 'Integration Tests'
      }
    ]
  ],
  
  // Verbose output
  verbose: true,
  
  // Detect open handles
  detectOpenHandles: true,
  
  // Force exit after tests complete
  forceExit: true,
  
  // Maximum worker processes
  maxWorkers: 1, // Run integration tests sequentially
  
  // Test sequence
  testSequencer: '<rootDir>/tests/integration/test-sequencer.js'
};