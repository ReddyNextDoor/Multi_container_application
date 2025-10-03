const express = require('express');
const Todo = require('../models/Todo');

const router = express.Router();

// GET /todos - Retrieve all todos from database
router.get('/', async (req, res) => {
  try {
    const todos = await Todo.find().sort({ createdAt: -1 });
    
    res.status(200).json({
      success: true,
      data: todos,
      message: `Retrieved ${todos.length} todos successfully`
    });
  } catch (error) {
    console.error('Error retrieving todos:', error);
    res.status(500).json({
      success: false,
      error: 'Internal Server Error',
      message: 'Failed to retrieve todos'
    });
  }
});

// POST /todos - Create new todo with validation
router.post('/', async (req, res) => {
  try {
    const { title, description, completed } = req.body;

    // Validate required fields
    if (!title || title.trim() === '') {
      return res.status(400).json({
        success: false,
        error: 'Validation Error',
        message: 'Title is required'
      });
    }

    // Create new todo
    const todoData = {
      title: title.trim(),
      description: description ? description.trim() : '',
      completed: completed || false
    };

    const newTodo = new Todo(todoData);
    const savedTodo = await newTodo.save();

    res.status(201).json({
      success: true,
      data: savedTodo,
      message: 'Todo created successfully'
    });
  } catch (error) {
    console.error('Error creating todo:', error);
    
    // Handle validation errors
    if (error.name === 'ValidationError') {
      const validationErrors = Object.values(error.errors).map(err => err.message);
      return res.status(400).json({
        success: false,
        error: 'Validation Error',
        message: validationErrors.join(', ')
      });
    }

    res.status(500).json({
      success: false,
      error: 'Internal Server Error',
      message: 'Failed to create todo'
    });
  }
});

// GET /todos/:id - Retrieve single todo by ID
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;

    // Validate MongoDB ObjectId format
    if (!id.match(/^[0-9a-fA-F]{24}$/)) {
      return res.status(400).json({
        success: false,
        error: 'Validation Error',
        message: 'Invalid todo ID format'
      });
    }

    const todo = await Todo.findById(id);

    if (!todo) {
      return res.status(404).json({
        success: false,
        error: 'Not Found',
        message: 'Todo not found'
      });
    }

    res.status(200).json({
      success: true,
      data: todo,
      message: 'Todo retrieved successfully'
    });
  } catch (error) {
    console.error('Error retrieving todo:', error);
    res.status(500).json({
      success: false,
      error: 'Internal Server Error',
      message: 'Failed to retrieve todo'
    });
  }
});

// PUT /todos/:id - Update existing todo
router.put('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { title, description, completed } = req.body;

    // Validate MongoDB ObjectId format
    if (!id.match(/^[0-9a-fA-F]{24}$/)) {
      return res.status(400).json({
        success: false,
        error: 'Validation Error',
        message: 'Invalid todo ID format'
      });
    }

    // Check if todo exists
    const existingTodo = await Todo.findById(id);
    if (!existingTodo) {
      return res.status(404).json({
        success: false,
        error: 'Not Found',
        message: 'Todo not found'
      });
    }

    // Prepare update data
    const updateData = {};
    
    if (title !== undefined) {
      if (!title || title.trim() === '') {
        return res.status(400).json({
          success: false,
          error: 'Validation Error',
          message: 'Title cannot be empty'
        });
      }
      updateData.title = title.trim();
    }

    if (description !== undefined) {
      updateData.description = description ? description.trim() : '';
    }

    if (completed !== undefined) {
      updateData.completed = Boolean(completed);
    }

    // Update todo with validation
    const updatedTodo = await Todo.findByIdAndUpdate(
      id,
      updateData,
      { 
        new: true, // Return updated document
        runValidators: true // Run schema validation
      }
    );

    res.status(200).json({
      success: true,
      data: updatedTodo,
      message: 'Todo updated successfully'
    });
  } catch (error) {
    console.error('Error updating todo:', error);
    
    // Handle validation errors
    if (error.name === 'ValidationError') {
      const validationErrors = Object.values(error.errors).map(err => err.message);
      return res.status(400).json({
        success: false,
        error: 'Validation Error',
        message: validationErrors.join(', ')
      });
    }

    res.status(500).json({
      success: false,
      error: 'Internal Server Error',
      message: 'Failed to update todo'
    });
  }
});

// DELETE /todos/:id - Delete todo by ID
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;

    // Validate MongoDB ObjectId format
    if (!id.match(/^[0-9a-fA-F]{24}$/)) {
      return res.status(400).json({
        success: false,
        error: 'Validation Error',
        message: 'Invalid todo ID format'
      });
    }

    // Find and delete todo
    const deletedTodo = await Todo.findByIdAndDelete(id);

    if (!deletedTodo) {
      return res.status(404).json({
        success: false,
        error: 'Not Found',
        message: 'Todo not found'
      });
    }

    res.status(200).json({
      success: true,
      data: deletedTodo,
      message: 'Todo deleted successfully'
    });
  } catch (error) {
    console.error('Error deleting todo:', error);
    res.status(500).json({
      success: false,
      error: 'Internal Server Error',
      message: 'Failed to delete todo'
    });
  }
});

module.exports = router;