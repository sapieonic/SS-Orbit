import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../routing/routes.dart';

/// Back from a screen: pops when there is a page under it, otherwise goes
/// to [fallback] (a screen opened from a link or with `go`, so back never
/// leaves the app by surprise).
void goBack(BuildContext context, {String fallback = AppRoutes.farmers}) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallback);
  }
}

/// Opens [location] over the current screen (`push`), unless it is already
/// the current page (a second tap on the sync pill or the Me avatar).
void openPage(BuildContext context, String location) {
  final router = GoRouter.of(context);
  if (router.state.uri.path == Uri.parse(location).path) return;
  router.push(location);
}
