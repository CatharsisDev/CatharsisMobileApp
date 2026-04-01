import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../questions_model.dart';
import '../provider/reflection_provider.dart';
import '../provider/theme_provider.dart';

/// Shows a bottom sheet where the user can write or edit a reflection note
/// for [question].  Call [showReflectionSheet] from any page.
Future<void> showReflectionSheet(
  BuildContext context,
  WidgetRef ref,
  Question question,
) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => UncontrolledProviderScope(
      container: ProviderScope.containerOf(context),
      child: _ReflectionSheet(question: question),
    ),
  );
}

class _ReflectionSheet extends ConsumerStatefulWidget {
  final Question question;
  const _ReflectionSheet({required this.question});

  @override
  ConsumerState<_ReflectionSheet> createState() => _ReflectionSheetState();
}

class _ReflectionSheetState extends ConsumerState<_ReflectionSheet> {
  late final TextEditingController _ctrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing =
        ref.read(reflectionProvider.notifier).noteFor(widget.question) ?? '';
    _ctrl = TextEditingController(text: existing);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await ref
        .read(reflectionProvider.notifier)
        .saveNote(widget.question, _ctrl.text);
    setState(() => _saving = false);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customTheme = theme.extension<CustomThemeExtension>();
    final fontColor =
        customTheme?.fontColor ?? theme.textTheme.bodyMedium?.color ?? Colors.black87;
    final bgColor = customTheme?.preferenceModalBackgroundColor ??
        theme.scaffoldBackgroundColor;
    final borderColor =
        customTheme?.preferenceBorderColor ?? theme.dividerColor;
    final buttonColor =
        customTheme?.preferenceButtonColor ?? theme.primaryColor;
    final isDark = theme.brightness == Brightness.dark;

    // Sheet grows with keyboard
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: borderColor.withOpacity(0.4), width: 1.5),
        ),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: fontColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Icon(Icons.edit_note_rounded, color: Colors.orange, size: 22),
              const SizedBox(width: 8),
              Text(
                'Your Reflection',
                style: TextStyle(
                  fontFamily: 'Runtime',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: fontColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Question text
          Text(
            widget.question.text,
            style: TextStyle(
              fontFamily: 'Runtime',
              fontSize: 13,
              color: fontColor.withOpacity(0.55),
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),

          // Text field
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.06)
                  : Colors.black.withOpacity(0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor.withOpacity(0.3)),
            ),
            child: TextField(
              controller: _ctrl,
              maxLines: 7,
              minLines: 5,
              autofocus: true,
              style: TextStyle(
                fontFamily: 'Runtime',
                fontSize: 15,
                color: fontColor,
                height: 1.5,
              ),
              decoration: InputDecoration(
                hintText: 'Write your thoughts here…',
                hintStyle: TextStyle(
                  fontFamily: 'Runtime',
                  color: fontColor.withOpacity(0.35),
                ),
                contentPadding: const EdgeInsets.all(14),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Action row
          Row(
            children: [
              // Delete button (only shown when there's an existing note)
              if ((ref.watch(reflectionProvider.notifier)
                      .noteFor(widget.question) ??
                  '').isNotEmpty)
                TextButton.icon(
                  onPressed: _saving
                      ? null
                      : () async {
                          _ctrl.clear();
                          await ref
                              .read(reflectionProvider.notifier)
                              .saveNote(widget.question, '');
                          if (mounted) Navigator.of(context).pop();
                        },
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.redAccent, size: 18),
                  label: const Text(
                    'Delete',
                    style: TextStyle(
                      fontFamily: 'Runtime',
                      color: Colors.redAccent,
                      fontSize: 14,
                    ),
                  ),
                ),
              const Spacer(),

              // Cancel
              TextButton(
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    fontFamily: 'Runtime',
                    fontSize: 15,
                    color: fontColor.withOpacity(0.5),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Save
              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  elevation: 0,
                ),
                child: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        'Save',
                        style: TextStyle(
                          fontFamily: 'Runtime',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: customTheme?.buttonFontColor ?? Colors.white,
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
