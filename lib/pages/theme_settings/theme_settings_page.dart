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
                colors: ref.watch(themeProvider).themeName == 'dark' 
    ? [Theme.of(context).appBarTheme.backgroundColor!, Theme.of(context).scaffoldBackgroundColor]
    : ref.watch(themeProvider).themeName == 'light'
    ? [Color.fromARGB(235, 201, 197, 197), Color.fromARGB(255, 255, 255, 255)]
    : [Color.fromARGB(235, 208, 164, 180), Color.fromRGBO(140, 198, 255, 1)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
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
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        iconSize: 30.0,
                        onPressed: () => Navigator.pop(context), // Navigate back
                      ),
                      const SizedBox(width: 8.0),
                      Text(
                        'Theme Settings',
                        style: GoogleFonts.raleway(
                          fontSize: 22.0,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              offset: Offset(2.0, 2.0),
                              blurRadius: 2.0,
                              color: Colors.black.withOpacity(0.5),
                            ),
                          ],
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
                          style: GoogleFonts.raleway(
                            fontSize: 20.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                offset: Offset(2.0, 2.0),
                                blurRadius: 2.0,
                                color: Colors.black.withOpacity(0.5),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        ListTile(
                          title: Text(
                            'Catharsis Signature Theme',
                            style: GoogleFonts.raleway(
                              color: Colors.white,
                              fontSize: 16.0,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  offset: Offset(2.0, 2.0),
                                  blurRadius: 2.0,
                                  color: Colors.black.withOpacity(0.5),
                                ),
                              ],
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
                            style: GoogleFonts.raleway(
                              color: Colors.white,
                              fontSize: 16.0,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  offset: Offset(2.0, 2.0),
                                  blurRadius: 2.0,
                                  color: Colors.black.withOpacity(0.5),
                                ),
                              ],
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
                            style: GoogleFonts.raleway(
                              color: Colors.white,
                              fontSize: 16.0,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  offset: Offset(2.0, 2.0),
                                  blurRadius: 2.0,
                                  color: Colors.black.withOpacity(0.5),
                                ),
                              ],
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