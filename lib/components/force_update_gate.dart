import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/force_update_service.dart';

/// Wraps the whole app (see MaterialApp.builder in main.dart). Shows the app
/// normally, but replaces it with a blocking "update required" screen when
/// [ForceUpdateService] says this build is too old.
///
/// Checks on launch and again whenever the app returns to the foreground
/// (at most every 15 minutes), so raising the minimum in Firestore also
/// reaches users who keep the app open in the background.
class ForceUpdateGate extends StatefulWidget {
  final Widget child;
  const ForceUpdateGate({super.key, required this.child});

  @override
  State<ForceUpdateGate> createState() => _ForceUpdateGateState();
}

class _ForceUpdateGateState extends State<ForceUpdateGate>
    with WidgetsBindingObserver {
  static const Duration _recheckInterval = Duration(minutes: 15);

  UpdateRequirement? _requirement;
  DateTime? _lastCheck;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // Always re-check while blocked (the user may have just updated);
    // otherwise throttle to avoid a Firestore read on every resume.
    final due = _lastCheck == null ||
        DateTime.now().difference(_lastCheck!) > _recheckInterval;
    if (_requirement != null || due) _check();
  }

  Future<void> _check() async {
    _lastCheck = DateTime.now();
    final result = await ForceUpdateService.check();
    if (!mounted) return;
    if (result?.storeUrl != _requirement?.storeUrl ||
        result?.message != _requirement?.message) {
      setState(() => _requirement = result);
    }
  }

  Future<void> _openStore() async {
    final uri = Uri.parse(_requirement!.storeUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final requirement = _requirement;
    if (requirement == null) return widget.child;

    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyMedium?.color ?? Colors.black87;

    // Not a route, so the Android back button can't dismiss it; PopScope
    // stops back from closing the app's routes behind it.
    return PopScope(
      canPop: false,
      child: Material(
        color: theme.scaffoldBackgroundColor,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/catharsis_word_only.png',
                  height: 36,
                  color: textColor,
                ),
                const SizedBox(height: 40),
                Text(
                  'Update required',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Runtime',
                    fontSize: 26,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  requirement.message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: textColor.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _openStore,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: textColor,
                      foregroundColor: theme.scaffoldBackgroundColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Update now',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
