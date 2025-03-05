import 'package:flutter/material.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        color: const Color(0xFF1976D2),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Color(0xFF1976D2),
              ),
              child: Center(
                child: Image.asset(
                  'assets/images/albanilogo.png',
                  height: 60,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            _buildDrawerItem(
              context: context,
              icon: Icons.dashboard,
              title: 'Dashboard',
              onTap: () {
                Navigator.pop(context);
                // Navigate to Dashboard
              },
            ),
            _buildDrawerItem(
              context: context,
              icon: Icons.people,
              title: 'Users',
              onTap: () {
                Navigator.pop(context);
                // Navigate to Users
              },
            ),
            _buildDrawerItem(
              context: context,
              icon: Icons.settings,
              title: 'Bucketconfigs',
              onTap: () {
                Navigator.pop(context);
                // Navigate to Bucketconfigs
              },
            ),
            _buildDrawerItem(
              context: context,
              icon: Icons.description,
              title: 'Logs',
              onTap: () {
                Navigator.pop(context);
                // Navigate to Logs
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
    );
  }
} 