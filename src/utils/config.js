require('dotenv').config();

const config = {
  // Server Configuration
  port: process.env.PORT || 3000,
  nodeEnv: process.env.NODE_ENV || 'development',
  
  // Database Configuration
  database: {
    uri: process.env.MONGODB_URI || 'mongodb://localhost:27017/todoapi',
    name: process.env.DB_NAME || 'todoapi',
    options: {
      useNewUrlParser: true,
      useUnifiedTopology: true,
      maxPoolSize: parseInt(process.env.DB_MAX_POOL_SIZE) || 10,
      serverSelectionTimeoutMS: parseInt(process.env.DB_SERVER_SELECTION_TIMEOUT) || 5000,
      socketTimeoutMS: parseInt(process.env.DB_SOCKET_TIMEOUT) || 45000,
    }
  },

  // Application Configuration
  app: {
    name: 'Todo API',
    version: '1.0.0',
    description: 'A RESTful Todo API with MongoDB backend'
  }
};

// Validation function to ensure required environment variables are set
function validateConfig() {
  const requiredEnvVars = [];
  const missingVars = [];

  // Check for required environment variables in production
  if (config.nodeEnv === 'production') {
    requiredEnvVars.push('MONGODB_URI');
    
    requiredEnvVars.forEach(varName => {
      if (!process.env[varName]) {
        missingVars.push(varName);
      }
    });

    if (missingVars.length > 0) {
      throw new Error(`Missing required environment variables: ${missingVars.join(', ')}`);
    }
  }

  // Validate database URI format
  if (!config.database.uri.startsWith('mongodb://') && !config.database.uri.startsWith('mongodb+srv://')) {
    throw new Error('Invalid MongoDB URI format. Must start with mongodb:// or mongodb+srv://');
  }

  // Validate port number
  if (isNaN(config.port) || config.port < 1 || config.port > 65535) {
    throw new Error('Invalid port number. Must be between 1 and 65535');
  }

  console.log('✅ Configuration validation passed');
  return true;
}

// Log configuration (excluding sensitive data)
function logConfig() {
  console.log('📋 Application Configuration:');
  console.log(`   Environment: ${config.nodeEnv}`);
  console.log(`   Port: ${config.port}`);
  console.log(`   Database: ${config.database.name}`);
  console.log(`   Database Host: ${config.database.uri.replace(/\/\/.*@/, '//***@')}`); // Hide credentials
}

module.exports = {
  ...config,
  validateConfig,
  logConfig
};