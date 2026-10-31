import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/sathi_card.dart';
import '../../domain/models/claim_models.dart';
import '../providers/claim_controller.dart';

class AppealPage extends StatefulWidget {
  const AppealPage({super.key});

  @override
  State<AppealPage> createState() => _AppealPageState();
}

class _AppealPageState extends State<AppealPage> {
  late final TextEditingController _draftController;
  bool _showingTranslation = false;

  @override
  void initState() {
    super.initState();
    final claim = context.read<ClaimCubit>().state;
    _draftController = TextEditingController(
      text: claim.appealDraft.isNotEmpty
          ? claim.appealDraft
          : _makeDraft(claim),
    );
  }

  @override
  void dispose() {
    _draftController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final claim = context.watch<ClaimCubit>().state;
    final controller = context.read<ClaimCubit>();
    if (!_showingTranslation &&
        claim.appealDraft.isNotEmpty &&
        _draftController.text.isEmpty)
      _draftController.text = claim.appealDraft;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RECONSIDERATION DRAFT',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.teal,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Your words. Your evidence.',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Start with a clear, polite request. Review and edit every sentence before using it.',
            style: TextStyle(color: AppColors.muted, height: 1.45),
          ),
          const SizedBox(height: 18),
          SathiCard(
            color: AppColors.mint,
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.edit_note_rounded, color: AppColors.teal, size: 25),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'This is a draft, not an automatic appeal. Sathi does not send it to the insurer. Add only documents you actually have and verify the policy clause, facts and submission deadline.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.tealDark,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SathiCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Editable message',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: AppColors.navy,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        _draftController.text = _makeDraft(claim);
                        controller.saveDraft(_draftController.text);
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Refresh'),
                    ),
                  ],
                ),
                if (claim.appealDraftTranslation.isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _showingTranslation = !_showingTranslation;
                          _draftController.text = _showingTranslation
                              ? claim.appealDraftTranslation
                              : claim.appealDraft;
                        });
                      },
                      icon: const Icon(Icons.translate_rounded, size: 17),
                      label: Text(
                        _showingTranslation
                            ? 'Show original language'
                            : 'Show English translation',
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                TextField(
                  controller: _draftController,
                  onChanged: (value) {
                    if (_showingTranslation) {
                      controller.saveDraftTranslation(value);
                    } else {
                      controller.saveDraft(value);
                    }
                  },
                  minLines: 16,
                  maxLines: 24,
                  keyboardType: TextInputType.multiline,
                  decoration: const InputDecoration(
                    hintText: 'Review and edit your reconsideration request…',
                    alignLabelWithHint: true,
                  ),
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.55,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: _draftController.text),
                    );
                    if (context.mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Draft copied. Paste it into the insurer’s official channel after reviewing.',
                          ),
                        ),
                      );
                  },
                  icon: const Icon(Icons.copy_all_outlined),
                  label: const Text('Copy draft'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          SathiCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Have you submitted it?',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'After you submit it yourself via the insurer’s official website, email or grievance channel, you can record that step in the demo tracker.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 12),
                if (claim.reconsiderationMarkedSubmitted)
                  const Row(
                    children: [
                      Icon(Icons.check_circle, color: AppColors.green),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Marked as submitted by you. This is not a confirmation from the insurer.',
                          style: TextStyle(
                            color: AppColors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  OutlinedButton.icon(
                    onPressed: () =>
                        _confirmMarkedSubmitted(context, controller),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('I have submitted this draft'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Please verify all facts, dates, amounts and attachments. This template is general informational support and is not legal advice or a guarantee of recovery.',
            style: TextStyle(color: AppColors.muted, fontSize: 10, height: 1.5),
          ),
        ],
      ),
    );
  }

  String _makeDraft(ClaimState claim) {
    final uploaded = claim.documents
        .where((d) => d.uploaded)
        .map(
          (d) => '• ${d.title}${d.fileName == null ? '' : ' (${d.fileName})'}',
        )
        .toList();
    final attachments = uploaded.isEmpty
        ? '• [List only the documents you are actually attaching]'
        : uploaded.join('\n');
    return '''Subject: Request for review of partial settlement — Claim ${claim.claimId}

Dear Claims Review Team,

I am requesting a review of the partial settlement recorded for claim ${claim.claimId}, submitted on ${claim.claimDate} for treatment at ${claim.hospitalName}.

The decision letter states: “${claim.insurerReason}”

Please share an itemised explanation of the amount approved and the remaining amount of ₹${claim.unpaidAmount}, including any applicable policy clause, benefit limit, exclusion or deduction. Please also confirm which additional documents or information are needed for review.

Documents currently marked as attached in my checklist:
$attachments

Please confirm receipt of this request, provide a reference number, and let me know the next steps and applicable timelines. I understand that the review will be subject to the policy terms and your formal assessment.

Regards,
[Policyholder name]
[Registered mobile number / email]
[Policy or claim reference, if required]
''';
  }

  Future<void> _confirmMarkedSubmitted(
    BuildContext context,
    ClaimCubit controller,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Record submission?'),
        content: const Text(
          'This only updates the local demo timeline. Sathi will not send the draft or contact the insurer. Have you already submitted it through the insurer’s official channel?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Not yet'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Yes, I submitted it'),
          ),
        ],
      ),
    );
    if (confirmed == true) controller.markReconsiderationSubmitted();
  }
}
