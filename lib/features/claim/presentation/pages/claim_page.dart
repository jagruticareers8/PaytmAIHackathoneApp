import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/sathi_card.dart';
import '../providers/claim_controller.dart';

/// Plain-language claim overview. Document reading happens automatically when
/// the user adds a file; there is no separate analysis step.
class ClaimPage extends StatelessWidget {
  const ClaimPage({
    super.key,
    required this.onNavigate,
    required this.onAddDocuments,
  });

  final ValueChanged<int> onNavigate;
  final VoidCallback onAddDocuments;

  @override
  Widget build(BuildContext context) {
    final documents = context
        .watch<ClaimCubit>()
        .state
        .documents
        .where((document) => document.uploaded)
        .toList();
    final readyCount = documents
        .where((document) => (document.extractedText ?? '').trim().isNotEmpty)
        .length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MY CLAIM',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.teal,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Your claim documents',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 7),
          const Text(
            'Sathi reads the documents you add and helps explain what they say. It is not connected to your insurer’s live system.',
            style: TextStyle(color: AppColors.muted, height: 1.45),
          ),
          const SizedBox(height: 18),
          SathiCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.mint,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.folder_open_outlined,
                        color: AppColors.teal,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            documents.isEmpty
                                ? 'No documents added yet'
                                : '${documents.length} document(s) added',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: AppColors.navy,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            documents.isEmpty
                                ? 'Add your insurance letter or hospital bill.'
                                : '$readyCount ready to use',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onAddDocuments,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add a document'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SathiCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.chat_bubble_outline, color: AppColors.teal),
                    SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Have a question about your claim?',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Ask Sathi in Hindi, English or Hinglish. It will look at your saved documents first.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => onNavigate(0),
                    icon: const Icon(Icons.forum_outlined),
                    label: const Text('Ask Sathi'),
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
