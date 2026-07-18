import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_frs/presentation/providers/auth_provider.dart';

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

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminDashboard(),
      ),
      GoRoute(
        path: '/faculty',
        builder: (context, state) => const FacultyDashboard(),
      ),
      GoRoute(
        path: '/student',
        builder: (context, state) => const StudentDashboard(),
      ),
      GoRoute(
        path: '/self-scan',
        builder: (context, state) {
          final classId = int.parse(state.uri.queryParameters['classId']!);
          return SelfAttendanceScanScreen(classId: classId);
        },
      ),
      GoRoute(
        path: '/class/:id',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return ClassDetailScreen(classId: id);
        },
      ),
      GoRoute(
        path: '/analytics',
        builder: (context, state) => const AnalyticsScreen(),
      ),
      GoRoute(
        path: '/reports',
        builder: (context, state) => const ReportsScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) {
          final studentId = state.uri.queryParameters['studentId'];
          return RegistrationScreen(studentId: studentId);
        },
      ),
      GoRoute(
        path: '/attendance-camera',
        builder: (context, state) {
          final classId = int.parse(state.uri.queryParameters['classId']!);
          final mode = state.uri.queryParameters['mode'] ?? 'scan';
          return AttendanceCameraScreen(classId: classId, mode: mode);
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
