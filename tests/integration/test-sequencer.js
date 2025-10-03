const Sequencer = require('@jest/test-sequencer').default;

class IntegrationTestSequencer extends Sequencer {
  /**
   * Custom test sequencer for integration tests
   * Ensures tests run in the correct order for deployment validation
   */
  sort(tests) {
    // Define test execution order
    const testOrder = [
      // 1. Infrastructure validation (no dependencies)
      'infrastructure-validation.test.js',
      
      // 2. Ansible configuration validation (no dependencies)
      'ansible-validation.test.js',
      
      // 3. Full deployment integration (depends on infrastructure and ansible)
      'deployment-integration.test.js'
    ];
    
    // Sort tests based on defined order
    const sortedTests = [];
    
    // First, add tests in the defined order
    testOrder.forEach(testFile => {
      const test = tests.find(t => t.path.includes(testFile));
      if (test) {
        sortedTests.push(test);
      }
    });
    
    // Then add any remaining tests
    tests.forEach(test => {
      if (!sortedTests.includes(test)) {
        sortedTests.push(test);
      }
    });
    
    console.log('Integration test execution order:');
    sortedTests.forEach((test, index) => {
      const testName = test.path.split('/').pop();
      console.log(`  ${index + 1}. ${testName}`);
    });
    
    return sortedTests;
  }
}

module.exports = IntegrationTestSequencer;