import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/grade.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';

class GradesDialog extends StatefulWidget {
  const GradesDialog({super.key});

  @override
  State<GradesDialog> createState() => _GradesDialogState();
}

class _GradesDialogState extends State<GradesDialog> {
  Future<void> _addComponent(BuildContext context, int subjectId) async {
    final nameCtrl = TextEditingController(text: 'Final Exam');
    final weightCtrl = TextEditingController(text: '30');
    final scoreCtrl = TextEditingController();
    final targetCtrl = TextEditingController(text: '90');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Grading Component'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Component (e.g. Midterms, Quizzes)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: weightCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Weight Percentage (%)',
                hintText: 'e.g. 30',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: scoreCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Score Percentage (%) (optional if not yet taken)',
                hintText: 'e.g. 88',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: targetCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Target Course Grade (%)',
                hintText: 'e.g. 90',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add Component'),
          ),
        ],
      ),
    );

    if (ok == true && mounted) {
      final weight = double.tryParse(weightCtrl.text) ?? 0;
      final score = double.tryParse(scoreCtrl.text);
      final target = double.tryParse(targetCtrl.text) ?? 85;

      await context.read<AppState>().addGrade(
            subjectId: subjectId,
            componentName: nameCtrl.text.trim(),
            weightPct: weight,
            scorePct: score,
            targetPct: target,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final summary = app.gradeSummary;
    final subjects = app.subjects;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: PortalColors.primary.withAlpha(24),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.calculate_outlined,
                      color: PortalColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Academic GPA & Target Grade Solver',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Track weighted scores & solve what you need on upcoming finals.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? PortalColors.mutedDark
                                : PortalColors.mutedLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // GPA Overview Banner
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: AppGradients.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PROJECTED CUMULATIVE GPA',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          summary?.cumulativeGpa != null
                              ? '${summary!.cumulativeGpa!.toStringAsFixed(2)} / 4.00'
                              : 'Calculating...',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(40),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white30),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.military_tech,
                            color: Colors.amber,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            summary?.academicStanding ?? 'In Progress',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Subject Breakdown List
              Expanded(
                child: subjects.isEmpty
                    ? const Center(
                        child: Text('Add subjects first to track grades.'),
                      )
                    : ListView.builder(
                        itemCount: subjects.length,
                        itemBuilder: (context, idx) {
                          final sub = subjects[idx];
                          final subSummary = summary?.subjects.firstWhere(
                            (s) => s.subjectId == sub.id,
                            orElse: () => SubjectGradeSummary(
                              subjectId: sub.id,
                              code: sub.code,
                              title: sub.title,
                              units: sub.units,
                              color: sub.color,
                              componentsCount: 0,
                              letterGrade: 'N/A',
                              targetPercentage: 85,
                              remainingWeight: 100,
                              components: [],
                            ),
                          );

                          return Card(
                            margin: const EdgeInsets.only(bottom: 14),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: hexToColor(sub.color),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${sub.code} · ${sub.title}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const Spacer(),
                                      if (subSummary?.currentPercentage != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: PortalColors.primary
                                                .withAlpha(24),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '${subSummary!.currentPercentage}% · ${subSummary.letterGrade}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              color: PortalColors.primary,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // Needed on remaining solver
                                  if (subSummary?.neededOnRemaining != null &&
                                      subSummary!.remainingWeight > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: (subSummary.neededOnRemaining! > 95
                                                ? Colors.orange
                                                : PortalColors.emerald)
                                            .withAlpha(20),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.track_changes,
                                            size: 16,
                                            color: subSummary.neededOnRemaining! > 95
                                                ? Colors.orange
                                                : PortalColors.emerald,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Target Solver: Need ~${subSummary.neededOnRemaining!.clamp(0, 100)}% on remaining ${subSummary.remainingWeight.round()}% of course work to hit ${subSummary.targetPercentage.round()}% target.',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: subSummary.neededOnRemaining! > 95
                                                    ? Colors.orange
                                                    : PortalColors.emerald,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  const SizedBox(height: 10),

                                  // Components chips
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      for (final c in subSummary?.components ??
                                          <SubjectGrade>[])
                                        Chip(
                                          avatar: Icon(
                                            c.scorePct != null
                                                ? Icons.check_circle
                                                : Icons.pending_outlined,
                                            size: 16,
                                            color: c.scorePct != null
                                                ? PortalColors.emerald
                                                : PortalColors.muted,
                                          ),
                                          label: Text(
                                            '${c.componentName} (${c.weightPct.round()}%): ${c.scorePct != null ? '${c.scorePct!.round()}%' : 'Pending'}',
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                        ),
                                      ActionChip(
                                        avatar: const Icon(
                                          Icons.add,
                                          size: 16,
                                          color: PortalColors.primary,
                                        ),
                                        label: const Text(
                                          'Add Item',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: PortalColors.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        onPressed: () =>
                                            _addComponent(context, sub.id),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
