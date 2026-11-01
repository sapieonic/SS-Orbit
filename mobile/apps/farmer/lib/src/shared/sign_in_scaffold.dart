import 'package:flutter/material.dart';
import 'package:orbit_ui/orbit_ui.dart';

/// The layout every sign-in and sign-up screen shares: the [header] and
/// [content] scroll together, and the screen's main action ([bottom]) stays
/// pinned above the keyboard, so the one task on the screen is always in
/// reach.
///
/// The header scrolls (instead of staying fixed) because at 130% font scale
/// on a 360 x 640 phone a wrapped Telugu title can fill half the screen; the
/// content under it must still be reachable.
class SignInScaffold extends StatelessWidget {
  /// Creates the layout.
  const SignInScaffold({
    super.key,
    required this.header,
    required this.content,
    this.bottom,
  });

  /// Usually a `ScreenHeader` with the Listen button.
  final Widget header;

  /// The content, laid out in a padded column under the header.
  final List<Widget> content;

  /// The hero button and anything that belongs with it.
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                header,
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    OrbitSpace.s16,
                    OrbitSpace.s8,
                    OrbitSpace.s16,
                    OrbitSpace.s16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: content,
                  ),
                ),
              ],
            ),
          ),
          if (bottom case final bottom?)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  OrbitSpace.s16,
                  OrbitSpace.s8,
                  OrbitSpace.s16,
                  OrbitSpace.s16,
                ),
                child: bottom,
              ),
            ),
        ],
      ),
    );
  }
}
