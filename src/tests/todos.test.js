const request = require('supertest');
const mongoose = require('mongoose');
const app = require('../server');
const Todo = require('../models/Todo');

// Test database connection
const testDbUri = process.env.TEST_DB_URI || 'mongodb://localhost:27017/todo-api-test';

describe('Todo API Endpoints', () => {
  beforeAll(async () => {
    // Connect to test database
    await mongoose.connect(testDbUri);
  });

  beforeEach(async () => {
    // Clean database before each test
    await Todo.deleteMany({});
  });

  afterAll(async () => {
    // Clean up and close connection
    await Todo.deleteMany({});
    await mongoose.connection.close();
  });

  describe('GET /todos', () => {
    it('should return empty array when no todos exist', async () => {
      const response = await request(app)
        .get('/todos')
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data).toEqual([]);
      expect(response.body.message).toBe('Retrieved 0 todos successfully');
    });

    it('should return all todos when they exist', async () => {
      // Create test todos
      await Todo.create({ title: 'Test Todo 1', description: 'Description 1' });
      await Todo.create({ title: 'Test Todo 2', completed: true });

      const response = await request(app)
        .get('/todos')
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data).toHaveLength(2);
      expect(response.body.message).toBe('Retrieved 2 todos successfully');
    });
  });

  describe('POST /todos', () => {
    it('should create a new todo with valid data', async () => {
      const todoData = {
        title: 'New Todo',
        description: 'Todo description',
        completed: false
      };

      const response = await request(app)
        .post('/todos')
        .send(todoData)
        .expect(201);

      expect(response.body.success).toBe(true);
      expect(response.body.data.title).toBe(todoData.title);
      expect(response.body.data.description).toBe(todoData.description);
      expect(response.body.data.completed).toBe(false);
      expect(response.body.message).toBe('Todo created successfully');
    });

    it('should return validation error when title is missing', async () => {
      const todoData = { description: 'No title' };

      const response = await request(app)
        .post('/todos')
        .send(todoData)
        .expect(400);

      expect(response.body.success).toBe(false);
      expect(response.body.error).toBe('Validation Error');
      expect(response.body.message).toBe('Title is required');
    });

    it('should return validation error when title is empty', async () => {
      const todoData = { title: '   ', description: 'Empty title' };

      const response = await request(app)
        .post('/todos')
        .send(todoData)
        .expect(400);

      expect(response.body.success).toBe(false);
      expect(response.body.error).toBe('Validation Error');
      expect(response.body.message).toBe('Title is required');
    });
  });

  describe('GET /todos/:id', () => {
    it('should return specific todo when valid ID is provided', async () => {
      const todo = await Todo.create({ title: 'Test Todo', description: 'Test description' });

      const response = await request(app)
        .get(`/todos/${todo._id}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data._id).toBe(todo._id.toString());
      expect(response.body.data.title).toBe(todo.title);
      expect(response.body.message).toBe('Todo retrieved successfully');
    });

    it('should return 404 when todo does not exist', async () => {
      const nonExistentId = new mongoose.Types.ObjectId();

      const response = await request(app)
        .get(`/todos/${nonExistentId}`)
        .expect(404);

      expect(response.body.success).toBe(false);
      expect(response.body.error).toBe('Not Found');
      expect(response.body.message).toBe('Todo not found');
    });

    it('should return validation error for invalid ID format', async () => {
      const response = await request(app)
        .get('/todos/invalid-id')
        .expect(400);

      expect(response.body.success).toBe(false);
      expect(response.body.error).toBe('Validation Error');
      expect(response.body.message).toBe('Invalid todo ID format');
    });
  });

  describe('PUT /todos/:id', () => {
    it('should update todo with valid data', async () => {
      const todo = await Todo.create({ title: 'Original Title', description: 'Original description' });
      const updateData = {
        title: 'Updated Title',
        description: 'Updated description',
        completed: true
      };

      const response = await request(app)
        .put(`/todos/${todo._id}`)
        .send(updateData)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.title).toBe(updateData.title);
      expect(response.body.data.description).toBe(updateData.description);
      expect(response.body.data.completed).toBe(true);
      expect(response.body.message).toBe('Todo updated successfully');
    });

    it('should return 404 when todo does not exist', async () => {
      const nonExistentId = new mongoose.Types.ObjectId();
      const updateData = { title: 'Updated Title' };

      const response = await request(app)
        .put(`/todos/${nonExistentId}`)
        .send(updateData)
        .expect(404);

      expect(response.body.success).toBe(false);
      expect(response.body.error).toBe('Not Found');
      expect(response.body.message).toBe('Todo not found');
    });

    it('should return validation error when title is empty', async () => {
      const todo = await Todo.create({ title: 'Original Title' });
      const updateData = { title: '   ' };

      const response = await request(app)
        .put(`/todos/${todo._id}`)
        .send(updateData)
        .expect(400);

      expect(response.body.success).toBe(false);
      expect(response.body.error).toBe('Validation Error');
      expect(response.body.message).toBe('Title cannot be empty');
    });
  });

  describe('DELETE /todos/:id', () => {
    it('should delete todo when valid ID is provided', async () => {
      const todo = await Todo.create({ title: 'Todo to delete', description: 'Will be deleted' });

      const response = await request(app)
        .delete(`/todos/${todo._id}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data._id).toBe(todo._id.toString());
      expect(response.body.message).toBe('Todo deleted successfully');

      // Verify todo is actually deleted
      const deletedTodo = await Todo.findById(todo._id);
      expect(deletedTodo).toBeNull();
    });

    it('should return 404 when todo does not exist', async () => {
      const nonExistentId = new mongoose.Types.ObjectId();

      const response = await request(app)
        .delete(`/todos/${nonExistentId}`)
        .expect(404);

      expect(response.body.success).toBe(false);
      expect(response.body.error).toBe('Not Found');
      expect(response.body.message).toBe('Todo not found');
    });

    it('should return validation error for invalid ID format', async () => {
      const response = await request(app)
        .delete('/todos/invalid-id')
        .expect(400);

      expect(response.body.success).toBe(false);
      expect(response.body.error).toBe('Validation Error');
      expect(response.body.message).toBe('Invalid todo ID format');
    });
  });
});