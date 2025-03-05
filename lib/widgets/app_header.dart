import 'package:flutter/material.dart';
import 'header_dropdown_menu.dart';

class AppHeader extends StatefulWidget implements PreferredSizeWidget {
  const AppHeader({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  State<AppHeader> createState() => _AppHeaderState();
}

class _AppHeaderState extends State<AppHeader> {
  bool _showMenu = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AppBar(
            backgroundColor: const Color(0xFF1976D2),
            leading: IconButton(
              icon: const Icon(Icons.person_outline, color: Colors.white),
              onPressed: () {
                // Handle profile action
              },
            ),
            title: SizedBox(
              height: 40,
              child: Image.asset(
                'assets/images/albanilogo.png',
                fit: BoxFit.contain,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _showMenu = !_showMenu;
                  });
                },
              ),
            ],
            centerTitle: true,
          ),
          if (_showMenu)
            Positioned(
              top: kToolbarHeight,
              left: 0,
              right: 0,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _showMenu = false;
                  });
                },
                child: Container(
                  color: Colors.transparent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      HeaderDropdownMenu(
                        isVisible: _showMenu,
                        onDismiss: () {
                          setState(() {
                            _showMenu = false;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
} 