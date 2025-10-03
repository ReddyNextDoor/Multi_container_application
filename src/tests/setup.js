// Test setup file
process.env.NODE_ENV = 'test';
process.env.DB_URI = 'mongodb://localhost:27017/todo-api-test';

// Increase timeout for database operations
jest.setTimeout(30000);