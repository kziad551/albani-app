import 'package:flutter/material.dart';

class HeaderDropdownMenu extends StatelessWidget {
  final bool isVisible;
  final VoidCallback onDismiss;

  const HeaderDropdownMenu({
    super.key,
    required this.isVisible,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: isVisible ? 240 : 0,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1976D2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMenuItem(
                context,
                'Dashboard',
                Icons.dashboard,
                () {
                  onDismiss();
                  // Navigate to Dashboard
                },
              ),
              _buildMenuItem(
                context,
                'Users',
                Icons.people,
                () {
                  onDismiss();
                  // Navigate to Users
                },
              ),
              _buildMenuItem(
                context,
                'Bucketconfigs',
                Icons.settings,
                () {
                  onDismiss();
                  // Navigate to Bucketconfigs
                },
              ),
              _buildMenuItem(
                context,
                'Logs',
                Icons.description,
                () {
                  onDismiss();
                  // Navigate to Logs
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
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