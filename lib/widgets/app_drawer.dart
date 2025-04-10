import 'package:flutter/material.dart';
import '../screens/projects_screen.dart';
import '../screens/users_screen.dart';
import '../screens/logs_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/buckets_screen.dart';
import '../services/auth_service.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  final AuthService _authService = AuthService();
  Map<String, dynamic>? _userData;
  String _userInitials = '';
  String _userName = '';
  String _userRole = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await _authService.getCurrentUser();
      
      if (userData != null && mounted) {
        // Debug: Print the entire user data to see what fields are available
        debugPrint('User data received in drawer: $userData');
        
        setState(() {
          _userData = userData;
          
          // Try different possible field names for name
          _userName = userData['name'] ?? 
                     userData['Name'] ?? 
                     userData['fullName'] ?? 
                     userData['displayName'] ?? 
                     userData['username'] ?? 
                     userData['userName'] ?? 
                     'User';
                     
          debugPrint('Using name: $_userName');
          
          // Try different possible field names for role
          _userRole = userData['role'] ?? 
                      userData['Role'] ?? 
                      userData['userRole'] ?? 
                      userData['UserRole'] ?? 
                      'User';
                      
          debugPrint('Using role: $_userRole');
          
          // Generate initials from name
          if (_userName.isNotEmpty) {
            final nameParts = _userName.split(' ');
            if (nameParts.length > 1) {
              _userInitials = '${nameParts[0][0]}${nameParts[1][0]}';
            } else if (nameParts.isNotEmpty) {
              _userInitials = nameParts[0][0];
            }
          }
          _userInitials = _userInitials.toUpperCase();
          debugPrint('Using initials: $_userInitials');
          
          _isLoading = false;
        });
      } else {
        debugPrint('No user data received in drawer');
        setState(() {
          _userName = 'User';
          _userRole = 'User';
          _userInitials = 'U';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user data in drawer: $e');
      if (mounted) {
        setState(() {
          _userName = 'User';
          _userRole = 'User';
          _userInitials = 'U';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if user is admin
    final bool isAdmin = _userRole.toLowerCase() == 'admin' || _userRole.toLowerCase() == 'superadmin';
    
    return Drawer(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  decoration: const BoxDecoration(
                    color: Color(0xFF1976D2),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _isLoading 
                      ? const SizedBox(
                          height: 70,
                          width: 70,
                          child: CircularProgressIndicator(
                            backgroundColor: Colors.white,
                            color: Colors.white54,
                          ),
                        )
                      : CircleAvatar(
                        backgroundColor: Colors.white,
                        radius: 35,
                        child: Text(
                          _userInitials,
                          style: const TextStyle(
                            color: Color(0xFF1976D2),
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _isLoading ? 'Loading...' : _userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isLoading ? '' : _userRole,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                // Dashboard is visible to all users
                ListTile(
                  leading: const Icon(Icons.dashboard, color: Color(0xFF1976D2)),
                  title: const Text('Dashboard'),
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProjectsScreen(),
                      ),
                    );
                  },
                ),
                // Only show Buckets to admins
                if (isAdmin)
                  ListTile(
                    leading: const Icon(Icons.folder, color: Color(0xFF1976D2)),
                    title: const Text('Buckets'),
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const BucketsScreen(),
                        ),
                      );
                    },
                  ),
                // Only show Users to admins
                if (isAdmin)
                  ListTile(
                    leading: const Icon(Icons.person, color: Color(0xFF1976D2)),
                    title: const Text('Users'),
                    onTap: () {
                      Navigator.pushNamed(context, '/users');
                    },
                  ),
                // Only show Logs to admins
                if (isAdmin)
                  ListTile(
                    leading: const Icon(Icons.history, color: Color(0xFF1976D2)),
                    title: const Text('Logs'),
                    onTap: () {
                      Navigator.pushNamed(context, '/logs');
                    },
                  ),
                // Profile is visible to all users
                ListTile(
                  leading: const Icon(Icons.person_outline, color: Color(0xFF1976D2)),
                  title: const Text('Profile'),
                  onTap: () {
                    // Close the drawer first
                    Navigator.pop(context);
                    // Then navigate to profile screen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProfileScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Logout',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () async {
                // Log out user
                await _authService.logout();
                
                // Navigate to login screen
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/login',
                    (Route<dynamic> route) => false,
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
} 