import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_frs/presentation/providers/auth_provider.dart';
import 'package:smart_frs/presentation/providers/theme_provider.dart';

// Import all screens
import 'package:smart_frs/presentation/screens/auth/login_screen.dart';
import 'package:smart_frs/presentation/screens/admin/admin_dashboard.dart';
import 'package:smart_frs/presentation/screens/faculty/faculty_dashboard.dart';
import 'package:smart_frs/presentation/screens/faculty/class_detail_screen.dart';
import 'package:smart_frs/presentation/screens/analytics/analytics_screen.dart';
import 'package:smart_frs/presentation/screens/reports/reports_screen.dart';
import 'package:smart_frs/presentation/screens/settings/settings_screen.dart';
import 'package:smart_frs/presentation/screens/registration/registration_screen.dart';
import 'package:smart_frs/presentation/screens/attendance/attendance_camera_screen.dart';
import 'package:smart_frs/presentation/screens/student/student_dashboard.dart';
import 'package:smart_frs/presentation/screens/student/self_attendance_scan.dart';

CustomTransitionPage<void> _buildThemePageTransition({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
  required AppThemeColor themeColor,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 450),
    reverseTransitionDuration: const Duration(milliseconds: 350),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      switch (themeColor) {
        case AppThemeColor.emerald:
          // Bouncy spring slide from bottom
          final offsetAnimation = Tween<Offset>(
            begin: const Offset(0, 0.12),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutBack));
          return SlideTransition(position: offsetAnimation, child: FadeTransition(opacity: animation, child: child));

        case AppThemeColor.purple:
          // Cosmic Zoom Fade
          final scaleAnimation = Tween<double>(begin: 0.92, end: 1.0)
              .animate(CurvedAnimation(parent: animation, curve: Curves.easeInOutCubic));
          return ScaleTransition(scale: scaleAnimation, child: FadeTransition(opacity: animation, child: child));

        case AppThemeColor.rose:
          // Radiant Slide Right
          final offsetAnimation = Tween<Offset>(
            begin: const Offset(0.08, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.decelerate));
          return SlideTransition(position: offsetAnimation, child: FadeTransition(opacity: animation, child: child));

        case AppThemeColor.ocean:
          // Fluid Cascade Slide Up
          final offsetAnimation = Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutQuart));
          return SlideTransition(position: offsetAnimation, child: FadeTransition(opacity: animation, child: child));

        case AppThemeColor.indigo:
        default:
          // Smooth Fade & Subtle Scale
          final scaleAnimation = Tween<double>(begin: 0.96, end: 1.0)
              .animate(CurvedAnimation(parent: animation, curve: Curves.fastOutSlowIn));
          return ScaleTransition(scale: scaleAnimation, child: FadeTransition(opacity: animation, child: child));
      }
    },
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);
  final themeState = ref.watch(themeProvider);

  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => _buildThemePageTransition(
          context: context,
          state: state,
          child: const LoginScreen(),
          themeColor: themeState.color,
        ),
      ),
      GoRoute(
        path: '/admin',
        pageBuilder: (context, state) => _buildThemePageTransition(
          context: context,
          state: state,
          child: const AdminDashboard(),
          themeColor: themeState.color,
        ),
      ),
      GoRoute(
        path: '/faculty',
        pageBuilder: (context, state) => _buildThemePageTransition(
          context: context,
          state: state,
          child: const FacultyDashboard(),
          themeColor: themeState.color,
        ),
      ),
      GoRoute(
        path: '/student',
        pageBuilder: (context, state) => _buildThemePageTransition(
          context: context,
          state: state,
          child: const StudentDashboard(),
          themeColor: themeState.color,
        ),
      ),
      GoRoute(
        path: '/self-scan',
        pageBuilder: (context, state) {
          final classId = int.parse(state.uri.queryParameters['classId']!);
          return _buildThemePageTransition(
            context: context,
            state: state,
            child: SelfAttendanceScanScreen(classId: classId),
            themeColor: themeState.color,
          );
        },
      ),
      GoRoute(
        path: '/class/:id',
        pageBuilder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return _buildThemePageTransition(
            context: context,
            state: state,
            child: ClassDetailScreen(classId: id),
            themeColor: themeState.color,
          );
        },
      ),
      GoRoute(
        path: '/analytics',
        pageBuilder: (context, state) => _buildThemePageTransition(
          context: context,
          state: state,
          child: const AnalyticsScreen(),
          themeColor: themeState.color,
        ),
      ),
      GoRoute(
        path: '/reports',
        pageBuilder: (context, state) => _buildThemePageTransition(
          context: context,
          state: state,
          child: const ReportsScreen(),
          themeColor: themeState.color,
        ),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) => _buildThemePageTransition(
          context: context,
          state: state,
          child: const SettingsScreen(),
          themeColor: themeState.color,
        ),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) {
          final studentId = state.uri.queryParameters['studentId'];
          return _buildThemePageTransition(
            context: context,
            state: state,
            child: RegistrationScreen(studentId: studentId),
            themeColor: themeState.color,
          );
        },
      ),
      GoRoute(
        path: '/attendance-camera',
        pageBuilder: (context, state) {
          final classId = int.parse(state.uri.queryParameters['classId']!);
          final mode = state.uri.queryParameters['mode'] ?? 'scan';
          return _buildThemePageTransition(
            context: context,
            state: state,
            child: AttendanceCameraScreen(classId: classId, mode: mode),
            themeColor: themeState.color,
          );
        },
      ),
    ],
    redirect: (context, state) {
      final loggingIn = state.matchedLocation == '/login';
      final status = authState.status;

      // Do not redirect while loading auth status
      if (status == AuthStatus.initial || status == AuthStatus.loading) {
        return null;
      }

      // If not authenticated, force redirect to Login
      if (status == AuthStatus.unauthenticated || status == AuthStatus.error) {
        return loggingIn ? null : '/login';
      }

      // If authenticated, prevent access to login, redirect to respective dashboard
      if (status == AuthStatus.authenticated) {
        if (loggingIn) {
          final user = authState.user;
          if (user?.role == 'admin') {
            return '/admin';
          } else if (user?.role == 'student') {
            return '/student';
          } else {
            return '/faculty';
          }
        }
      }

      return null;
    },
  );
});
