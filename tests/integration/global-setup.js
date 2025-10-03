const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

module.exports = async () => {
  console.log('Starting global setup for integration tests...');
  
  try {
    // Verify prerequisites
    await verifyPrerequisites();
    
    // Setup test environment
    await setupTestEnvironment();
    
    // Initialize test resources
    await initializeTestResources();
    
    console.log('Global setup completed successfully');
    
  } catch (error) {
    console.error('Global setup failed:', error.message);
    throw error;
  }
};

async function verifyPrerequisites() {
  console.log('Verifying prerequisites...');
  
  const requiredTools = [
    { name: 'node', command: 'node --version' },
    { name: 'npm', command: 'npm --version' },
    { name: 'docker', command: 'docker --version' },
    { name: 'docker-compose', command: 'docker-compose --version' },
    { name: 'terraform', command: 'terraform --version' },
    { name: 'ansible', command: 'ansible --version' },
    { name: 'aws', command: 'aws --version' }
  ];
  
  const results = {};
  
  for (const tool of requiredTools) {
    try {
      const output = execSync(tool.command, { encoding: 'utf8', timeout: 10000 });
      results[tool.name] = {
        available: true,
        version: output.trim().split('\n')[0]
      };
      console.log(`✓ ${tool.name}: ${results[tool.name].version}`);
    } catch (error) {
      results[tool.name] = {
        available: false,
        error: error.message
      };
      console.warn(`⚠ ${tool.name}: Not available - ${error.message}`);
    }
  }
  
  // Check for critical tools
  const criticalTools = ['node', 'npm', 'docker'];
  const missingCritical = criticalTools.filter(tool => !results[tool].available);
  
  if (missingCritical.length > 0) {
    throw new Error(`Critical tools missing: ${missingCritical.join(', ')}`);
  }
  
  // Save tool versions for reference
  const toolVersionsFile = path.join(__dirname, '../../test-results/tool-versions.json');
  fs.writeFileSync(toolVersionsFile, JSON.stringify(results, null, 2));
  
  console.log('Prerequisites verification completed');
}

async function setupTestEnvironment() {
  console.log('Setting up test environment...');
  
  // Create test directories
  const testDirs = [
    'test-results',
    'test-results/integration',
    'test-results/logs',
    'test-results/artifacts'
  ];
  
  testDirs.forEach(dir => {
    const dirPath = path.join(__dirname, '../..', dir);
    if (!fs.existsSync(dirPath)) {
      fs.mkdirSync(dirPath, { recursive: true });
      console.log(`Created directory: ${dir}`);
    }
  });
  
  // Set up environment variables for tests
  const testEnvVars = {
    NODE_ENV: 'test',
    TEST_TIMEOUT: '600000',
    TEST_RETRY_ATTEMPTS: '3',
    TEST_RETRY_DELAY: '5000'
  };
  
  Object.entries(testEnvVars).forEach(([key, value]) => {
    if (!process.env[key]) {
      process.env[key] = value;
    }
  });
  
  // Verify AWS credentials (if available)
  try {
    execSync('aws sts get-caller-identity', { encoding: 'utf8', timeout: 10000 });
    console.log('✓ AWS credentials are configured');
  } catch (error) {
    console.warn('⚠ AWS credentials not configured - some tests may be skipped');
  }
  
  // Verify Docker is running
  try {
    execSync('docker info', { encoding: 'utf8', timeout: 10000 });
    console.log('✓ Docker is running');
  } catch (error) {
    console.warn('⚠ Docker is not running - some tests may fail');
  }
  
  console.log('Test environment setup completed');
}

async function initializeTestResources() {
  console.log('Initializing test resources...');
  
  // Install test dependencies if needed
  try {
    const packageJsonPath = path.join(__dirname, '../../package.json');
    if (fs.existsSync(packageJsonPath)) {
      const packageJson = JSON.parse(fs.readFileSync(packageJsonPath, 'utf8'));
      
      // Check if integration test dependencies are installed
      const testDeps = [
        'jest',
        'axios',
        'js-yaml'
      ];
      
      const missingDeps = testDeps.filter(dep => 
        !packageJson.dependencies?.[dep] && !packageJson.devDependencies?.[dep]
      );
      
      if (missingDeps.length > 0) {
        console.log(`Installing missing test dependencies: ${missingDeps.join(', ')}`);
        execSync(`npm install --save-dev ${missingDeps.join(' ')}`, {
          encoding: 'utf8',
          cwd: path.join(__dirname, '../..'),
          timeout: 60000
        });
      }
    }
  } catch (error) {
    console.warn('Could not verify/install test dependencies:', error.message);
  }
  
  // Create test configuration files
  const testConfigDir = path.join(__dirname, '../../test-results');
  
  const testConfig = {
    timestamp: new Date().toISOString(),
    environment: process.env.NODE_ENV,
    platform: process.platform,
    nodeVersion: process.version,
    testSuite: 'integration',
    settings: {
      timeout: parseInt(process.env.TEST_TIMEOUT || '600000'),
      retryAttempts: parseInt(process.env.TEST_RETRY_ATTEMPTS || '3'),
      retryDelay: parseInt(process.env.TEST_RETRY_DELAY || '5000')
    }
  };
  
  fs.writeFileSync(
    path.join(testConfigDir, 'test-config.json'),
    JSON.stringify(testConfig, null, 2)
  );
  
  // Set up test logging
  const logFile = path.join(testConfigDir, 'logs', 'integration-setup.log');
  const logEntry = {
    timestamp: new Date().toISOString(),
    level: 'INFO',
    message: 'Integration test global setup completed',
    config: testConfig
  };
  
  fs.writeFileSync(logFile, JSON.stringify(logEntry, null, 2) + '\n');
  
  console.log('Test resources initialization completed');
}

// Helper function to check if a command exists
function commandExists(command) {
  try {
    execSync(`which ${command}`, { encoding: 'utf8', timeout: 5000 });
    return true;
  } catch (error) {
    return false;
  }
}

// Helper function to get system information
function getSystemInfo() {
  return {
    platform: process.platform,
    arch: process.arch,
    nodeVersion: process.version,
    npmVersion: (() => {
      try {
        return execSync('npm --version', { encoding: 'utf8', timeout: 5000 }).trim();
      } catch {
        return 'unknown';
      }
    })(),
    memory: {
      total: Math.round(require('os').totalmem() / 1024 / 1024 / 1024) + 'GB',
      free: Math.round(require('os').freemem() / 1024 / 1024 / 1024) + 'GB'
    },
    cpus: require('os').cpus().length
  };
}