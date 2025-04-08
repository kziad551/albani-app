import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/projects_screen.dart';
import 'screens/users_screen.dart';
import 'screens/logs_screen.dart';
import 'screens/add_project_screen.dart';
import 'screens/edit_project_screen.dart';
import 'screens/project_details_screen.dart';
import 'screens/project_buckets_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AlBani Project Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1976D2),
          primary: const Color(0xFF1976D2),
          background: Colors.white,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: Colors.white,
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.black87),
          bodyMedium: TextStyle(color: Colors.black87),
        ),
        useMaterial3: true,
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/projects': (context) => const ProjectsScreen(),
        '/users': (context) => const UsersScreen(),
        '/logs': (context) => const LogsScreen(),
        '/add_project': (context) => const AddProjectScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/project_details') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => ProjectDetailsScreen(
              projectId: args['projectId'],
              projectName: args['projectName'] ?? 'Project Details',
            ),
          );
        } else if (settings.name == '/edit_project') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => EditProjectScreen(
              projectId: args['projectId'],
              title: args['title'],
              description: args['description'],
              location: args['location'],
              status: args['status'],
            ),
          );
        } else if (settings.name == '/project_buckets') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => ProjectBucketsScreen(
              projectId: args['projectId'],
              projectName: args['projectName'],
            ),
          );
        }
        return null;
      },
    );
  }
}