import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/sathi_card.dart';
import '../providers/claim_controller.dart';

class TrackerPage extends StatelessWidget {
  const TrackerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final claim = context.watch<ClaimCubit>().state;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CLAIM TRACKER',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.teal,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Know what happened\nand what comes next.',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'A visible timeline helps you keep the insurer’s steps, documents and follow-up in one place.',
            style: TextStyle(color: AppColors.muted, height: 1.45),
          ),
          const SizedBox(height: 18),
          SathiCard(
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.amberBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.hourglass_bottom_rounded,
                    color: AppColors.amber,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Current claim status',
                        style: TextStyle(color: AppColors.muted, fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        claim.reconsiderationMarkedSubmitted
                            ? 'You marked reconsideration as submitted'
                            : 'No live claim status available',
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'This log shows only actions recorded in this app, not insurer updates.',
                        style: TextStyle(color: AppColors.muted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionHeading('Activity timeline'),
          const SizedBox(height: 10),
          if (claim.timeline.isEmpty)
            SathiCard(
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, color: AppColors.teal),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No activity has been recorded yet. Attach a document or mark your own next step to create a local activity entry. Live insurer tracking will require an authenticated insurer/TPA integration.',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ...List.generate(claim.timeline.length, (index) {
            final event = claim.timeline[index];
            final isLast = index == claim.timeline.length - 1;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 32,
                  child: Column(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: event.done
                              ? AppColors.greenBg
                              : (event.isCurrent
                              ? AppColors.mint
                              : Colors.white),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: event.done
                                ? AppColors.green
                                : (event.isCurrent
                                ? AppColors.teal
                                : AppColors.border),
                            width: 1.4,
                          ),
                        ),
                        child: Icon(
                          event.done
                              ? Icons.check_rounded
                              : (event.isCurrent
                              ? Icons.more_horiz
                              : Icons.circle_outlined),
                          size: 15,
                          color: event.done
                              ? AppColors.green
                              : (event.isCurrent
                              ? AppColors.teal
                              : AppColors.muted),
                        ),
                      ),
                      if (!isLast)
                        Container(
                          width: 2,
                          height: 66,
                          color: event.done
                              ? const Color(0xFFB9E4CF)
                              : AppColors.border,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 18, top: 2),
                    child: SathiCard(
                      padding: const EdgeInsets.all(13),
                      color: event.isCurrent
                          ? const Color(0xFFF0FBF9)
                          : Colors.white,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  event.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.navy,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Text(
                                event.dateLabel,
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            event.description,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 11,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          }),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.amberBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline_rounded, color: AppColors.amber),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'After submitting through the insurer’s official channel, keep the acknowledgement/reference number and copies of all files. This app does not fetch live claim status without an insurer/TPA integration.',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.45,
                      color: AppColors.ink,
                    ),
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
