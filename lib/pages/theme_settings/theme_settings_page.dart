import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../provider/theme_provider.dart';
import 'package:google_fonts/google_fonts.dart';

class ThemeSettingsPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFFFAF1E1),
                  const Color(0xFFFAF1E1).withOpacity(0.95),
                ],
              ),
            ),
          ),
          // Texture overlay at 40% opacity
          Opacity(
            opacity: 0.4,
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage("assets/images/background_texture.png"),
                  fit: BoxFit.cover,
                ),
              ),
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
                        icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
                        iconSize: 30.0,
                        onPressed: () => Navigator.pop(context), // Navigate back
                      ),
                      const SizedBox(width: 8.0),
                      Text(
                        'Theme Settings',
                        style: TextStyle(
                          fontFamily: 'Runtime',
                          fontSize: 22.0,
                          fontWeight: FontWeight.bold,
                          color: const Color.fromRGBO(32, 28, 17, 1),
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
                            color: const Color.fromRGBO(32, 28, 17, 1),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ListTile(
                          title: Text(
                            'Default Theme',
                            style: TextStyle(
                              fontFamily: 'Runtime',
                              color: const Color.fromRGBO(32, 28, 17, 1),
                              fontSize: 16.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          trailing: Radio<String>(
                            value: 'catharsis_signature',
                            groupValue: themeState.themeName,
                            activeColor: const Color.fromARGB(255, 227, 95, 66), // Tick color
                            onChanged: (value) => themeNotifier.setTheme('catharsis_signature'),
                          ),
                        ),
                        ListTile(
                          title: Text(
                            'Light Theme',
                            style: TextStyle(
                              fontFamily: 'Runtime',
                              color: const Color.fromRGBO(32, 28, 17, 1),
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
                              color: const Color.fromRGBO(32, 28, 17, 1),
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