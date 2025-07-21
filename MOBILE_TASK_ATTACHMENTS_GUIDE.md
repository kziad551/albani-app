# 📱 Mobile App - Task Attachments Implementation Guide

## 🎯 **Objective**
Add the ability to upload files to individual tasks and view task attachments in the mobile app, matching the functionality implemented in the web application.

## 🔍 **Current Mobile App Analysis**
Based on your existing codebase in `/mobileapp/lib/`, you already have:
- ✅ **File upload to buckets** working (`ApiService.uploadFile`)
- ✅ **File download/viewing** working (`ApiService.getFileDownloadUrl`)
- ✅ **Task creation/editing** working (`CreateTaskScreen`)
- ✅ **Task display** working (`ProjectDetailsScreen`)

## 🆕 **What's New in Web App (To Implement in Mobile)**
The web app now has **TASK-SPECIFIC ATTACHMENTS** in addition to bucket files:

### **Web Implementation Analysis:**
1. **Task Attachments API**: `/api/Attachments/GetTaskAttachments?TaskGuid=...`
2. **Task Creation with Files**: Upload files during task creation
3. **Task View with Attachments**: Show attached files when viewing task details
4. **Separate from Bucket Files**: Task attachments are different from general bucket files

---

## 🛠️ **Implementation Steps**

### **Step 1: Add New API Method for Task Attachments**

Add this method to your `lib/services/api_service.dart`:

```dart
// Get attachments for a specific task
Future<List<Map<String, dynamic>>> getTaskAttachments(String taskGuid) async {
  try {
    if (!await hasInternetConnection()) {
      throw Exception('No internet connection');
    }
    
    // Don't try to fetch data for invalid task GUIDs
    if (taskGuid.isEmpty || !taskGuid.contains('-')) {
      debugPrint('Invalid task GUID provided: $taskGuid');
      return [];
    }
    
    debugPrint('Getting attachments for task: $taskGuid');
    
    // Get token for authentication
    final token = await storage.read(key: 'accessToken');
    if (token == null) {
      throw Exception('No authentication token found');
    }

    try {
      final response = await _dio.get(
        '/api/Attachments/GetTaskAttachments',
        queryParameters: {'TaskGuid': taskGuid},
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
            'Host': AppConfig.apiHost,
          },
        ),
      );
      
      debugPrint('Task attachments response status: ${response.statusCode}');
      debugPrint('Task attachments response data: ${response.data}');

      if (response.statusCode == 200) {
        if (response.data is List) {
          return List<Map<String, dynamic>>.from(response.data);
        } else if (response.data is Map) {
          final data = response.data as Map<String, dynamic>;
          if (data['data'] != null && data['data'] is List) {
            return List<Map<String, dynamic>>.from(data['data']);
          } else if (data['result'] != null && data['result'] is List) {
            return List<Map<String, dynamic>>.from(data['result']);
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching task attachments: $e');
    }
    
    return [];
  } catch (e) {
    debugPrint('Error getting task attachments: $e');
    return [];
  }
}

// Upload file directly to a task (alternative to bucket upload)
Future<Map<String, dynamic>> uploadFileToTask(String taskGuid, String filePath) async {
  try {
    if (!await hasInternetConnection()) {
      throw Exception('No internet connection');
    }
    
    debugPrint('Uploading file to task: $taskGuid');
    debugPrint('File path: $filePath');
    
    // Get the file name from the path
    final fileName = filePath.split('/').last;
    
    // Create form data with the file and task GUID
    final formData = FormData.fromMap({
      'taskGuid': taskGuid,
      'BucketTaskGuid': taskGuid, // Alternative parameter name
      'file': await MultipartFile.fromFile(
        filePath,
        filename: fileName,
        contentType: MediaType.parse('application/octet-stream'),
      ),
    });
    
    // Get headers and URL
    final headers = await _getHeaders();
    final baseUrl = await getBaseUrl();
    
    // Add specific headers for multipart uploads
    headers['Content-Type'] = 'multipart/form-data';
    
    debugPrint('Making task file upload request to: $baseUrl/api/Attachments/AddTaskAttachment');
    
    // Try task-specific endpoint
    try {
      final response = await _dio.post(
        '$baseUrl/api/Attachments/AddTaskAttachment',
        data: formData,
        options: Options(
          headers: headers,
          followRedirects: true,
          validateStatus: (status) => status! < 500,
        ),
      );
      
      debugPrint('Task upload response: ${response.statusCode}');
      debugPrint('Response data: ${response.data}');
      
      if (response.statusCode! >= 200 && response.statusCode! < 300) {
        if (response.data is Map) {
          final uploadedFile = Map<String, dynamic>.from(response.data);
          debugPrint('File uploaded successfully to task: ${uploadedFile['id'] ?? uploadedFile['guid']}');
          return uploadedFile;
        }
      }
    } catch (e) {
      debugPrint('Task-specific upload failed: $e, falling back to bucket upload');
      
      // Fallback: Get bucket GUID from task and upload to bucket
      // You may need to fetch task details to get bucketGuid
      throw Exception('Task file upload failed: $e');
    }
    
    throw Exception('Failed to upload file to task');
  } catch (e) {
    debugPrint('Error uploading file to task: $e');
    throw Exception('Failed to upload file to task: $e');
  }
}
```

### **Step 2: Update Task Detail View**

Modify your task detail modal in `lib/screens/project_details_screen.dart`:

```dart
// In the task detail bottom sheet, add attachments section
Widget _buildTaskDetailSheet(Map<String, dynamic> task, String bucketGuid) {
  return DraggableScrollableSheet(
    initialChildSize: 0.6,
    maxChildSize: 0.9,
    minChildSize: 0.4,
    expand: false,
    builder: (context, scrollController) {
      return Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ... existing task details (title, status, priority, etc.) ...
            
            // NEW: Task Attachments Section
            const Divider(),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Attachments',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            
            // Task attachments list
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _apiService.getTaskAttachments(task['guid']?.toString() ?? ''),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final attachments = snapshot.data ?? [];
                
                if (attachments.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'No attachments found for this task',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }
                
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: attachments.length,
                  itemBuilder: (context, index) {
                    final attachment = attachments[index];
                    final fileName = attachment['fileName'] ?? 
                                   attachment['name'] ?? 
                                   'Unnamed File';
                    
                    return ListTile(
                      leading: _getFileIcon(attachment['fileExtension'] ?? ''),
                      title: Text(fileName),
                      subtitle: Text(
                        'Size: ${_formatFileSize(attachment['fileSize'] ?? 0)}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.download),
                        onPressed: () async {
                          // Download the attachment
                          final fileGuid = attachment['guid'];
                          if (fileGuid != null) {
                            // Use existing download logic
                            // ... (implement download similar to bucket files)
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),
            
            // Add attachment button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.attach_file),
                label: const Text('Add Attachment'),
                onPressed: () async {
                  // Show file picker and upload to task
                  final result = await FilePicker.platform.pickFiles();
                  
                  if (result != null && result.files.isNotEmpty) {
                    final file = result.files.first;
                    if (file.path != null) {
                      try {
                        await _apiService.uploadFileToTask(
                          task['guid']?.toString() ?? '',
                          file.path!,
                        );
                        
                        // Refresh the sheet
                        setState(() {});
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('File attached successfully'),
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error uploading file: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  }
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

// Helper method to format file size
String _formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
```

### **Step 3: Update Task Creation Screen**

Modify `lib/screens/create_task_screen.dart` to allow attaching files during task creation:

```dart
class _CreateTaskScreenState extends State<CreateTaskScreen> {
  // ... existing variables ...
  
  // NEW: Add file attachment variables
  List<PlatformFile> _selectedFiles = [];
  bool _isUploadingFiles = false;

  // ... existing methods ...

  // NEW: Method to handle file selection
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

  // NEW: Method to remove selected file
  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  // UPDATE: Modify the save task method
  Future<void> _saveTask() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a task title'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Prepare task data
      final taskData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'status': _selectedStatus,
        'priority': _selectedPriority,
        'assignedTo': _selectedAssignees.isNotEmpty ? _selectedAssignees.first : null,
        'bucketId': widget.bucketId,
        'bucketGuid': widget.bucketId,
        'dueDate': _expiryDate.toIso8601String(),
      };

      // Create or update the task first
      Map<String, dynamic> savedTask;
      if (widget.existingTask != null) {
        taskData['id'] = widget.existingTask!['id'];
        taskData['guid'] = widget.existingTask!['guid'];
        savedTask = await _apiService.updateTask(taskData);
      } else {
        savedTask = await _apiService.createTask(taskData);
      }

      // Upload files if any were selected
      if (_selectedFiles.isNotEmpty) {
        setState(() {
          _isUploadingFiles = true;
        });

        final taskGuid = savedTask['guid']?.toString();
        if (taskGuid != null && taskGuid.isNotEmpty) {
          for (final file in _selectedFiles) {
            if (file.path != null) {
              try {
                await _apiService.uploadFileToTask(taskGuid, file.path!);
                debugPrint('Uploaded file: ${file.name}');
              } catch (e) {
                debugPrint('Error uploading file ${file.name}: $e');
                // Continue with other files even if one fails
              }
            }
          }
        }
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onTaskCreated?.call(savedTask);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existingTask != null 
                ? 'Task updated successfully' 
                : 'Task created successfully'
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving task: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _isUploadingFiles = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ... existing app bar and body ...
      
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ... existing form fields (title, description, etc.) ...
            
            // NEW: File attachment section
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Attachments',
                  style: TextStyle(
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
            
            // Save button (update to show upload progress)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveTask,
                child: _isSaving 
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
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
                  : Text(widget.existingTask != null ? 'Update Task' : 'Create Task'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

### **Step 4: Add Required Dependencies**

Make sure your `pubspec.yaml` includes:

```yaml
dependencies:
  file_picker: ^6.1.1  # For file selection
  # ... other existing dependencies
```

---

## 🔥 **Firebase Notifications**

**Good news!** Firebase notifications are already implemented:
- ✅ The backend sends notifications when tasks are assigned
- ✅ The mobile app just needs to register FCM tokens (already in your files)
- ✅ Use the existing `MOBILE_NOTIFICATION_INTEGRATION.md` guide

---

## 🧪 **Testing Your Implementation**

1. **Create a new task** with file attachments
2. **View the task** and verify attachments are displayed
3. **Download/open** an attachment
4. **Edit a task** and add more attachments
5. **Check** that task attachments are separate from bucket files

---

## 📋 **API Endpoints Summary**

Based on the backend logs, use these endpoints:

```
GET  /api/Attachments/GetTaskAttachments?TaskGuid={taskGuid}
POST /api/Attachments/AddTaskAttachment (with multipart form data)
GET  /api/Attachments/DownloadAttachment?AttachmentGuid={fileGuid}
```

---

## ⚠️ **Important Notes**

1. **Task GUID vs ID**: Always use the `guid` field for API calls, not the numeric `id`
2. **Authentication**: All requests need the `Authorization: Bearer {token}` header
3. **Error Handling**: The mobile app should gracefully handle upload failures
4. **File Size Limits**: Respect server file size limitations
5. **Offline Support**: Consider caching attachment metadata for offline viewing

---

## 🎯 **Expected Result**

After implementation, users should be able to:
- ✅ Attach files when creating tasks
- ✅ View all attachments for a specific task
- ✅ Download/open task attachments
- ✅ Add more attachments to existing tasks
- ✅ See task attachments separately from general bucket files

This will bring your mobile app to feature parity with the web application's new task attachment functionality! 