import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:showcaseview/showcaseview.dart';

final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 2,
    errorMethodCount: 8,
    lineLength: 120,
    colors: true,
    printEmojis: true,
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  ),
);

class TutorialService {
  static Future<bool> shouldShowTutorial(Future<bool> hasSeenTutorialFuture) async {
    try {
      bool hasSeenTutorial = await hasSeenTutorialFuture;
      logger.i('Checked tutorial status: hasSeenTutorial=$hasSeenTutorial');
      return !hasSeenTutorial;
    } catch (e) {
      logger.e('Error checking tutorial status: $e');
      return true;
    }
  }

  static Future<bool?> showTutorialWithSkipOption({
    required BuildContext context,
    required List<GlobalKey> showcaseKeys,
    required String skipText,
    required VoidCallback onComplete,
    required String title,
    required String content,
    required String confirmText,
    bool showDontAskAgain = false,
  }) async {
    final theme = Theme.of(context);

    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        surfaceTintColor: Colors.white, // Prevent any tint overlay
        backgroundColor: Colors.white, // Force white background
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        title: Column(
          children: [
            Icon(
              Icons.tips_and_updates_outlined,
              size: 48,
              color: Colors.blue, // Explicit blue color for icon
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface, // Text color for contrast on white
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Text(
          content,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.8),
          ),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () {
              onComplete();
              Navigator.pop(context, true);
            },
            child: Text(
              skipText,
              style: theme.textTheme.labelLarge?.copyWith(
                color: Colors.blue.shade700.withOpacity(0.6), // Blue with opacity for secondary action
              ),
            ),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, false),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.blue.shade100, // Light blue button background
              foregroundColor: Colors.blue.shade900, // Dark blue text/icon
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              confirmText,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void startShowCase(BuildContext context, List<GlobalKey> showcaseKeys) {
    logger.i('Attempting to start showcase with context: $context, keys: $showcaseKeys');
    if (!context.mounted) {
      logger.w('Cannot start showcase: context is not mounted');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot start tutorial: context unavailable')),
      );
      return;
    }

    try {
      final showCaseWidget = ShowCaseWidget.of(context);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          logger.i('Starting showcase with keys: $showcaseKeys');
          showCaseWidget.startShowCase(showcaseKeys);
        } else {
          logger.w('Post-frame callback skipped: context is not mounted');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cannot start tutorial: context unavailable')),
          );
        }
      });
    } catch (e) {
      logger.e('Error starting showcase: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to start tutorial: $e')),
        );
      }
    }
  }

  static Widget buildShowcase({
    required BuildContext context,
    required GlobalKey key,
    required String title,
    required String description,
    required Widget child,
  }) {
    return Showcase(
      key: key,
      title: title,
      description: description,
      child: child,
    );
  }

  static void handleTutorialCompletion() {
    logger.i('Tutorial completed');
  }
}