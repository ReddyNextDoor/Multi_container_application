const fs = require('fs');
const path = require('path');

module.exports = async () => {
  console.log('Starting global teardown for integration tests...');
  
  try {
    // Clean up test resources
    await cleanupTestResources();
    
    // Generate test report
    await generateTestReport();
    
    // Archive test artifacts
    await archiveTestArtifacts();
    
    console.log('Global teardown completed successfully');
    
  } catch (error) {
    console.error('Global teardown failed:', error.message);
    // Don't throw error in teardown to avoid masking test failures
  }
};

async function cleanupTestResources() {
  console.log('Cleaning up test resources...');
  
  // Clean up temporary files
  const tempDirs = [
    path.join(__dirname, '../../inventory-test'),
    path.join(__dirname, '../../terraform/test.tfvars'),
    path.join(__dirname, '../../terraform/test.tfplan')
  ];
  
  tempDirs.forEach(tempPath => {
    if (fs.existsSync(tempPath)) {
      try {
        if (fs.statSync(tempPath).isDirectory()) {
          fs.rmSync(tempPath, { recursive: true, force: true });
        } else {
          fs.unlinkSync(tempPath);
        }
        console.log(`Cleaned up: ${tempPath}`);
      } catch (error) {
        console.warn(`Could not clean up ${tempPath}: ${error.message}`);
      }
    }
  });
  
  // Clean up Docker test images (if any)
  try {
    const { execSync } = require('child_process');
    
    // Remove test images
    const testImages = [
      'todo-api:test',
      'todo-api:integration-test'
    ];
    
    testImages.forEach(image => {
      try {
        execSync(`docker rmi ${image}`, { encoding: 'utf8', timeout: 30000 });
        console.log(`Removed Docker image: ${image}`);
      } catch (error) {
        // Image may not exist, which is fine
      }
    });
    
    // Clean up unused Docker resources
    try {
      execSync('docker system prune -f', { encoding: 'utf8', timeout: 60000 });
      console.log('Cleaned up unused Docker resources');
    } catch (error) {
      console.warn('Could not clean up Docker resources:', error.message);
    }
    
  } catch (error) {
    console.warn('Docker cleanup failed:', error.message);
  }
  
  console.log('Test resources cleanup completed');
}

async function generateTestReport() {
  console.log('Generating test report...');
  
  const testResultsDir = path.join(__dirname, '../../test-results');
  
  if (!fs.existsSync(testResultsDir)) {
    console.log('No test results directory found, skipping report generation');
    return;
  }
  
  const reportData = {
    timestamp: new Date().toISOString(),
    testSuite: 'integration',
    environment: process.env.NODE_ENV || 'test',
    platform: process.platform,
    nodeVersion: process.version,
    summary: {
      totalTests: 0,
      passedTests: 0,
      failedTests: 0,
      skippedTests: 0,
      duration: 0
    },
    artifacts: [],
    logs: []
  };
  
  // Collect test artifacts
  try {
    const artifactsDir = path.join(testResultsDir, 'artifacts');
    if (fs.existsSync(artifactsDir)) {
      const artifacts = fs.readdirSync(artifactsDir);
      reportData.artifacts = artifacts.map(artifact => ({
        name: artifact,
        path: path.join(artifactsDir, artifact),
        size: fs.statSync(path.join(artifactsDir, artifact)).size,
        created: fs.statSync(path.join(artifactsDir, artifact)).mtime
      }));
    }
  } catch (error) {
    console.warn('Could not collect artifacts:', error.message);
  }
  
  // Collect log files
  try {
    const logsDir = path.join(testResultsDir, 'logs');
    if (fs.existsSync(logsDir)) {
      const logs = fs.readdirSync(logsDir);
      reportData.logs = logs.map(log => ({
        name: log,
        path: path.join(logsDir, log),
        size: fs.statSync(path.join(logsDir, log)).size,
        created: fs.statSync(path.join(logsDir, log)).mtime
      }));
    }
  } catch (error) {
    console.warn('Could not collect logs:', error.message);
  }
  
  // Parse Jest results if available
  try {
    const jestResultsFile = path.join(testResultsDir, 'integration/integration-test-results.xml');
    if (fs.existsSync(jestResultsFile)) {
      // Basic XML parsing for test counts
      const xmlContent = fs.readFileSync(jestResultsFile, 'utf8');
      
      const testsMatch = xmlContent.match(/tests="(\d+)"/);
      const failuresMatch = xmlContent.match(/failures="(\d+)"/);
      const errorsMatch = xmlContent.match(/errors="(\d+)"/);
      const skippedMatch = xmlContent.match(/skipped="(\d+)"/);
      const timeMatch = xmlContent.match(/time="([\d.]+)"/);
      
      if (testsMatch) reportData.summary.totalTests = parseInt(testsMatch[1]);
      if (failuresMatch) reportData.summary.failedTests = parseInt(failuresMatch[1]);
      if (errorsMatch) reportData.summary.failedTests += parseInt(errorsMatch[1]);
      if (skippedMatch) reportData.summary.skippedTests = parseInt(skippedMatch[1]);
      if (timeMatch) reportData.summary.duration = parseFloat(timeMatch[1]);
      
      reportData.summary.passedTests = reportData.summary.totalTests - 
                                      reportData.summary.failedTests - 
                                      reportData.summary.skippedTests;
    }
  } catch (error) {
    console.warn('Could not parse Jest results:', error.message);
  }
  
  // Add system information
  reportData.system = {
    memory: {
      total: Math.round(require('os').totalmem() / 1024 / 1024 / 1024) + 'GB',
      free: Math.round(require('os').freemem() / 1024 / 1024 / 1024) + 'GB'
    },
    cpus: require('os').cpus().length,
    uptime: Math.round(require('os').uptime() / 3600) + 'h'
  };
  
  // Save report
  const reportFile = path.join(testResultsDir, 'integration-test-report.json');
  fs.writeFileSync(reportFile, JSON.stringify(reportData, null, 2));
  
  // Generate human-readable summary
  const summaryFile = path.join(testResultsDir, 'test-summary.txt');
  const summary = `
Integration Test Summary
=======================
Timestamp: ${reportData.timestamp}
Environment: ${reportData.environment}
Platform: ${reportData.platform}
Node.js: ${reportData.nodeVersion}

Test Results:
- Total Tests: ${reportData.summary.totalTests}
- Passed: ${reportData.summary.passedTests}
- Failed: ${reportData.summary.failedTests}
- Skipped: ${reportData.summary.skippedTests}
- Duration: ${reportData.summary.duration}s

System Information:
- Memory: ${reportData.system.memory.free} free of ${reportData.system.memory.total}
- CPUs: ${reportData.system.cpus}
- Uptime: ${reportData.system.uptime}

Artifacts: ${reportData.artifacts.length} files
Logs: ${reportData.logs.length} files
`;
  
  fs.writeFileSync(summaryFile, summary);
  
  console.log('Test report generated successfully');
  console.log(`Report saved to: ${reportFile}`);
  console.log(`Summary saved to: ${summaryFile}`);
}

async function archiveTestArtifacts() {
  console.log('Archiving test artifacts...');
  
  const testResultsDir = path.join(__dirname, '../../test-results');
  
  if (!fs.existsSync(testResultsDir)) {
    console.log('No test results to archive');
    return;
  }
  
  try {
    const { execSync } = require('child_process');
    
    // Create archive with timestamp
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const archiveName = `integration-test-results-${timestamp}.tar.gz`;
    const archivePath = path.join(__dirname, '../../', archiveName);
    
    // Create tar archive
    execSync(`tar -czf "${archivePath}" -C "${path.dirname(testResultsDir)}" "${path.basename(testResultsDir)}"`, {
      encoding: 'utf8',
      timeout: 60000
    });
    
    const archiveSize = fs.statSync(archivePath).size;
    console.log(`Test artifacts archived: ${archiveName} (${Math.round(archiveSize / 1024)}KB)`);
    
    // Clean up old archives (keep last 5)
    try {
      const projectRoot = path.join(__dirname, '../..');
      const files = fs.readdirSync(projectRoot);
      const archiveFiles = files
        .filter(file => file.startsWith('integration-test-results-') && file.endsWith('.tar.gz'))
        .map(file => ({
          name: file,
          path: path.join(projectRoot, file),
          mtime: fs.statSync(path.join(projectRoot, file)).mtime
        }))
        .sort((a, b) => b.mtime - a.mtime);
      
      // Remove old archives (keep newest 5)
      const archivesToRemove = archiveFiles.slice(5);
      archivesToRemove.forEach(archive => {
        try {
          fs.unlinkSync(archive.path);
          console.log(`Removed old archive: ${archive.name}`);
        } catch (error) {
          console.warn(`Could not remove old archive ${archive.name}: ${error.message}`);
        }
      });
      
    } catch (error) {
      console.warn('Could not clean up old archives:', error.message);
    }
    
  } catch (error) {
    console.warn('Could not create test archive:', error.message);
  }
  
  console.log('Test artifacts archiving completed');
}

// Log teardown completion
process.on('exit', () => {
  const teardownLog = {
    timestamp: new Date().toISOString(),
    level: 'INFO',
    message: 'Integration test global teardown completed',
    processId: process.pid,
    exitCode: process.exitCode
  };
  
  try {
    const logFile = path.join(__dirname, '../../test-results/logs/integration-teardown.log');
    fs.writeFileSync(logFile, JSON.stringify(teardownLog, null, 2) + '\n');
  } catch (error) {
    // Ignore logging errors during teardown
  }
});