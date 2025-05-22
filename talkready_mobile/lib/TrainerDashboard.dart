import 'package:flutter/material.dart';

class TrainerDashboard extends StatelessWidget {
  const TrainerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trainer Dashboard'),
      ),
      body: const Center(
        child: Text(
          'Welcome, Trainer!',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}