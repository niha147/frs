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
    final themeState = ref.watch(themeProvider);

    return MaterialApp.router(
      title: 'SmartAttend AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.buildTheme(Brightness.light, themeState.color),
      darkTheme: AppTheme.buildTheme(Brightness.dark, themeState.color),
      themeMode: themeState.mode,
      routerConfig: router,
      builder: (context, child) {
        final activeTheme = (themeState.mode == ThemeMode.light)
            ? AppTheme.buildTheme(Brightness.light, themeState.color)
            : AppTheme.buildTheme(Brightness.dark, themeState.color);

        final animatedChild = AnimatedTheme(
          data: activeTheme,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOutCubic,
          child: child!,
        );

        final isWide = MediaQuery.of(context).size.width > 600;
        if (!isWide) return animatedChild;
        
        return Material(
          type: MaterialType.transparency,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOutCubic,
            color: activeTheme.scaffoldBackgroundColor,
            child: Center(
              child: Card(
                elevation: 12,
                margin: const EdgeInsets.symmetric(vertical: 24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                  width: 450,
                  child: animatedChild,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
