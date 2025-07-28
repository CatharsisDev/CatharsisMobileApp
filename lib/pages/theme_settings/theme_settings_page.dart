import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../provider/theme_provider.dart';
import 'package:google_fonts/google_fonts.dart';

class ThemeSettingsPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);
    final isDark = themeState.themeName == 'dark';
    
    // Get theme-aware colors
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black;
    final customTheme = Theme.of(context).extension<CustomThemeExtension>();

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          // Use theme-aware background
          Container(
            decoration: BoxDecoration(
              color: backgroundColor,
              image: (customTheme?.showBackgroundTexture ?? false) && 
                     (customTheme?.backgroundImagePath != null)
                  ? DecorationImage(
                      image: AssetImage(customTheme!.backgroundImagePath!),
                      fit: BoxFit.cover,
                      opacity: 0.4,
                    )
                  : null,
            ),
          ),
          
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top bar with back button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios, color: textColor),
                        iconSize: 30.0,
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8.0),
                      Text(
                        'Theme Settings',
                        style: TextStyle(
                          fontFamily: 'Runtime',
                          fontSize: 22.0,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Theme',
                          style: TextStyle(
                            fontFamily: 'Runtime',
                            fontSize: 20.0,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ListTile(
                          title: Text(
                            'Default Theme',
                            style: TextStyle(
                              fontFamily: 'Runtime',
                              color: textColor,
                              fontSize: 16.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          trailing: Radio<String>(
                            value: 'catharsis_signature',
                            groupValue: themeState.themeName,
                            activeColor: const Color.fromARGB(255, 227, 95, 66),
                            onChanged: (value) => themeNotifier.setTheme('catharsis_signature'),
                          ),
                        ),
                        ListTile(
                          title: Text(
                            'Light Theme',
                            style: TextStyle(
                              fontFamily: 'Runtime',
                              color: textColor,
                              fontSize: 16.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          trailing: Radio<String>(
                            value: 'light',
                            groupValue: themeState.themeName,
                            activeColor: const Color.fromARGB(255, 227, 95, 66),
                            onChanged: (value) => themeNotifier.setTheme('light'),
                          ),
                        ),
                        ListTile(
                          title: Text(
                            'Dark Theme',
                            style: TextStyle(
                              fontFamily: 'Runtime',
                              color: textColor,
                              fontSize: 16.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          trailing: Radio<String>(
                            value: 'dark',
                            groupValue: themeState.themeName,
                            activeColor: const Color.fromARGB(255, 227, 95, 66),
                            onChanged: (value) => themeNotifier.setTheme('dark'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}