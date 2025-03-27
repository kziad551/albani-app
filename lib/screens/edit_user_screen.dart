import 'package:flutter/material.dart';
import '../services/api_service.dart';

class EditUserScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const EditUserScreen({
    super.key,
    required this.user,
  });

  @override
  State<EditUserScreen> createState() => _EditUserScreenState();
}

class _EditUserScreenState extends State<EditUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  
  late final TextEditingController _usernameController;
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _oldPasswordController;
  late final TextEditingController _newPasswordController;
  late final TextEditingController _confirmPasswordController;
  String? _selectedRole;
  bool _isLoading = false;

  final List<String> _roles = ['Admin', 'Manager', 'User'];

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.user['userName'] ?? widget.user['username'] ?? '');
    
    // Setup name controller - handle both firstName+lastName and name formats
    String name = '';
    if (widget.user['firstName'] != null || widget.user['lastName'] != null) {
      name = '${widget.user['firstName'] ?? ''} ${widget.user['lastName'] ?? ''}'.trim();
    } else {
      name = widget.user['name'] ?? '';
    }
    _nameController = TextEditingController(text: name);
    
    _phoneController = TextEditingController(text: widget.user['phoneNumber'] ?? widget.user['phone'] ?? '');
    _oldPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _selectedRole = widget.user['role'] ?? 'User';
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _updateUser() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    // Check if new password and confirm password match
    if (_newPasswordController.text.isNotEmpty && 
        _newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New password and confirm password do not match')),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get the name parts (first name and last name)
      final String fullName = _nameController.text.trim();
      String firstName = '';
      String lastName = '';
      
      if (fullName.contains(' ')) {
        // If name has space, split into first and last name
        final parts = fullName.split(' ');
        firstName = parts[0];
        lastName = parts.sublist(1).join(' ');
      } else {
        // If no space, just use as first name
        firstName = fullName;
      }
      
      // Prepare user data
      final userId = widget.user['id']?.toString() ?? '';
      if (userId.isEmpty) {
        throw Exception('Invalid user ID');
      }
      
      final Map<String, dynamic> userData = {
        'id': userId,
        'userName': _usernameController.text.trim(),
        'firstName': firstName,
        'lastName': lastName,
        'phoneNumber': _phoneController.text.trim(),
        'role': _selectedRole,
      };
      
      // Add password fields if a new password was entered
      if (_newPasswordController.text.isNotEmpty) {
        userData['oldPassword'] = _oldPasswordController.text;
        userData['newPassword'] = _newPasswordController.text;
      }
      
      // Call the API to update the user
      await _apiService.put('api/Employees/$userId', userData);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User updated successfully')),
        );
        Navigator.pop(context, true); // Return true to indicate successful update
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update user: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1976D2),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit User',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: const Color(0xFF1976D2),
                            child: Text(
                              _getInitials(_nameController.text),
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.camera_alt,
                                  color: Color(0xFF1976D2),
                                  size: 20,
                                ),
                                onPressed: () {
                                  // TODO: Implement profile picture upload
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Profile picture upload coming soon')),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Username
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        border: OutlineInputBorder(),
                      ),
                      readOnly: true, // Username cannot be edited
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a username';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Name
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Phone Number
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    
                    // Role
                    DropdownButtonFormField<String>(
                      value: _selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'Role',
                        border: OutlineInputBorder(),
                      ),
                      items: _roles.map((String role) {
                        return DropdownMenuItem(
                          value: role,
                          child: Text(role),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedRole = newValue;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a role';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    
                    // Password Change Section
                    const Text(
                      'Change Password',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Old Password
                    TextFormField(
                      controller: _oldPasswordController,
                      decoration: const InputDecoration(
                        labelText: 'Old Password',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (_newPasswordController.text.isNotEmpty && (value == null || value.isEmpty)) {
                          return 'Please enter your old password';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // New Password
                    TextFormField(
                      controller: _newPasswordController,
                      decoration: const InputDecoration(
                        labelText: 'New Password',
                        border: OutlineInputBorder(),
                        helperText: 'Leave blank to keep current password',
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 16),
                    
                    // Confirm Password
                    TextFormField(
                      controller: _confirmPasswordController,
                      decoration: const InputDecoration(
                        labelText: 'Confirm New Password',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (_newPasswordController.text.isNotEmpty && 
                            _newPasswordController.text != value) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),
                    
                    // Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('CANCEL'),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: _updateUser,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1976D2),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24, 
                              vertical: 12,
                            ),
                          ),
                          child: const Text('UPDATE'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  String _getInitials(String fullName) {
    if (fullName.isEmpty) return 'U';
    
    final parts = fullName.split(' ');
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.length == 1 && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    
    return 'U';
  }
} 