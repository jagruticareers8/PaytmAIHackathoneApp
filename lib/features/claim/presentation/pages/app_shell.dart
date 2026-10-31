import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import 'appeal_page.dart';
import 'claim_page.dart';
import 'documents_page.dart';
import 'home_page.dart';
import 'tracker_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  int _documentPickRequest = 0;

  void _navigateTo(int index) => setState(() => _index = index);

  /// Opens the native picker immediately from Home or Claim, without asking
  /// the user to navigate to Documents and tap a second button.
  void _requestAddDocuments() {
    setState(() {
      _index = 2;
      _documentPickRequest++;
    });
  }

  void _returnHomeAfterDocuments() => setState(() => _index = 0);

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(onNavigate: _navigateTo, onAddDocuments: _requestAddDocuments),
      ClaimPage(onNavigate: _navigateTo, onAddDocuments: _requestAddDocuments),
      DocumentsPage(
        autoPickRequest: _documentPickRequest,
        onDocumentsReady: _returnHomeAfterDocuments,
      ),
      const TrackerPage(),
      const AppealPage(),
    ];

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: _index, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _navigateTo,
        backgroundColor: Colors.white,
        indicatorColor: AppColors.mint,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.health_and_safety_outlined),
            selectedIcon: Icon(Icons.health_and_safety),
            label: 'Claim',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_open_outlined),
            selectedIcon: Icon(Icons.folder_open),
            label: 'Documents',
          ),
          NavigationDestination(
            icon: Icon(Icons.timeline_outlined),
            selectedIcon: Icon(Icons.timeline),
            label: 'Track',
          ),
          NavigationDestination(
            icon: Icon(Icons.edit_document),
            selectedIcon: Icon(Icons.edit_document),
            label: 'Draft',
          ),
        ],
      ),
    );
  }
}
