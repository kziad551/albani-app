import 'package:flutter/material.dart';
import '../widgets/app_header.dart';
import '../widgets/app_drawer.dart';
import '../services/api_service.dart';
import '../config/app_config.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  String? _errorMessage = null;
  final _searchController = TextEditingController();
  String _filterText = '';
  
  // Pagination
  int _currentPage = 1;
  int _totalUsers = 0;
  int _totalPages = 1;
  final int _usersPerPage = 10; // Display 10 users per page

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('Fetching users from API...');
      final response = await _apiService.getUsers();
      print('Fetched users response: $response');
      
      List<Map<String, dynamic>> usersList = [];
      
      if (response is List) {
        // Convert all items to Map<String, dynamic>
        for (var item in response) {
          if (item is Map<String, dynamic>) {
            usersList.add(item);
          }
        }
      }
      
      print('Processed ${usersList.length} users');
      
      if (mounted) {
        setState(() {
          _users = usersList;
          _totalUsers = usersList.length;
          _totalPages = 1;
          _currentPage = 1;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching users: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load users: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _changePage(int page) {
    if (page < 1 || page > _totalPages) {
      return;
    }
    
    setState(() {
      _currentPage = page;
    });
    
    _loadUsers();
  }

  String _getInitials(Map<String, dynamic> user) {
    final firstName = user['firstName'] ?? '';
    final lastName = user['lastName'] ?? '';
    
    if (firstName.isNotEmpty && lastName.isNotEmpty) {
      return '${firstName[0]}${lastName[0]}';
    } else if (firstName.isNotEmpty) {
      return firstName[0];
    } else if (lastName.isNotEmpty) {
      return lastName[0];
    } else if (user['username'] != null && user['username'].toString().isNotEmpty) {
      return user['username'][0];
    }
    
    return 'U';
  }

  String _getFullName(Map<String, dynamic> user) {
    final firstName = user['firstName'] ?? '';
    final lastName = user['lastName'] ?? '';
    
    if (firstName.isNotEmpty || lastName.isNotEmpty) {
      return '$firstName $lastName'.trim();
    } else if (user['name'] != null) {
      return user['name'];
    } else if (user['username'] != null) {
      return user['username'];
    }
    
    return 'Unknown User';
  }

  Color _getUserColor(int index) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.amber.shade700,
      Colors.deepOrange,
      Colors.cyan.shade700,
    ];
    
    return colors[index % colors.length];
  }

  List<Map<String, dynamic>> get _filteredUsers {
    if (_filterText.isEmpty) {
      return _users;
    }
    
    final query = _filterText.toLowerCase();
    return _users.where((user) {
      final name = _getFullName(user).toLowerCase();
      final username = (user['username'] ?? '').toString().toLowerCase();
      final email = (user['email'] ?? '').toString().toLowerCase();
      final phone = (user['phone'] ?? user['phoneNumber'] ?? '').toString().toLowerCase();
      
      return name.contains(query) || 
             username.contains(query) || 
             email.contains(query) || 
             phone.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AppHeader(),
      endDrawer: const AppDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadUsers,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Search users...',
                                prefixIcon: const Icon(Icons.search),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _filterText = value;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Users ($_totalUsers)',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _filteredUsers.isEmpty
                          ? const Center(
                              child: Text(
                                'No users found.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 16),
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadUsers,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _filteredUsers.length,
                                itemBuilder: (context, index) {
                                  final user = _filteredUsers[index];
                                  final initials = _getInitials(user);
                                  final fullName = _getFullName(user);
                                  
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      leading: CircleAvatar(
                                        backgroundColor: _getUserColor(index),
                                        child: Text(
                                          initials,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      title: Text(
                                        fullName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (user['email'] != null && user['email'].toString().isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 4),
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.email, size: 14),
                                                  const SizedBox(width: 4),
                                                  Text(user['email']),
                                                ],
                                              ),
                                            ),
                                          if (user['phone'] != null && user['phone'].toString().isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 4),
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.phone, size: 14),
                                                  const SizedBox(width: 4),
                                                  Text(user['phone']),
                                                ],
                                              ),
                                            ),
                                          if (user['role'] != null && user['role'].toString().isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 4),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: _getUserColor(index).withOpacity(0.2),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  user['role'],
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: _getUserColor(index),
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      isThreeLine: true,
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                    
                    // Pagination controls
                    if (_totalPages > 1)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_ios),
                              onPressed: _currentPage > 1
                                  ? () => _changePage(_currentPage - 1)
                                  : null,
                            ),
                            Text(
                              'Page $_currentPage of $_totalPages',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.arrow_forward_ios),
                              onPressed: _currentPage < _totalPages
                                  ? () => _changePage(_currentPage + 1)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
    );
  }
} 