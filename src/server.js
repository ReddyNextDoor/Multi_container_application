const express = require('express');
const cors = require('cors');
const config = require('./utils/config');
const dbConnection = require('./utils/database');

const app = express();

// Middleware configuration
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Health check endpoint with database status
app.get('/health', async (req, res) => {
  try {
    const dbHealth = await dbConnection.healthCheck();
    const dbStatus = dbConnection.getConnectionStatus();
    
    res.status(200).json({
      success: true,
      message: 'API is running',
      timestamp: new Date().toISOString(),
      database: {
        status: dbHealth.status,
        message: dbHealth.message,
        connection: {
          isConnected: dbStatus.isConnected,
          readyState: dbStatus.readyState,
          host: dbStatus.host,
          port: dbStatus.port,
          name: dbStatus.name
        }
      }
    });
  } catch (error) {
    res.status(503).json({
      success: false,
      message: 'Service unavailable',
      timestamp: new Date().toISOString(),
      database: {
        status: 'error',
        message: error.message
      }
    });
  }
});

// Basic route
app.get('/', (req, res) => {
  res.json({
    success: true,
    message: 'Todo API Server',
    version: '1.0.0'
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({
    success: false,
    error: 'Internal Server Error',
    message: 'Something went wrong!'
  });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    success: false,
    error: 'Not Found',
    message: 'Route not found'
  });
});

// Initialize server with database connection
async function startServer() {
  try {
    // Validate configuration
    config.validateConfig();
    config.logConfig();

    // Connect to database
    await dbConnection.connect(config.database.uri, config.database.options);

    // Start server
    app.listen(config.port, () => {
      console.log(`🚀 Server is running on port ${config.port}`);
      console.log(`📊 Environment: ${config.nodeEnv}`);
      console.log(`🔗 Database: Connected to ${config.database.name}`);
    });
  } catch (error) {
    console.error('❌ Failed to start server:', error.message);
    process.exit(1);
  }
}

// Start the server
if (require.main === module) {
  startServer();
}

module.exports = app;