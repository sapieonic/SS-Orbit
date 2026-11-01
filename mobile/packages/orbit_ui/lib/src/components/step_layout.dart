import 'package:flutter/material.dart';

import '../tokens/orbit_tokens.g.dart';
import 'screen_header.dart';

/// The frame of one step in a short flow (one input per screen): a
/// [ScreenHeader] with back and Listen, a progress bar, the step's content
/// scrolling in the middle, and the step's main button pinned at the bottom
/// above the keyboard.
///
/// [onBack] goes to the previous step, or leaves the flow on the first one;
/// wrap the screen in a `PopScope` so the system back gesture does the same.
class StepLayout extends StatelessWidget {
  /// Creates a step frame.
  const StepLayout({
    super.key,
    required this.title,
    required this.step,
    required this.totalSteps,
    required this.stepLabel,
    required this.onBack,
    required this.child,
    this.subtitle,
    this.listen,
    this.action,
  }) : assert(step > 0 && step <= totalSteps, 'step must be in 1..totalSteps');

  /// Flow title, e.g. "New plot".
  final String title;

  /// 1-based step number.
  final int step;

  /// Steps in the flow.
  final int totalSteps;

  /// "Step 2 of 3", already localised: read out for the progress bar, and
  /// the header's sub-line unless [subtitle] is given.
  final String stepLabel;

  /// Header sub-line in place of [stepLabel], e.g. "Plot 1 · Step 2 of 3".
  final String? subtitle;

  /// Back arrow in the header.
  final VoidCallback onBack;

  /// The header's Listen button.
  final Widget? listen;

  /// The step's question and input.
  final Widget child;

  /// The step's main button; null when the content has its own actions.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          ScreenHeader(
            title: title,
            subtitle: subtitle ?? stepLabel,
            onBack: onBack,
            listen: listen,
          ),
          LinearProgressIndicator(
            value: step / totalSteps,
            semanticsLabel: stepLabel,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(OrbitSpace.s16),
              child: child,
            ),
          ),
          if (action case final action?)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  OrbitSpace.s16,
                  OrbitSpace.s8,
                  OrbitSpace.s16,
                  OrbitSpace.s16,
                ),
                child: action,
              ),
            ),
        ],
      ),
    );
  }
}

/// The question at the top of a step, styled as a title and announced as a
/// header, with an optional helper line under it.
class StepQuestion extends StatelessWidget {
  /// Creates a step question.
  const StepQuestion(this.text, {super.key, this.helper});

  /// The question, e.g. "Which crop?".
  final String text;

  /// Optional helper line.
  final String? helper;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: OrbitSpace.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(text, style: theme.textTheme.titleLarge),
          ),
          if (helper case final helper?) ...[
            const SizedBox(height: OrbitSpace.s4),
            Text(
              helper,
              style: theme.textTheme.bodyMedium!.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
