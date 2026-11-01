import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../icons/orbit_icons.dart';
import '../tokens/orbit_tokens.g.dart';
import 'orbit_button.dart';

/// The last row of a paged list: asks for the next page as soon as it is
/// built (the list builds it when the user scrolls near the end), shows a
/// spinner while it loads, and the error with a Try again button when it
/// failed.
///
/// Give it a key that changes with the page cursor, so each new end of the
/// list asks again.
class LoadMoreFooter extends StatefulWidget {
  /// Creates the footer.
  const LoadMoreFooter({
    super.key,
    required this.loading,
    required this.onLoadMore,
    required this.loadingLabel,
    required this.retryLabel,
    this.errorText,
  });

  /// The next page is loading.
  final bool loading;

  /// Why the last request failed, already localised; null when it didn't.
  final String? errorText;

  /// Requests the next page.
  final VoidCallback onLoadMore;

  /// Screen-reader label for the spinner, e.g. "Loading".
  final String loadingLabel;

  /// Label of the retry button, e.g. "Try again".
  final String retryLabel;

  @override
  State<LoadMoreFooter> createState() => _LoadMoreFooterState();
}

class _LoadMoreFooterState extends State<LoadMoreFooter> {
  @override
  void initState() {
    super.initState();
    // Not during build: the request usually changes app state.
    if (widget.errorText == null && !widget.loading) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onLoadMore();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.errorText case final error?) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            error,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: OrbitSpace.s8),
          OrbitButton(
            label: widget.retryLabel,
            icon: OrbitIcons.refresh,
            variant: OrbitButtonVariant.secondary,
            size: OrbitButtonSize.medium,
            onPressed: widget.onLoadMore,
          ),
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.all(OrbitSpace.s16),
      child: Center(
        child: Semantics(
          label: widget.loadingLabel,
          child: const CircularProgressIndicator(),
        ),
      ),
    );
  }
}
