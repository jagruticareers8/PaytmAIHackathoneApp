import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/sathi_card.dart';
import '../providers/claim_controller.dart';
import 'sathi_assistant_card.dart';
import 'technology_page.dart';

/// Main user journey: add a document once, then ask Sathi in natural language.
class HomePage extends StatelessWidget {
  const HomePage({
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
    final failedCount = documents
        .where((document) => document.readFailed)
        .length;
    final allReady = documents.isNotEmpty && readyCount == documents.length;

    final heading = documents.isEmpty
        ? 'Let’s understand your claim'
        : allReady
        ? 'Your documents are ready'
        : failedCount > 0
        ? 'One document needs a clearer copy'
        : 'Sathi is reading your documents';
    final description = documents.isEmpty
        ? 'Add your insurance letter, hospital bill or report. Sathi will read it automatically.'
        : allReady
        ? 'Ask about your approved amount, claim decision, required documents or deadline.'
        : failedCount > 0
        ? 'Try adding a clearer photo or an unlocked PDF. You do not need to copy or paste anything.'
        : 'You can ask your question as soon as your documents are ready.';
    final buttonLabel = documents.isEmpty
        ? 'Add a document'
        : failedCount > 0
        ? 'Try another document'
        : 'Add another document';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: AppColors.mint,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.support_agent_rounded,
                  color: AppColors.teal,
                  size: 27,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sathi',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.navy,
                      ),
                    ),
                    Text(
                      'Your claim companion',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Privacy and settings',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TechnologyPage()),
                ),
                icon: const Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.teal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            'Namaste 👋',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 6),
          Text(
            'Understand your health-insurance claim.',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 9),
          Text(
            'Upload your document once. Sathi reads it and helps explain what it means in simple language.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 14),
          SathiCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.folder_open_outlined,
                      color: AppColors.teal,
                      size: 23,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        heading,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (allReady)
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.green,
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 13),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onAddDocuments,
                    icon: const Icon(Icons.add_rounded),
                    label: Text(buttonLabel),
                  ),
                ),
                if (documents.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: () => onNavigate(2),
                    child: const Text('View my documents'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.mint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  color: AppColors.teal,
                  size: 18,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your documents stay on this phone. Sathi does not check live insurer status.',
                    style: TextStyle(
                      color: AppColors.tealDark,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SathiAssistantCard(
            onNavigate: onNavigate,
            claimContext: {
              'attachedDocumentNames': documents
                  .map((document) => document.fileName ?? document.title)
                  .toList(),
              'documentTexts': documents
                  .where(
                    (document) =>
                (document.extractedText ?? '').trim().isNotEmpty,
              )
                  .map(
                    (document) => {
                  'title': document.title,
                  'text': document.extractedText,
                },
              )
                  .toList(),
            },
          ),
        ],
      ),
    );
  }
}
