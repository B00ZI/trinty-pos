import 'package:flutter/material.dart';
import '../objectbox.dart';

class HistoryScreen extends StatelessWidget {
    final ObjectBox objectbox;
  const HistoryScreen({super.key, required this.objectbox});

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order History'),
      ),
      body: const Center(
        child: Text('History Screen'),
      ),
    );
  }
}
