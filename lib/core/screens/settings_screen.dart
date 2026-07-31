import 'package:flutter/material.dart';
import '../app_settings_state.dart';
import '../settings_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Settings',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              _SectionCard(
                title: 'Appearance',
                child: ValueListenableBuilder<ThemeMode>(
                  valueListenable: AppSettingsState.themeMode,
                  builder: (context, mode, _) {
                    return SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Dark mode'),
                      subtitle: const Text('Applies across all apps'),
                      value: mode == ThemeMode.dark,
                      onChanged: (value) => SettingsService.setDarkMode(value),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Bottom navigation',
                child: ValueListenableBuilder<NavBarStyle>(
                  valueListenable: AppSettingsState.navBarStyle,
                  builder: (context, style, _) {
                    return Column(
                      children: [
                        RadioListTile<NavBarStyle>(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Standard'),
                          subtitle: const Text('Full-width bar with labels'),
                          value: NavBarStyle.standard,
                          groupValue: style,
                          onChanged: (value) =>
                              SettingsService.setNavBarStyle(value!),
                        ),
                        RadioListTile<NavBarStyle>(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Floating'),
                          subtitle: const Text('Compact rounded pill'),
                          value: NavBarStyle.floating,
                          groupValue: style,
                          onChanged: (value) =>
                              SettingsService.setNavBarStyle(value!),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
