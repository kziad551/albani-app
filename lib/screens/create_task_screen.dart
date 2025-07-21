import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';
import '../services/api_service.dart';
import '../utils/dropdown_helpers.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

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
  List<String> _selectedAssignees = [];
  String? _selectedPriority = 'Medium';
  DateTime _expiryDate = DateTime.now().add(const Duration(days: 7));
  
  bool _isLoading = false;
  bool _isSaving = false;
  List<Map<String, dynamic>> _projectEmployees = [];
  String _errorMessage = '';
  
  // File attachment variables
  List<PlatformFile> _selectedFiles = [];
  bool _isUploadingFiles = false;
  List<Map<String, dynamic>> _existingAttachments = [];

  @override
  void initState() {
    super.initState();
    
    // Set defaults first
    if (widget.existingTask != null) {
      _titleController.text = widget.existingTask!['title'] ?? '';
      _descriptionController.text = widget.existingTask!['description'] ?? '';
      _selectedStatus = DropdownHelpers.normalizeTaskStatus(widget.existingTask!['status']);
      // Support both string and list for backward compatibility
      final assigned = widget.existingTask!['assignedTo'];
      if (assigned is List) {
        _selectedAssignees = assigned.map((e) => e.toString()).toList();
      } else if (assigned != null) {
        _selectedAssignees = [assigned.toString()];
      }
      _selectedPriority = DropdownHelpers.normalizePriority(widget.existingTask!['priority']);
      
      if (widget.existingTask!['dueDate'] != null) {
        try {
          _expiryDate = DateTime.parse(widget.existingTask!['dueDate']);
        } catch (e) {
          debugPrint('Error parsing expiry date: $e');
        }
      }
      
      // Load existing task attachments if in edit mode
      _loadExistingAttachments();
    } else {
      // Initialize dropdowns with default values for new tasks
      _selectedStatus = 'Pending'; 
      _selectedPriority = 'Medium';
      _selectedAssignees = [];
    }
    
    // Load employees for the bucket
    _loadProjectEmployees();
  }

  // Load existing task attachments when editing
  Future<void> _loadExistingAttachments() async {
    if (widget.existingTask == null) return;
    
    final taskGuid = widget.existingTask!['guid']?.toString();
    if (taskGuid == null || taskGuid.isEmpty) return;
    
    try {
      final attachments = await _apiService.getTaskAttachments(taskGuid);
      debugPrint('Loaded ${attachments.length} existing attachments for task');
      
      setState(() {
        _existingAttachments = attachments;
      });
    } catch (e) {
      debugPrint('Error loading existing attachments: $e');
    }
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
          // Set default assignees if available and none selected
          if (employees.isNotEmpty && _selectedAssignees.isEmpty) {
            final employeeId = employees[0]['id']?.toString() ?? 
                                employees[0]['guid']?.toString() ?? 
                                employees[0]['email']?.toString();
            if (employeeId != null) {
              _selectedAssignees = [employeeId];
            }
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

  // Method to handle file selection
  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );
      
      if (result != null) {
        setState(() {
          _selectedFiles.addAll(result.files);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking files: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Method to remove selected file
  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  // Helper method to download existing attachment
  Future<void> _downloadExistingAttachment(Map<String, dynamic> attachment) async {
    try {
      final fileName = attachment['fileName'] ?? 'attachment';
      final fileUrl = attachment['fileUrl'] ?? attachment['url'];
      final fileGuid = attachment['guid']?.toString();
      
      if (fileGuid == null || fileGuid.isEmpty) {
        throw Exception('Invalid file GUID');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Downloading $fileName...')),
      );
      
              // Get download URL and open file
        final downloadUrl = await _apiService.getFileDownloadUrl(fileGuid);
        debugPrint('Got download URL: $downloadUrl');

        if (!mounted) return;

        // Check platform and handle accordingly
        if (kIsWeb) {
          // For web, open in new tab
          final uri = Uri.parse(downloadUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            debugPrint('File opened in browser');
          } else {
            throw Exception('Could not launch URL');
          }
        } else {
          // For mobile, open file
          final uri = Uri.parse(downloadUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
            debugPrint('File opened on mobile');
          } else {
            throw Exception('Could not launch URL');
          }
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$fileName downloaded successfully')),
          );
        }
    } catch (e) {
      debugPrint('Error downloading attachment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to download file')),
        );
      }
    }
  }

  // Helper method to format file size
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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
        'assignedTo': _selectedAssignees,
        'priority': _selectedPriority,
        'dueDate': _expiryDate.toIso8601String(),
        'bucketId': widget.bucketId?.toString(),
        'bucketGuid': widget.bucketId?.toString(),
        'bucketName': widget.bucketName,
        'projectId': widget.projectId.toString(),
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
      
      // Upload files if any were selected
      if (_selectedFiles.isNotEmpty) {
        setState(() {
          _isUploadingFiles = true;
        });

        final taskGuid = resultTask['guid']?.toString();
        if (taskGuid != null && taskGuid.isNotEmpty) {
          for (final file in _selectedFiles) {
            try {
              if (kIsWeb) {
                // For web, use bytes instead of path
                if (file.bytes != null) {
                  await _apiService.uploadFileToTaskFromBytes(taskGuid, file.bytes!, file.name);
                  debugPrint('Uploaded file (web): ${file.name}');
                } else {
                  debugPrint('File bytes are null for web upload: ${file.name}');
                }
              } else {
                // For mobile, use path
                if (file.path != null) {
                  await _apiService.uploadFileToTask(taskGuid, file.path!);
                  debugPrint('Uploaded file (mobile): ${file.name}');
                } else {
                  debugPrint('File path is null for mobile upload: ${file.name}');
                }
              }
            } catch (e) {
              debugPrint('Error uploading file ${file.name}: $e');
              // Continue with other files even if one fails
            }
          }
        }
      }
      
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
          _isUploadingFiles = false;
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
                child: _isSaving 
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 12),
                        Text(_isUploadingFiles 
                          ? 'Uploading files...' 
                          : 'Saving task...'),
                      ],
                    )
                  : Text(widget.isEditMode ? 'UPDATE' : 'CREATE'),
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
                            const Text('Assignee(s)'),
                            const SizedBox(height: 8),
                            if (_errorMessage.isNotEmpty) 
                              Text(_errorMessage, style: const TextStyle(color: Colors.red, fontSize: 12)),
                            // Multi-select widget
                            _projectEmployees.isEmpty
                              ? const Text('No employees available')
                              : MultiSelectDialogField<String>(
                                  items: _projectEmployees.map((employee) {
                                      final employeeId = employee['id']?.toString() ?? 
                                                         employee['guid']?.toString() ?? 
                                                         employee['email']?.toString();
                                    if (employeeId == null) return null;
                                      final employeeName = employee['fullName'] ?? 
                                                           employee['name'] ?? 
                                                           employee['userName'] ?? 
                                                           employee['email'] ?? 
                                                           'Unknown User';
                                    return MultiSelectItem<String>(employeeId, employeeName.toString());
                                  }).whereType<MultiSelectItem<String>>().toList(),
                                  initialValue: _selectedAssignees.whereType<String>().toList(),
                                  title: const Text('Select Assignees'),
                                  buttonText: const Text('Select Assignees'),
                                  searchable: true,
                                  listType: MultiSelectListType.LIST,
                                  onConfirm: (values) {
                                    setState(() {
                                      _selectedAssignees = values.whereType<String>().toList();
                                    });
                                  },
                                  chipDisplay: MultiSelectChipDisplay(
                                    onTap: (value) {
                                      setState(() {
                                        _selectedAssignees.remove(value);
                                      });
                                    },
                                  ),
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
                  const SizedBox(height: 16),
                  
                  // File attachment section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.isEditMode ? 'New Attachments' : 'Attachments',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.attach_file),
                        label: const Text('Add Files'),
                        onPressed: _pickFiles,
                      ),
                    ],
                  ),
                  
                  // Show existing attachments in edit mode
                  if (widget.isEditMode && _existingAttachments.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Existing Attachments',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: _existingAttachments.map((attachment) {
                              final fileName = attachment['fileName'] ?? 'Unnamed file';
                              final fileSize = attachment['fileSize'] as int?;
                              
                              return ListTile(
                                leading: const Icon(Icons.insert_drive_file),
                                title: Text(fileName),
                                subtitle: fileSize != null 
                                  ? Text(_formatFileSize(fileSize))
                                  : null,
                                trailing: IconButton(
                                  icon: const Icon(Icons.download),
                                  onPressed: () => _downloadExistingAttachment(attachment),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),

                  // Show selected files
                  if (_selectedFiles.isNotEmpty)
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: _selectedFiles.asMap().entries.map((entry) {
                          final index = entry.key;
                          final file = entry.value;
                          
                          return ListTile(
                            leading: const Icon(Icons.insert_drive_file),
                            title: Text(file.name),
                            subtitle: Text(_formatFileSize(file.size)),
                            trailing: IconButton(
                              icon: const Icon(Icons.remove_circle, color: Colors.red),
                              onPressed: () => _removeFile(index),
                            ),
                          );
                        }).toList(),
                      ),
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