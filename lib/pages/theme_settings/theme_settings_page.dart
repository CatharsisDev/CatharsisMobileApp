import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../provider/theme_provider.dart';
import 'package:google_fonts/google_fonts.dart';

// Helper: theme screenshot selector
Widget _buildThemeOption({
  required BuildContext context,
  required String title,
  required String imageAsset,
  required String value,
  required String groupValue,
  required ValueChanged<String?> onChanged,
}) {
  final isSelected = value == groupValue;
  final theme = Theme.of(context);
  final borderColor = theme.textTheme.bodyMedium?.color ?? Colors.black;
  return GestureDetector(
    onTap: () => onChanged(value),
    child: Column(
      children: [
        Flexible(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 0.5, // Adjust this ratio to fit your screen images
              child: Image.asset(
                imageAsset, 
                width: double.infinity, 
                fit: BoxFit.cover
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Runtime',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: theme.textTheme.bodyMedium?.color,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          alignment: Alignment.center,
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: 1.5),
            color: isSelected ? const Color.fromRGBO(42, 63, 44, 0.7) : Colors.transparent,
          ),
          child: isSelected
              ? Icon(Icons.check, size: 16, color: Colors.white)
              : null,
        ),
      ],
    ),
  );
}

class ThemeSettingsPage extends ConsumerStatefulWidget {
  @override
  ConsumerState<ThemeSettingsPage> createState() => _ThemeSettingsPageState();
}

class _ThemeSettingsPageState extends ConsumerState<ThemeSettingsPage> {
  final PageController _pageController = PageController(viewportFraction: 0.8);
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      final page = _pageController.page?.round() ?? 0;
      if (page != _currentPage) {
        setState(() {
          _currentPage = page;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);
    
    // Get theme-aware colors
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black;
    final customTheme = Theme.of(context).extension<CustomThemeExtension>();
    final theme = Theme.of(context);

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
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: Icon(Icons.arrow_back_ios, color: textColor),
                          iconSize: 22.0,
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      Text(
                        'Appearance',
                        style: TextStyle(
                          fontFamily: 'Runtime',
                          fontSize: 20.0,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                
                // Main content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      children: [
                        // PageView for theme options
                        Expanded(
                          child: PageView.builder(
                            controller: _pageController,
                            itemCount: 3,
                            onPageChanged: (i) => setState(() => _currentPage = i),
                            itemBuilder: (ctx, i) {
                              final opts = [
                                {'title':'Default','image':'assets/images/default_theme_image.png','value':'catharsis_signature'},
                                {'title':'Dark','image':'assets/images/dark_theme_image.png','value':'dark'},
                                {'title':'Light','image':'assets/images/light_theme_image.png','value':'light'},
                              ];
                              final o = opts[i];
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: _buildThemeOption(
                                  context: context,
                                  title: o['title']!,
                                  imageAsset: o['image']!,
                                  value: o['value']!,
                                  groupValue: themeState.themeName,
                                  onChanged: (_) => themeNotifier.setTheme(o['value']!),
                                ),
                              );
                            },
                          ),
                        ),
                        
                        // Page indicators
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(3, (i) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _currentPage == i
                                  ? (theme.textTheme.bodyMedium?.color ?? Colors.black)
                                  : (theme.textTheme.bodyMedium?.color ?? Colors.black).withOpacity(0.3),
                            ),
                          )),
                        ),
                        const SizedBox(height: 20),
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
  
  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}