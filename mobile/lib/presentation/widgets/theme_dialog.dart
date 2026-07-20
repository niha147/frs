import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_frs/presentation/providers/theme_provider.dart';

void showThemeSelectorDialog(BuildContext context, WidgetRef ref) {
  showDialog(
    context: context,
    builder: (ctx) => const ThemeSelectorDialog(),
  );
}

class ThemeSelectorDialog extends ConsumerWidget {
  const ThemeSelectorDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Icon(
            Icons.palette_rounded,
            color: Theme.of(context).colorScheme.primary,
            size: 28,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              "Theme & Accessibility",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "APPEARANCE MODE",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    avatar: const Icon(Icons.dark_mode_rounded, size: 18),
                    label: const Text("Dark"),
                    selected: themeState.mode == ThemeMode.dark,
                    onSelected: (_) => ref.read(themeProvider.notifier).setMode(ThemeMode.dark),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    avatar: const Icon(Icons.light_mode_rounded, size: 18),
                    label: const Text("Light"),
                    selected: themeState.mode == ThemeMode.light,
                    onSelected: (_) => ref.read(themeProvider.notifier).setMode(ThemeMode.light),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              "ACCENT COLOR PALETTE",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            Column(
              children: AppThemeColor.values.map((preset) {
                final isSelected = themeState.color == preset;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () {
                      ref.read(themeProvider.notifier).setColor(preset);
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? preset.primary.withOpacity(0.12)
                            : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? preset.primary : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [preset.primary, preset.secondary],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: preset.primary.withOpacity(0.4),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              preset.label,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle_rounded,
                              color: preset.primary,
                              size: 22,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text("Done"),
        ),
      ],
    );
  }
}
