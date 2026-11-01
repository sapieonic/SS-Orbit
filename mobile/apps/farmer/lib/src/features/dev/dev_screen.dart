import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/data.dart';
import '../../routing/routes.dart';
import '../../shared/farmer_data.dart';

/// Dev-only tools: switch the mock scenario to demo empty, offline and error
/// states, and reset mock data. English only on purpose; never shown in
/// staging or prod (the mock backend doesn't exist there).
class DevScreen extends ConsumerWidget {
  const DevScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scenario = ref.watch(mockScenarioProvider);
    final env = ref.watch(orbitEnvProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Developer tools')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          ListTile(
            title: const Text('Environment'),
            subtitle: Text('${env.flavor.name} · ${env.dataSource.name}'),
          ),
          if (scenario == null)
            const ListTile(
              title: Text('Mock scenarios are off: the app uses the API.'),
            )
          else ...[
            const _Header('Mock scenario'),
            RadioGroup<MockScenario>(
              groupValue: scenario,
              onChanged: (value) {
                if (value == null) return;
                ref.read(mockScenarioProvider.notifier).select(value);
                // Refetch the farmer's data under the new scenario. The
                // repositories and the session stay as they are, so this
                // screen (and the back stack under it) is kept.
                ref.read(farmerDataGenerationProvider.notifier).bump();
              },
              child: Column(
                children: [
                  for (final s in MockScenario.values)
                    RadioListTile<MockScenario>(
                      value: s,
                      title: Text(s.label),
                      subtitle: Text(s.description),
                    ),
                ],
              ),
            ),
            const _Header('Data'),
            ListTile(
              leading: const Icon(Icons.restart_alt),
              title: const Text('Reset mock data'),
              subtitle: const Text('Drops sign-ups, call-backs and consents.'),
              onTap: () {
                ref.read(mockScenarioProvider.notifier).resetData();
                ref.read(farmerDataGenerationProvider.notifier).bump();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Mock data reset')),
                );
              },
            ),
          ],
          const _Header('Session'),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            onTap: () async {
              await ref.read(sessionProvider.notifier).signOut();
              if (context.mounted) context.go(Routes.login);
            },
          ),
          const ListTile(
            title: Text('Test logins'),
            subtitle: Text(
              'Ravi 9000000101 · Venkatesh 9000000102 · any other number '
              'signs up. OTP 123456.',
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );
}
