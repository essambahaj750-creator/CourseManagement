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
import 'features/catalog/courses_v5_page.dart';
import 'features/enrollments/enrollments_page.dart';
import 'features/home/home_v3_page.dart';
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
      const guestOnlyPaths = {'/login', '/register'};
      final publicCatalog = path == '/courses' || path.startsWith('/courses/');
      final publicPath = path == '/' || publicCatalog || guestOnlyPaths.contains(path);
      final requestedReturn = state.uri.queryParameters['return'];
      final safeReturn = requestedReturn != null &&
              requestedReturn.startsWith('/') &&
              !requestedReturn.startsWith('//') &&
              !requestedReturn.startsWith('/login') &&
              !requestedReturn.startsWith('/register')
          ? requestedReturn
          : null;

      if (widget.auth.isRestoring) return path == '/splash' ? null : '/splash';
      if (!widget.auth.isAuthenticated && !publicPath) {
        return Uri(
          path: '/login',
          queryParameters: {'return': state.uri.toString()},
        ).toString();
      }
      if (widget.auth.isAuthenticated && guestOnlyPaths.contains(path)) {
        return safeReturn ?? '/';
      }
      if (widget.auth.isAuthenticated && path == '/splash') return '/';
      if (!widget.auth.isAuthenticated && path == '/splash') return '/';
      if (path.startsWith('/admin') && !widget.auth.isAdmin) return '/';
      if (path.startsWith('/manage') && !widget.auth.isInstructor) return '/';
      return null;
    },
    errorBuilder: (context, state) => _RouteErrorPage(message: state.error?.toString()),
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashPage()),
      GoRoute(
        path: '/login',
        builder: (context, state) =>
            LoginPage(returnPath: state.uri.queryParameters['return']),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) =>
            RegisterPage(returnPath: state.uri.queryParameters['return']),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (context, state) => const HomeV3Page()),
          GoRoute(path: '/courses', builder: (context, state) => const CoursesV5Page()),
          GoRoute(
            path: '/courses/:id',
            builder: (context, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '');
              if (id == null || id <= 0) return const _RouteErrorPage(message: 'معرّف الكورس غير صالح.');
              return CourseDetailsPage(courseId: id);
            },
          ),
          GoRoute(path: '/enrollments', builder: (context, state) => const EnrollmentsPage()),
          GoRoute(path: '/profile', builder: (context, state) => const ProfilePage()),
          GoRoute(path: '/manage/courses', builder: (context, state) => const CourseManagementPage()),
          GoRoute(path: '/admin/users', builder: (context, state) => const AdminUsersPage()),
          GoRoute(path: '/admin/enrollments', builder: (context, state) => const AdminEnrollmentsPage()),
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

class _RouteErrorPage extends StatelessWidget {
  const _RouteErrorPage({this.message});
  final String? message;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.route_rounded, color: AppTheme.blue, size: 56),
                    const SizedBox(height: 16),
                    const Text('الصفحة غير متاحة', style: TextStyle(color: AppTheme.ink, fontSize: 22, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Text(message ?? 'تعذر فتح هذا الرابط.', textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.muted, height: 1.7)),
                    const SizedBox(height: 20),
                    FilledButton.icon(onPressed: () => context.go('/'), icon: const Icon(Icons.home_rounded), label: const Text('العودة للرئيسية')),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}