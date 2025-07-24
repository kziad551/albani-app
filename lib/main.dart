import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/login_screen.dart';
import 'screens/projects_screen.dart';
import 'screens/users_screen.dart';
import 'screens/logs_screen.dart';
import 'screens/add_project_screen.dart';
import 'screens/edit_project_screen.dart';
import 'screens/project_details_screen.dart';
import 'screens/project_buckets_screen.dart';
import 'services/auth_service.dart';
import 'utils/navigation_service.dart';
import 'splash_screen.dart';
import 'services/firebase_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  // Ensure plugins are initialized before the app starts
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  
  // Initialize Firebase Core - Platform specific approach
  try {
    debugPrint('🚀🚀🚀 [MAIN] Initializing Firebase Core...');
    
    // For iOS, Firebase is initialized natively in AppDelegate
    // For Android and other platforms, initialize here
    if (Platform.isIOS) {
      debugPrint('🚀 [MAIN] iOS detected - using native Firebase initialization');
    } else {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('🚀🚀🚀 [MAIN] Firebase Core initialized for non-iOS platform');
    }
    
    // Set background message handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    debugPrint('🚀 [MAIN] Background message handler set');
  } catch (e) {
    debugPrint('⚠️⚠️⚠️ [MAIN] Firebase initialization failed: $e');
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();
    
    return MaterialApp(
      title: 'AlBani',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.black),
          titleTextStyle: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: const SplashScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/projects': (context) => const ProjectsScreen(),
        '/dashboard': (context) => const ProjectsScreen(), // Alias for dashboard
        '/users': (context) => FutureBuilder<Map<String, dynamic>?>(
          future: authService.getCurrentUser(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            
            // Check if user is admin
            final userData = snapshot.data;
            final userRole = userData?['role']?.toString().toLowerCase() ?? '';
            final isAdmin = userRole == 'admin' || userRole == 'superadmin';
            
            if (isAdmin) {
              return const UsersScreen();
            } else {
              // Redirect non-admin users to dashboard
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.pushReplacementNamed(context, '/dashboard');
              });
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
          },
        ),
        '/logs': (context) => FutureBuilder<Map<String, dynamic>?>(
          future: authService.getCurrentUser(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            
            // Check if user is admin
            final userData = snapshot.data;
            final userRole = userData?['role']?.toString().toLowerCase() ?? '';
            final isAdmin = userRole == 'admin' || userRole == 'superadmin';
            
            if (isAdmin) {
              return const LogsScreen();
            } else {
              // Redirect non-admin users to dashboard
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.pushReplacementNamed(context, '/dashboard');
              });
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
          },
        ),
        '/add_project': (context) => FutureBuilder<Map<String, dynamic>?>(
          future: authService.getCurrentUser(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            
            // Check if user is admin
            final userData = snapshot.data;
            final userRole = userData?['role']?.toString().toLowerCase() ?? '';
            final isAdmin = userRole == 'admin' || userRole == 'superadmin';
            
            if (isAdmin) {
              return const AddProjectScreen();
            } else {
              // Redirect non-admin users to dashboard
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.pushReplacementNamed(context, '/dashboard');
              });
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
          },
        ),
      },
      onGenerateRoute: (settings) {
        // Handle protected routes here
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
            builder: (context) => FutureBuilder<Map<String, dynamic>?>(
              future: AuthService().getCurrentUser(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                
                // Check if user is admin
                final userData = snapshot.data;
                final userRole = userData?['role']?.toString().toLowerCase() ?? '';
                final isAdmin = userRole == 'admin' || userRole == 'superadmin';
                
                if (isAdmin) {
                  return EditProjectScreen(
                    projectId: args['projectId'],
                    title: args['title'],
                    description: args['description'],
                    location: args['location'],
                    status: args['status'],
                  );
                } else {
                  // Redirect non-admin users to dashboard
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    Navigator.pushReplacementNamed(context, '/dashboard');
                  });
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
              },
            ),
          );
        } else if (settings.name == '/project_buckets') {
          final args = settings.arguments as Map<String, dynamic>;
          // Check if user is admin before allowing access to buckets
          return MaterialPageRoute(
            builder: (context) => FutureBuilder<Map<String, dynamic>?>(
              future: AuthService().getCurrentUser(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                
                // Check if user is admin
                final userData = snapshot.data;
                final userRole = userData?['role']?.toString().toLowerCase() ?? '';
                final isAdmin = userRole == 'admin' || userRole == 'superadmin';
                
                if (isAdmin) {
                  return ProjectBucketsScreen(
                    projectId: args['projectId'],
                    projectName: args['projectName'],
                  );
                } else {
                  // Redirect non-admin users to dashboard
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    Navigator.pushReplacementNamed(context, '/dashboard');
                  });
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
              },
            ),
          );
        }
        return null;
      },
      navigatorObservers: [
        // Add a navigator observer to set the logout callback when the app starts
        _NavigationObserver(),
      ],
    );
  }
}

// Navigator observer to set up the NavigationService
class _NavigationObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _setupNavigationService();
  }
  
  void _setupNavigationService() {
    // Set the logout callback
    NavigationService().setLogoutCallback(() {
      // Use the navigator to push to the login screen
      navigator?.pushNamedAndRemoveUntil('/login', (route) => false);
    });
  }
}