import 'package:flutter/material.dart';
import 'dart:math';
import '../services/api_service.dart';
import '../utils/dropdown_helpers.dart';

class CreateTaskScreen extends StatefulWidget {
  final String? bucketId;
  final String projectId;
  final String projectName;
  final String bucketName;
  final Function(Map<String, dynamic>) onTaskCreated;
  final Map<String, dynamic>? existingTask;
  final bool isEditMode;

  const CreateTaskScreen({
    super.key,
    this.bucketId,
    required this.projectId,
    required this.projectName,
    required this.bucketName,
    required this.onTaskCreated,
    this.existingTask,
    this.isEditMode = false,
  });

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final ApiService _apiService = ApiService();
  
  String? _selectedStatus = 'Pending';
  String? _selectedAssignee;
  String? _selectedPriority = 'Medium';
  DateTime _expiryDate = DateTime.now().add(const Duration(days: 7));
  
  bool _isLoading = false;
  bool _isSaving = false;
  List<Map<String, dynamic>> _projectEmployees = [];
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    
    // Set defaults first
    if (widget.existingTask != null) {
      _titleController.text = widget.existingTask!['title'] ?? '';
      _descriptionController.text = widget.existingTask!['description'] ?? '';
      _selectedStatus = DropdownHelpers.normalizeTaskStatus(widget.existingTask!['status']);
      _selectedAssignee = widget.existingTask!['assignedTo']?.toString();
      _selectedPriority = DropdownHelpers.normalizePriority(widget.existingTask!['priority']);
      
      if (widget.existingTask!['dueDate'] != null) {
        try {
          _expiryDate = DateTime.parse(widget.existingTask!['dueDate']);
        } catch (e) {
          debugPrint('Error parsing expiry date: $e');
        }
      }
    } else {
      // Initialize dropdowns with default values for new tasks
      _selectedStatus = 'Pending'; 
      _selectedPriority = 'Medium';
      _selectedAssignee = null; // This will be populated after employees are loaded
    }
    
    // Load employees for the bucket
    _loadProjectEmployees();
  }

  Future<void> _loadProjectEmployees() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
    }
    
    try {
      // Get project employees for assignee dropdown
      final employees = await _apiService.getProjectEmployees(widget.projectId);
      
      if (mounted) {
        setState(() {
          _projectEmployees = employees;
          _isLoading = false;
          
          // Set default assignee if available
          if (employees.isNotEmpty && _selectedAssignee == null) {
            _selectedAssignee = employees[0]['id']?.toString() ?? 
                                employees[0]['guid']?.toString() ?? 
                                employees[0]['email']?.toString();
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading project employees: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load users. Using default list.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() {
        _expiryDate = picked;
      });
    }
  }

  Future<void> _saveTask() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a task title')),
      );
      return;
    }
    
    if (mounted) {
      setState(() {
        _isSaving = true;
      });
    }
    
    try {
      // First determine if we're in edit mode and have an existing task ID
      final bool isEditMode = widget.isEditMode && widget.existingTask != null;
      final String? existingId = isEditMode 
          ? (widget.existingTask!['id']?.toString() ?? widget.existingTask!['guid']?.toString())
          : null;
          
      if (isEditMode && existingId != null) {
        debugPrint('EDIT MODE: Updating existing task with ID: $existingId');
      } else {
        debugPrint('CREATE MODE: Creating a new task');
      }
      
      // Create base task data
      final taskData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'status': _selectedStatus,
        'assignedTo': _selectedAssignee?.toString(), // Ensure it's a string
        'priority': _selectedPriority,
        'dueDate': _expiryDate.toIso8601String(),
        'bucketId': widget.bucketId?.toString(), // Ensure it's a string
        'bucketGuid': widget.bucketId?.toString(), // Add both forms of bucket ID
        'bucketName': widget.bucketName,
        'projectId': widget.projectId.toString(), // Ensure it's a string
        'projectName': widget.projectName,
      };
      
      // If we're updating an existing task, make sure the ID is included and correctly formatted
      if (isEditMode) {
        // Include both id and guid to cover all bases
        if (widget.existingTask!['id'] != null) {
          taskData['id'] = widget.existingTask!['id'].toString();
          debugPrint('Using existing ID for update: ${taskData['id']} (type: ${taskData['id'].runtimeType})');
        }
        
        if (widget.existingTask!['guid'] != null) {
          taskData['guid'] = widget.existingTask!['guid'].toString();
          debugPrint('Using existing GUID for update: ${taskData['guid']} (type: ${taskData['guid'].runtimeType})');
        }
        
        // Add other identifiers that might help the API recognize this as an update
        taskData['isUpdate'] = 'true';
        taskData['updateExisting'] = 'true';
        
        // Preserve creation date if available
        if (widget.existingTask!['createdAt'] != null) {
          taskData['createdAt'] = widget.existingTask!['createdAt'];
        }
      }
      
      debugPrint('${isEditMode ? "Updating" : "Creating"} task with data: $taskData');
      
      // Save or update task using the API
      final resultTask = isEditMode
          ? await _apiService.updateTask(taskData)
          : await _apiService.createTask(taskData);
      
      debugPrint('Task ${isEditMode ? "update" : "creation"} result: $resultTask');
      
      // Call the callback
      widget.onTaskCreated(resultTask);
      
      // Close the screen
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Task ${isEditMode ? "updated" : "created"} successfully'),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error ${widget.isEditMode ? "updating" : "creating"} task: $e');
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        
        // Show error dialog
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Task ${widget.isEditMode ? "Update" : "Creation"} Failed'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Error: ${e.toString()}'),
                    const SizedBox(height: 16),
                    const Text('Suggestions:'),
                    const SizedBox(height: 8),
                    const Text('• Check if the bucket exists and is valid'),
                    const Text('• Ensure the assignee is a valid user'),
                    const Text('• Try a different status or priority'),
                    const Text('• Check your internet connection'),
                    const SizedBox(height: 16),
                    const Text('Debug Details:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Bucket ID: ${widget.bucketId}'),
                    Text('Project ID: ${widget.projectId}'),
                    if (widget.isEditMode) 
                      Text('Task ID type: ${widget.existingTask?['id']?.runtimeType}'),
                    if (widget.isEditMode)
                      Text('Task ID: ${widget.existingTask?['id']?.toString() ?? widget.existingTask?['guid']?.toString() ?? 'Unknown'}'),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('CLOSE'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _saveTask(); // Retry
                  },
                  child: const Text('RETRY'),
                ),
              ],
            );
          },
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.isEditMode ? 'Edit Task' : 'Create Task',
          style: const TextStyle(color: Colors.black),
        ),
        actions: [
          _isSaving 
            ? const Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              )
            : TextButton(
                onPressed: _saveTask,
                child: Text(widget.isEditMode ? 'UPDATE' : 'CREATE'),
              ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      hintText: 'Title',
                      border: InputBorder.none,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Status'),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _selectedStatus,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              items: DropdownHelpers.taskStatusOptions.map((String status) {
                                return DropdownMenuItem(value: status, child: Text(status));
                              }).toList(),
                              onChanged: (value) => setState(() => _selectedStatus = value),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Due Date'),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () => _selectDate(context),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  suffixIcon: const Icon(Icons.calendar_today),
                                ),
                                child: Text(
                                  '${_expiryDate.day}/${_expiryDate.month}/${_expiryDate.year}',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Assignee'),
                            const SizedBox(height: 8),
                            if (_errorMessage.isNotEmpty) 
                              Text(_errorMessage, style: const TextStyle(color: Colors.red, fontSize: 12)),
                            DropdownButtonFormField<String>(
                              value: _selectedAssignee,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              items: _projectEmployees.isEmpty
                                  // Fallback to default list if no employees loaded
                                  ? const [
                                      DropdownMenuItem(value: 'oussama', child: Text('Oussama Tahmaz')),
                                      DropdownMenuItem(value: 'nabih', child: Text('Nabih Darwich')),
                                      DropdownMenuItem(value: 'hassan', child: Text('Hassan Bassam')),
                                      DropdownMenuItem(value: 'hatoum', child: Text('Hassan Hatoum')),
                                    ]
                                  // Dynamic list of employees
                                  : _projectEmployees.map((employee) {
                                      final employeeId = employee['id']?.toString() ?? 
                                                         employee['guid']?.toString() ?? 
                                                         employee['email']?.toString();
                                      final employeeName = employee['fullName'] ?? 
                                                           employee['name'] ?? 
                                                           employee['userName'] ?? 
                                                           employee['email'] ?? 
                                                           'Unknown User';
                                      return DropdownMenuItem(
                                        value: employeeId,
                                        child: Text(employeeName.toString()),
                                      );
                                    }).toList(),
                              onChanged: (value) => setState(() => _selectedAssignee = value),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Priority'),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _selectedPriority,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              items: DropdownHelpers.buildPriorityItems(),
                              onChanged: (value) => setState(() => _selectedPriority = value),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text('Description'),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      controller: _descriptionController,
                      maxLines: 10,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                        hintText: 'Enter task description here...',
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
} 