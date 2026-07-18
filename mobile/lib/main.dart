import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_frs/core/router/app_router.dart';
import 'package:smart_frs/core/theme/app_theme.dart';
import 'package:smart_frs/presentation/providers/theme_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeProvider);

    return MaterialApp.router(
      title: 'SmartAttend AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        final isWide = MediaQuery.of(context).size.width > 600;
        if (!isWide) return child!;
        
        return Material(
          type: MaterialType.transparency,
          child: Container(
            color: const Color(0xFF0F1E36),
            child: Center(
              child: Card(
                elevation: 12,
                margin: const EdgeInsets.symmetric(vertical: 24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                  width: 450,
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
