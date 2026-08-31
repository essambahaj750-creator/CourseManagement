import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/network/api_client.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/login_page.dart';
import 'features/auth/register_page.dart';
import 'features/catalog/course_details_page.dart';
import 'features/catalog/courses_page.dart';
import 'features/enrollments/enrollments_page.dart';
import 'features/home/home_page.dart';
import 'features/profile/admin_courses_page.dart';
import 'features/profile/admin_pages.dart';
import 'features/profile/profile_page.dart';
import 'widgets/app_shell.dart';
import 'widgets/splash_page.dart';

class CourseManagementApp extends StatefulWidget {
  const CourseManagementApp({required this.api, required this.auth, super.key});

  final ApiClient api;
  final AuthController auth;

  @override
  State<CourseManagementApp> createState() => _CourseManagementAppState();
}

class _CourseManagementAppState extends State<CourseManagementApp> {
  late final GoRouter _router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: widget.auth,
    redirect: (context, state) {
      final path = state.uri.path;
      const guestPaths = {'/login', '/register'};

      if (widget.auth.isRestoring) return path == '/splash' ? null : '/splash';
      if (!widget.auth.isAuthenticated && !guestPaths.contains(path)) {
        return '/login';
      }
      if (widget.auth.isAuthenticated &&
          (path == '/login' || path == '/register' || path == '/splash')) {
        return '/';
      }
      if (path.startsWith('/admin') && !widget.auth.isAdmin) return '/';
      if (path.startsWith('/manage') && !widget.auth.isInstructor) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashPage()),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (context, state) => const HomePage()),
          GoRoute(
            path: '/courses',
            builder: (context, state) => const CoursesPage(),
          ),
          GoRoute(
            path: '/courses/:id',
            builder: (context, state) => CourseDetailsPage(
              courseId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
            ),
          ),
          GoRoute(
            path: '/enrollments',
            builder: (context, state) => const EnrollmentsPage(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfilePage(),
          ),
          GoRoute(
            path: '/manage/courses',
            builder: (context, state) => const CourseManagementPage(),
          ),
          GoRoute(
            path: '/admin/users',
            builder: (context, state) => const AdminUsersPage(),
          ),
          GoRoute(
            path: '/admin/enrollments',
            builder: (context, state) => const AdminEnrollmentsPage(),
          ),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: widget.api),
        ChangeNotifierProvider.value(value: widget.auth),
      ],
      child: MaterialApp.router(
        title: 'منصة المعرفة',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        ),
        routerConfig: _router,
      ),
    );
  }
}
