const mongoose = require('mongoose');

const todoSchema = new mongoose.Schema({
  title: {
    type: String,
    required: [true, 'Title is required'],
    trim: true,
    maxlength: [200, 'Title cannot exceed 200 characters']
  },
  description: {
    type: String,
    trim: true,
    maxlength: [1000, 'Description cannot exceed 1000 characters'],
    default: ''
  },
  completed: {
    type: Boolean,
    default: false
  }
}, {
  timestamps: true, // Automatically adds createdAt and updatedAt fields
  versionKey: false // Removes __v field
});

// Add index for better query performance
todoSchema.index({ completed: 1 });
todoSchema.index({ createdAt: -1 });

// Instance method to toggle completion status
todoSchema.methods.toggleComplete = function() {
  this.completed = !this.completed;
  return this.save();
};

// Static method to find incomplete todos
todoSchema.statics.findIncomplete = function() {
  return this.find({ completed: false });
};

// Static method to find completed todos
todoSchema.statics.findCompleted = function() {
  return this.find({ completed: true });
};

const Todo = mongoose.model('Todo', todoSchema);

module.exports = Todo;