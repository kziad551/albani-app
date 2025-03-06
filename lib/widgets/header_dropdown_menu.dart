import 'package:flutter/material.dart';
import '../screens/users_screen.dart';

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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(Icons.dashboard, color: Colors.white),
          title: const Text(
            'Dashboard',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          onTap: () {
            onDismiss();
            // Navigate to Dashboard
          },
        ),
        ListTile(
          leading: const Icon(Icons.people, color: Colors.white),
          title: const Text(
            'Users',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          onTap: () {
            onDismiss();
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const UsersScreen()),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.settings, color: Colors.white),
          title: const Text(
            'Bucketconfigs',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          onTap: () {
            onDismiss();
            // Navigate to Bucketconfigs
          },
        ),
        ListTile(
          leading: const Icon(Icons.description, color: Colors.white),
          title: const Text(
            'Logs',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          onTap: () {
            onDismiss();
            // Navigate to Logs
          },
        ),
      ],
    );
  }
} 