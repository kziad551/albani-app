import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/app_header.dart';
import '../widgets/app_drawer.dart';
import 'edit_project_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import '../config/app_config.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ProjectSettingsScreen extends StatefulWidget {
  final dynamic projectId;
  final String projectName;
  final Map<String, dynamic>? projectDetails;

  const ProjectSettingsScreen({
    super.key,
    required this.projectId,
    required this.projectName,
    this.projectDetails,
  });

  @override
  State<ProjectSettingsScreen> createState() => _ProjectSettingsScreenState();
}

class _ProjectSettingsScreenState extends State<ProjectSettingsScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String _errorMessage = '';
  Map<String, dynamic> _projectData = {};
  List<Map<String, dynamic>> _projectBuckets = [];
  List<Map<String, dynamic>> _projectUsers = [];
  Map<String, bool> _expandedBuckets = {};

  @override
  void initState() {
    super.initState();
    _loadProjectData();
  }

  Future<void> _loadProjectData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // First validate token
      final isValid = await _apiService.validateToken();
      if (!isValid) {
        throw Exception('Please log in again to continue');
      }

      // Get project details
      Map<String, dynamic> projectDetails;
      if (widget.projectDetails != null) {
        projectDetails = widget.projectDetails!;
      } else {
        projectDetails = await _apiService.getProjectById(widget.projectId);
      }

      // Debug project details to find buckets
      debugPrint('\n=== Project Details ===');
      debugPrint('Project ID: ${projectDetails['id']}');
      debugPrint('Project GUID: ${projectDetails['guid']}');
      debugPrint('Project Title: ${projectDetails['title']}');
      
      // Debug all keys in project details to locate buckets
      debugPrint('Available keys in project details: ${projectDetails.keys.toList()}');
      
      // Load project employees using the correct endpoint
      final projectGuid = projectDetails['guid'] ?? widget.projectId;
      
      debugPrint('Loading users for project with ID: $projectGuid');
      
      // Use the correct API endpoint
      List<Map<String, dynamic>> projectUsers = [];
      
      try {
        // Get token from secure storage
        final storage = const FlutterSecureStorage();
        final token = await storage.read(key: 'accessToken');
        
        if (token != null) {
          // Use the exact API endpoint provided
          final response = await http.get(
            Uri.parse('${AppConfig.apiBaseUrl}/api/Projects/GetProjectEmployees?ProjectGuid=$projectGuid'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          );
          
          debugPrint('Project employees API response status: ${response.statusCode}');
          
          if (response.statusCode == 200 && response.body.isNotEmpty) {
            debugPrint('Project employees API response body: ${response.body.substring(0, min(100, response.body.length))}...');
            
            final responseData = jsonDecode(response.body);
            if (responseData is List) {
              projectUsers = List<Map<String, dynamic>>.from(responseData);
              debugPrint('Retrieved ${projectUsers.length} employees as List');
            } else if (responseData is Map) {
              final data = responseData['data'] ?? responseData['items'] ?? responseData['users'] ?? [];
              if (data is List) {
                projectUsers = List<Map<String, dynamic>>.from(data);
                debugPrint('Retrieved ${projectUsers.length} employees from data field');
              }
            }
          } else {
            debugPrint('Error response: ${response.body}');
          }
        } else {
          debugPrint('No access token available for API call');
        }
      } catch (e) {
        debugPrint('Error getting project employees: $e');
        
        // Fallback method
        try {
          final userResponse = await _apiService.get('api/Projects/GetProjectEmployees?ProjectGuid=$projectGuid');
          
          if (userResponse != null) {
            if (userResponse is List) {
              projectUsers = List<Map<String, dynamic>>.from(userResponse);
            } else if (userResponse is Map) {
              final data = userResponse['data'] ?? userResponse['items'] ?? userResponse['users'] ?? [];
              if (data is List) {
                projectUsers = List<Map<String, dynamic>>.from(data);
              }
            }
          }
        } catch (e2) {
          debugPrint('Error getting project users with fallback method: $e2');
        }
      }
      
      // Debug the result
      debugPrint('Found ${projectUsers.length} users for project');
      if (projectUsers.isNotEmpty) {
        for (final user in projectUsers) {
          final name = user['name'] ?? 
                     user['Name'] ?? 
                     '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim() ?? 
                     user['username'] ?? 
                     user['userName'] ?? 
                     'Unknown';
          final id = user['id'] ?? user['userId'] ?? user['employeeId'] ?? 'No ID';
          debugPrint('Project user: $name (ID: $id)');
        }
      } else {
        debugPrint('No users found for this project!');
      }

      // Extract buckets from project details instead of making a separate API call
      List<Map<String, dynamic>> buckets = [];
      
      // Look for buckets in various possible locations in the response
      if (projectDetails.containsKey('buckets') && projectDetails['buckets'] is List) {
        debugPrint('Found buckets in project details under "buckets" key');
        final bucketsList = projectDetails['buckets'] as List;
        buckets = List<Map<String, dynamic>>.from(bucketsList);
        debugPrint('Extracted ${buckets.length} buckets from "buckets" field');
      } else if (projectDetails.containsKey('Buckets') && projectDetails['Buckets'] is List) {
        debugPrint('Found buckets in project details under "Buckets" key (capital B)');
        final bucketsList = projectDetails['Buckets'] as List;
        buckets = List<Map<String, dynamic>>.from(bucketsList);
        debugPrint('Extracted ${buckets.length} buckets from "Buckets" field');
      } else {
        debugPrint('No buckets found in direct project details keys, checking for nested data');
        
        // Try to find buckets in a nested data structure
        try {
          // Sometimes API responses nest data under 'data', 'items', 'result', etc.
          for (final key in ['data', 'items', 'result', 'results']) {
            if (projectDetails.containsKey(key) && projectDetails[key] is Map) {
              final nestedData = projectDetails[key] as Map;
              
              if (nestedData.containsKey('buckets') && nestedData['buckets'] is List) {
                debugPrint('Found buckets in nested data under "$key.buckets"');
                final bucketsList = nestedData['buckets'] as List;
                buckets = List<Map<String, dynamic>>.from(bucketsList);
                debugPrint('Extracted ${buckets.length} buckets from "$key.buckets" field');
                break;
              } else if (nestedData.containsKey('Buckets') && nestedData['Buckets'] is List) {
                debugPrint('Found buckets in nested data under "$key.Buckets"');
                final bucketsList = nestedData['Buckets'] as List;
                buckets = List<Map<String, dynamic>>.from(bucketsList);
                debugPrint('Extracted ${buckets.length} buckets from "$key.Buckets" field');
                break;
              }
            }
          }
        } catch (e) {
          debugPrint('Error while trying to find buckets in nested data: $e');
        }
        
        // If still no buckets, make API call
        if (buckets.isEmpty) {
          debugPrint('No buckets found in project details, trying direct API call to fetch buckets');
          
          try {
            final response = await _apiService.get('api/Projects/GetProjectBuckets?projectGuid=$projectGuid');
            
            if (response != null) {
              debugPrint('Response from GetProjectBuckets API: $response');
              
              if (response is List) {
                buckets = List<Map<String, dynamic>>.from(response);
                debugPrint('Retrieved ${buckets.length} buckets from direct API call as List');
              } else if (response is Map) {
                // Try various possible locations of bucket data in the response
                for (final key in ['data', 'items', 'result', 'results', 'buckets', 'Buckets']) {
                  if (response.containsKey(key) && response[key] is List) {
                    final bucketsList = response[key] as List;
                    buckets = List<Map<String, dynamic>>.from(bucketsList);
                    debugPrint('Retrieved ${buckets.length} buckets from direct API call under "$key" field');
                    break;
                  }
                }
                
                // If still empty, check if the response itself is a bucket list
                if (buckets.isEmpty && response.containsKey('id') && response.containsKey('description')) {
                  buckets = [Map<String, dynamic>.from(response)];
                  debugPrint('Retrieved 1 bucket from direct API call (response is a single bucket)');
                }
              }
            }
          } catch (e) {
            debugPrint('Error fetching buckets from API: $e');
          }
          
          // If still no buckets, try fallback to the hierarchy endpoint
          if (buckets.isEmpty) {
            debugPrint('Still no buckets, trying hierarchy endpoint as fallback');
            try {
              final bucketsResponse = await _apiService.get('api/buckets/hierarchy/${projectGuid.toString()}');
              
              if (bucketsResponse != null) {
                if (bucketsResponse is List) {
                  buckets = List<Map<String, dynamic>>.from(bucketsResponse);
                  debugPrint('Retrieved ${buckets.length} buckets from hierarchy endpoint as List');
                } else if (bucketsResponse is Map) {
                  for (final key in ['data', 'items', 'result', 'results', 'buckets', 'Buckets']) {
                    if (bucketsResponse.containsKey(key) && bucketsResponse[key] is List) {
                      final bucketsList = bucketsResponse[key] as List;
                      buckets = List<Map<String, dynamic>>.from(bucketsList);
                      debugPrint('Retrieved ${buckets.length} buckets from hierarchy endpoint under "$key" field');
                      break;
                    }
                  }
                }
              }
            } catch (e) {
              debugPrint('Error fetching buckets from hierarchy endpoint: $e');
            }
          }
        }
      }
      
      // Debug the buckets in detail
      debugPrint('\n=== Bucket Details ===');
      debugPrint('Found ${buckets.length} buckets total');
      
      if (buckets.isNotEmpty) {
        debugPrint('First bucket sample: ${buckets.first}');
        debugPrint('Keys in first bucket: ${buckets.first.keys.toList()}');
        
        for (int i = 0; i < buckets.length; i++) {
          final bucket = buckets[i];
          final displayName = bucket['displayName'] ?? 
                           bucket['name'] ?? 
                           bucket['title'] ?? 
                           bucket['description'] ?? 
                           'Unnamed Bucket';
          final description = bucket['description'] ?? 'No description';
          final id = bucket['id'] ?? bucket['guid'] ?? 'No ID';
          final line = bucket['line']?.toString() ?? 'No line';
          debugPrint('Bucket $i: $displayName - $description (ID: $id, Line: $line)');
        }
      }

      // If buckets are still empty, try direct fetch using HTTP
      if (buckets.isEmpty) {
        debugPrint('Trying direct HTTP fetch for buckets as last resort');
        buckets = await _fetchBucketsDirectly(projectGuid.toString());
      }

      if (!mounted) return;

      setState(() {
        _projectData = projectDetails;
        _projectUsers = projectUsers;
        _projectBuckets = buckets;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading project data: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  // Helper method to fetch buckets directly using HTTP requests
  Future<List<Map<String, dynamic>>> _fetchBucketsDirectly(String projectGuid) async {
    List<Map<String, dynamic>> buckets = [];
    
    try {
      // Get token from secure storage
      final storage = const FlutterSecureStorage();
      final token = await storage.read(key: 'accessToken');
      
      if (token == null) {
        debugPrint('No access token available for direct bucket fetch');
        return [];
      }
      
      // Try multiple endpoints that might contain bucket data
      final endpoints = [
        '/api/Buckets/GetProjectBuckets?projectGuid=$projectGuid',
        '/api/Projects/$projectGuid/buckets',
        '/api/Projects/GetProjectBuckets?projectGuid=$projectGuid',
        '/api/Buckets?projectGuid=$projectGuid',
        '/api/buckets/list/$projectGuid',
      ];
      
      for (final endpoint in endpoints) {
        try {
          debugPrint('Trying endpoint: $endpoint');
          
          final response = await http.get(
            Uri.parse('${AppConfig.apiBaseUrl}$endpoint'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          );
          
          if (response.statusCode == 200 && response.body.isNotEmpty) {
            debugPrint('Success with endpoint: $endpoint');
            debugPrint('Response: ${response.body.substring(0, min(100, response.body.length))}...');
            
            final data = jsonDecode(response.body);
            
            if (data is List) {
              buckets = List<Map<String, dynamic>>.from(data);
              debugPrint('Found ${buckets.length} buckets as direct list');
              if (buckets.isNotEmpty) {
                break; // We found our buckets, stop trying other endpoints
              }
            } else if (data is Map) {
              // Look for bucket data in common response patterns
              bool foundBuckets = false;
              for (final key in ['data', 'items', 'result', 'results', 'buckets', 'Buckets']) {
                if (data.containsKey(key) && data[key] is List) {
                  final bucketsList = data[key] as List;
                  if (bucketsList.isNotEmpty) {
                    buckets = List<Map<String, dynamic>>.from(bucketsList);
                    debugPrint('Found ${buckets.length} buckets in "$key" field');
                    foundBuckets = true;
                    break;
                  }
                }
              }
              
              if (foundBuckets) {
                break; // We found our buckets, stop trying other endpoints
              }
            }
          } else {
            debugPrint('Failed with endpoint: $endpoint, status: ${response.statusCode}');
          }
        } catch (e) {
          debugPrint('Error with endpoint $endpoint: $e');
        }
      }
    } catch (e) {
      debugPrint('Error in direct bucket fetch: $e');
    }
    
    return buckets;
  }

  void _showAddBucketDialog({Map<String, dynamic>? parentBucket}) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(parentBucket != null ? 'Add Sub Bucket' : 'New Bucket'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final projectGuid = _projectData['guid'] ?? widget.projectId;
                
                // Calculate next line number for proper ordering
                int nextLine = 0;
                if (_projectBuckets.isNotEmpty) {
                  try {
                    // Find the highest line number and add 1
                    nextLine = _projectBuckets
                      .map((b) => int.tryParse(b['line']?.toString() ?? '0') ?? 0)
                      .reduce((a, b) => a > b ? a : b) + 1;
                  } catch (e) {
                    debugPrint('Error calculating next line: $e');
                  }
                }
                
                // Create bucket data with the correct format for the API
                final bucketData = {
                  'displayName': nameController.text,
                  'description': descriptionController.text,
                  'projectGuid': projectGuid.toString(),
                  'line': nextLine,
                  if (parentBucket != null && parentBucket.containsKey('guid')) 
                    'parentGuid': parentBucket['guid']?.toString(),
                  if (parentBucket != null && parentBucket.containsKey('id') && !parentBucket.containsKey('guid')) 
                    'parentId': parentBucket['id']?.toString(),
                };

                debugPrint('Creating bucket with data: $bucketData');
                
                // Call API to create bucket
                await _apiService.post('api/buckets', bucketData);
                
                if (mounted) {
                  Navigator.pop(context);
                  _loadProjectData(); // Refresh data
                }
              } catch (e) {
                if (mounted) {
                  debugPrint('Error creating bucket: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error creating bucket: $e')),
                  );
                }
              }
            },
            child: const Text('ADD'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Project'),
        content: const Text('Are you sure you want to delete this project? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final projectGuid = _projectData['guid'] ?? widget.projectId;
                await _apiService.deleteProject(projectGuid.toString());
                if (mounted) {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Go back to projects screen
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting project: $e')),
                  );
                }
              }
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildBucketTree(Map<String, dynamic> bucket, {int level = 0}) {
    // Get subBuckets from 'children' key or empty list if not present
    final List<dynamic> subBuckets = bucket['children'] ?? [];
    final bool hasSubBuckets = subBuckets.isNotEmpty;
    
    // Use guid, id, or generate a unique ID based on description and line
    final String bucketId = bucket['guid']?.toString() ?? 
                          bucket['id']?.toString() ?? 
                          '${bucket['description'] ?? ''}_${bucket['line'] ?? ''}';
    
    final bool isExpanded = _expandedBuckets[bucketId] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: hasSubBuckets 
            ? () {
                setState(() {
                  _expandedBuckets[bucketId] = !isExpanded;
                });
              }
            : null,
          child: Padding(
            padding: EdgeInsets.only(left: level * 20.0),
            child: Row(
              children: [
                if (hasSubBuckets)
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                    size: 24,
                    color: Colors.grey,
                  )
                else
                  const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Display name with bold text
                      Text(
                        bucket['displayName'] ?? 
                        bucket['name'] ?? 
                        bucket['title'] ?? 
                        'Unnamed Bucket',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      // Display description if available
                      if (bucket['description'] != null && bucket['description'].toString().isNotEmpty)
                        Text(
                          bucket['description'],
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      if (bucket['percentage'] != null)
                        Text(
                          'Progress: ${bucket['percentage']}%',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      if (bucket['line'] != null)
                        Text(
                          'Line: ${bucket['line']}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 20),
                  onPressed: () => _showAddBucketDialog(parentBucket: bucket),
                  tooltip: 'Add Sub Bucket',
                ),
              ],
            ),
          ),
        ),
        if (hasSubBuckets && isExpanded)
          Column(
            children: [
              for (var subBucket in subBuckets)
                _buildBucketTree(subBucket as Map<String, dynamic>, level: level + 1),
            ],
          ),
      ],
    );
  }

  // Add method to show user selection dialog
  void _showAddUserDialog() async {
    try {
      setState(() => _isLoading = true);
      
      // Fetch all users
      final allUsers = await _apiService.getUsers();
      
      if (!mounted) return;
      setState(() => _isLoading = false);

      // Get the set of existing user IDs from the project users
      // Check multiple possible ID field names since API responses can vary
      final existingUserIds = _projectUsers.map((u) => 
        u['id']?.toString() ?? 
        u['userId']?.toString() ?? 
        u['employeeId']?.toString() ?? 
        ''
      ).toSet();

      debugPrint('Existing user IDs in project: $existingUserIds');
      
      // Filter out users that are already in the project
      final availableUsers = allUsers.where((u) {
        final userId = u['id']?.toString() ?? 
                      u['userId']?.toString() ?? 
                      u['employeeId']?.toString() ?? 
                      '';
                      
        // Return true if this user is not in the project
        final notInProject = userId.isNotEmpty && !existingUserIds.contains(userId);
        return notInProject;
      }).toList();

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Add User to Project'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400, // Fixed height for scrollable content
            child: Column(
              children: [
                Expanded(
                  child: availableUsers.isEmpty
                      ? const Center(
                          child: Text(
                            'No available users to add',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: availableUsers.length,
                          itemBuilder: (context, index) {
                            final user = availableUsers[index];
                            final name = user['name'] ?? 
                                       '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim() ?? 
                                       user['username'] ?? 
                                       'Unknown User';
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue.shade100,
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                  style: TextStyle(
                                    color: Colors.blue.shade900,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(name),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (user['email'] != null && user['email'].toString().isNotEmpty)
                                    Text(user['email'].toString()),
                                  if (user['role'] != null && user['role'].toString().isNotEmpty)
                                    Container(
                                      margin: const EdgeInsets.only(top: 4),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        user['role'].toString(),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue.shade700,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              onTap: () async {
                                try {
                                  final projectGuid = _projectData['guid'] ?? widget.projectId;
                                  final userGuid = user['guid']?.toString();
                                  
                                  if (userGuid == null) {
                                    throw Exception('Employee GUID not found');
                                  }

                                  debugPrint('Adding employee with GUID: $userGuid to project: $projectGuid');
                                  
                                  // Use the correct API endpoint for adding employees to a project
                                  await _apiService.post(
                                    'api/Projects/AddEmployeesToProject',
                                    {
                                      'projectGuid': projectGuid.toString(),
                                      'employeeGuids': [userGuid]
                                    },
                                  );
                                  
                                  if (mounted) {
                                    Navigator.pop(context);
                                    _loadProjectData(); // Refresh data
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error adding user: $e')),
                                    );
                                  }
                                }
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading users: $e')),
        );
      }
    }
  }

  // Add method to remove user from project
  Future<void> _removeUser(Map<String, dynamic> user) async {
    try {
      final projectGuid = _projectData['guid'] ?? widget.projectId;
      
      // Check different possible ID field names
      final userId = user['id']?.toString() ?? 
                    user['userId']?.toString() ?? 
                    user['employeeId']?.toString();
                    
      if (userId == null || userId.isEmpty) {
        throw Exception('User ID not found');
      }
      
      // Use the corresponding remove endpoint
      await _apiService.delete('api/Projects/RemoveEmployeeFromProject?projectGuid=$projectGuid&employeeId=$userId');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User removed successfully')),
        );
        _loadProjectData(); // Refresh data
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing user: $e')),
        );
      }
    }
  }

  // Add method to show remove user confirmation
  void _showRemoveUserConfirmation(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove User'),
        content: Text('Are you sure you want to remove ${user['name']} from this project?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _removeUser(user);
            },
            child: const Text('REMOVE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildUserList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _projectUsers.length,
      itemBuilder: (context, index) {
        final user = _projectUsers[index];
        
        // Get user name from various possible fields
        final name = user['name'] ?? 
                    user['Name'] ?? 
                    '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim() ?? 
                    user['username'] ?? 
                    user['userName'] ?? 
                    'Unknown User';
                    
        // Get user email
        final email = user['email'] ?? 
                     user['Email'] ?? 
                     user['emailAddress'] ?? 
                     '';
                     
        // Get user role
        final role = user['role'] ?? 
                    user['Role'] ?? 
                    user['userRole'] ?? 
                    'No Role';
        
        // Get user initial for avatar
        final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
        
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.shade100,
              child: Text(
                initial,
                style: TextStyle(
                  color: Colors.blue.shade900,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (email.isNotEmpty) 
                  Text(
                    email,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    role,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            trailing: role.toLowerCase() != 'owner' && role.toLowerCase() != 'admin'
              ? IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                  onPressed: () => _showRemoveUserConfirmation(user),
                  tooltip: 'Remove User',
                )
              : role.toLowerCase() == 'owner'
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Owner',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber.shade900,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                : null,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AppHeader(showBackButton: true),
      endDrawer: const AppDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        'Error: $_errorMessage',
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadProjectData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Project Details Section
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Project Details',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit),
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => EditProjectScreen(
                                                  projectId: int.tryParse(_projectData['id']?.toString() ?? '') ?? 0,
                                                  title: _projectData['title'] ?? '',
                                                  description: _projectData['description'] ?? '',
                                                  location: _projectData['location'] ?? '',
                                                  status: _projectData['status'] ?? 'In Progress',
                                                ),
                                              ),
                                            ).then((_) => _loadProjectData());
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red),
                                          onPressed: _showDeleteConfirmation,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const Divider(),
                                _buildDetailRow('Title', _projectData['title'] ?? 'N/A'),
                                _buildDetailRow('Location', _projectData['location'] ?? 'N/A'),
                                _buildDetailRow('Description', _projectData['description'] ?? 'N/A'),
                                _buildDetailRow('Status', _projectData['status'] ?? 'N/A'),
                                _buildDetailRow('Manager', _projectData['managedBy'] ?? 'N/A'),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Buckets Configuration Section
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Bucket Configuration',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.refresh),
                                          onPressed: _loadProjectData,
                                          tooltip: 'Refresh Buckets',
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add),
                                          onPressed: () => _showAddBucketDialog(),
                                          tooltip: 'Add Bucket',
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const Divider(),
                                _projectBuckets.isEmpty
                                  ? Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(20.0),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(
                                              Icons.folder_off,
                                              size: 48,
                                              color: Colors.grey,
                                            ),
                                            const SizedBox(height: 16),
                                            const Text(
                                              'No buckets found for this project',
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.grey,
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            ElevatedButton.icon(
                                              onPressed: _loadProjectData,
                                              icon: const Icon(Icons.refresh),
                                              label: const Text('Refresh'),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: _projectBuckets.length,
                                      itemBuilder: (context, index) {
                                        final bucket = _projectBuckets[index];
                                        return _buildBucketTree(bucket);
                                      },
                                    ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Project Users Section
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Project Users',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.person_add),
                                      onPressed: _showAddUserDialog,
                                    ),
                                  ],
                                ),
                                const Divider(),
                                _buildUserList(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
} 