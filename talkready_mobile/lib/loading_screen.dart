import 'package:flutter/material.dart';

// Create a reusable LoadingScreen widget
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.9),
        ),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF00568D)),
            strokeWidth: 4,
          ),
        ),
      ),
    );
  }
}

// Helper function to show the loading screen
void showLoadingScreen(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) => const LoadingScreen(), // Show LoadingScreen, not WelcomePage
  );
}

// Helper function to hide the loading screen
void hideLoadingScreen(BuildContext context) {
  Navigator.of(context).pop();
}