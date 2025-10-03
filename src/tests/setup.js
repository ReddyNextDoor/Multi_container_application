// Test setup file
process.env.NODE_ENV = 'test';

// Use MONGODB_URI from environment or default for local testing
process.env.DB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/todo-api-test';

// Increase timeout for database operations
jest.setTimeout(30000);