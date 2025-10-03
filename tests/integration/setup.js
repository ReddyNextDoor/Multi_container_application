const fs = require('fs');
const path = require('path');

// Global test setup for integration tests
beforeAll(() => {
  console.log('Setting up integration test environment...');
  
  // Verify required environment variables
  const requiredEnvVars = [
    'AWS_ACCESS_KEY_ID',
    'AWS_SECRET_ACCESS_KEY',
    'AWS_REGION'
  ];
  
  const missingVars = requiredEnvVars.filter(varName => !process.env[varName]);
  
  if (missingVars.length > 0) {
    console.warn(`Warning: Missing environment variables: ${missingVars.join(', ')}`);
    console.warn('Some integration tests may fail without proper AWS credentials');
  }
  
  // Set default values for test environment
  process.env.NODE_ENV = 'test';
  process.env.AWS_REGION = process.env.AWS_REGION || 'us-east-1';
  
  // Create test results directory
  const testResultsDir = path.join(__dirname, '../../test-results/integration');
  if (!fs.existsSync(testResultsDir)) {
    fs.mkdirSync(testResultsDir, { recursive: true });
  }
  
  console.log('Integration test environment setup complete');
});

afterAll(() => {
  console.log('Cleaning up integration test environment...');
  
  // Add any global cleanup here
  
  console.log('Integration test environment cleanup complete');
});

// Global error handler for unhandled rejections
process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection at:', promise, 'reason:', reason);
});

// Global error handler for uncaught exceptions
process.on('uncaughtException', (error) => {
  console.error('Uncaught Exception:', error);
  process.exit(1);
});

// Extend Jest matchers
expect.extend({
  toContainValidDockerImage(received, imageName) {
    const pass = received.includes(imageName) && received.includes('Up');
    
    if (pass) {
      return {
        message: () => `expected ${received} not to contain running Docker image ${imageName}`,
        pass: true,
      };
    } else {
      return {
        message: () => `expected ${received} to contain running Docker image ${imageName}`,
        pass: false,
      };
    }
  },
  
  toBeValidIPAddress(received) {
    const ipRegex = /^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/;
    const pass = ipRegex.test(received);
    
    if (pass) {
      return {
        message: () => `expected ${received} not to be a valid IP address`,
        pass: true,
      };
    } else {
      return {
        message: () => `expected ${received} to be a valid IP address`,
        pass: false,
      };
    }
  },
  
  toBeHealthyAPIResponse(received) {
    const pass = received.status === 200 && 
                 received.data && 
                 received.data.status === 'healthy';
    
    if (pass) {
      return {
        message: () => `expected response not to be a healthy API response`,
        pass: true,
      };
    } else {
      return {
        message: () => `expected response to be a healthy API response, got status: ${received.status}`,
        pass: false,
      };
    }
  }
});

// Test utilities
global.testUtils = {
  // Wait for a condition to be true
  waitFor: async (condition, timeout = 30000, interval = 1000) => {
    const startTime = Date.now();
    
    while (Date.now() - startTime < timeout) {
      try {
        const result = await condition();
        if (result) {
          return result;
        }
      } catch (error) {
        // Ignore errors and continue waiting
      }
      
      await new Promise(resolve => setTimeout(resolve, interval));
    }
    
    throw new Error(`Condition not met within ${timeout}ms`);
  },
  
  // Retry an operation with exponential backoff
  retry: async (operation, maxAttempts = 3, baseDelay = 1000) => {
    let lastError;
    
    for (let attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await operation();
      } catch (error) {
        lastError = error;
        
        if (attempt === maxAttempts) {
          throw error;
        }
        
        const delay = baseDelay * Math.pow(2, attempt - 1);
        console.log(`Attempt ${attempt} failed, retrying in ${delay}ms...`);
        await new Promise(resolve => setTimeout(resolve, delay));
      }
    }
    
    throw lastError;
  },
  
  // Generate random test data
  generateTestData: () => ({
    timestamp: Date.now(),
    randomId: Math.random().toString(36).substring(7),
    testTodo: {
      title: `Test Todo ${Date.now()}`,
      description: `This is a test todo created at ${new Date().toISOString()}`
    }
  }),
  
  // Validate environment setup
  validateEnvironment: () => {
    const checks = {
      nodeVersion: process.version,
      platform: process.platform,
      arch: process.arch,
      cwd: process.cwd(),
      env: {
        NODE_ENV: process.env.NODE_ENV,
        AWS_REGION: process.env.AWS_REGION,
        CI: process.env.CI
      }
    };
    
    console.log('Environment validation:', JSON.stringify(checks, null, 2));
    
    return checks;
  }
};

// Log test environment information
console.log('Integration Test Environment:');
console.log('- Node.js version:', process.version);
console.log('- Platform:', process.platform);
console.log('- Architecture:', process.arch);
console.log('- Working directory:', process.cwd());
console.log('- AWS Region:', process.env.AWS_REGION || 'not set');
console.log('- CI Environment:', process.env.CI || 'false');