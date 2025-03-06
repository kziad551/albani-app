import 'package:flutter/material.dart';
import '../screens/profile_screen.dart';

class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  const AppHeader({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFF1976D2),
      leading: IconButton(
        icon: const Icon(Icons.person_outline, color: Colors.white),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ProfileScreen()),
          );
        },
      ),
      title: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 120),
          child: Image.asset(
            'assets/images/albanilogo.png',
            height: 40,
            fit: BoxFit.contain,
          ),
        ),
      ),
      actions: [
        Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openEndDrawer(),
          ),
        ),
      ],
    );
  }
} 