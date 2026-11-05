import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit_l10n/orbit_l10n.dart';

import '../../data/data.dart';
import '../../device/device.dart';
import '../../local/local.dart';
import '../../shared/helpline.dart';

/// Dev menu: mock scenarios and data resets (dev builds only).
///
/// Switch the mock scenario, move the mock GPS, act as HO (edit Padma S's
/// Plot 2, send a note, a farmer asking for a call-back) to demo sync and
/// conflicts, force a sync and see what the engine holds, and reset
/// everything. English only on purpose, like the Farmer app's dev menu: the
/// router only lets dev builds on mock data reach it.
class DevScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const DevScreen({super.key});

  @override
  ConsumerState<DevScreen> createState() => _DevScreenState();
}

class _DevScreenState extends ConsumerState<DevScreen> {
  void _say(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _sync() async {
    final result = await ref.read(syncEngineProvider).syncNow(force: true);
    if (mounted) _say('$result');
  }

  /// Runs an HO action on the mock server, then syncs so the phone sees it.
  Future<void> _asHo(
    String done,
    void Function(MockBackend backend) act,
  ) async {
    final backend = ref.read(mockBackendProvider);
    if (backend == null) return;
    try {
      act(backend);
    } on Object catch (e) {
      _say('Failed: $e');
      return;
    }
    _say(done);
    await ref.read(syncEngineProvider).syncNow();
  }

  Future<void> _reset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset mock data?'),
        content: const Text(
          'Reloads the mock server seed, deletes everything on this phone '
          '(unsynced records too) and signs out.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    ref.read(mockScenarioProvider.notifier).resetData();
    await ref.read(sessionProvider.notifier).logout(discardUnsynced: true);
    // logout wipes through the engine's guard; make sure even without one.
    await ref.read(localStoreProvider).wipe();
    if (mounted) _say('Mock data reset; signed out');
  }

  @override
  Widget build(BuildContext context) {
    final env = ref.watch(orbitEnvProvider);
    final scenario = ref.watch(mockScenarioProvider);
    final sync = ref.watch(syncStateProvider);
    final territory = ref.watch(territoryProvider).value;
    final connectivity = ref.watch(connectivityProvider);
    final location = ref.watch(locationServiceProvider);
    final meta = territory?.meta;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.faShellTitleDev)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ListTile(
            title: const Text('Environment'),
            subtitle: Text('${env.flavor.name} · ${env.dataSource.name}'),
          ),
          if (scenario == null)
            const ListTile(
              title: Text('Mock tools are off: the app uses the API.'),
            )
          else ...[
            const _Header('Mock scenario'),
            RadioGroup<MockScenario>(
              groupValue: scenario,
              onChanged: (value) {
                if (value != null) {
                  ref.read(mockScenarioProvider.notifier).select(value);
                }
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
            if (connectivity case final MockConnectivityService net)
              SwitchListTile(
                title: const Text('On Wi-Fi'),
                subtitle: const Text(
                  'Off: mobile data (photos wait when "Wi-Fi only" is on)',
                ),
                value: connectivity.isOnWifi,
                onChanged: connectivity.isOnline
                    ? (v) => setState(() => net.setWifi(v))
                    : null,
              ),
            if (location case final MockLocationService gps) ...[
              const _Header('Mock GPS'),
              ListTile(
                title: Text(
                  'Accuracy ±${gps.accuracyM.round()} m'
                  '${gps.walking ? ' · walking the boundary' : ''}',
                ),
                subtitle: Text(
                  '${gps.position.lat.toStringAsFixed(5)}, '
                  '${gps.position.lng.toStringAsFixed(5)}',
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () => setState(
                        () =>
                            gps.setAccuracy(MockLocationService.goodAccuracyM),
                      ),
                      child: const Text('Good accuracy'),
                    ),
                    OutlinedButton(
                      onPressed: () => setState(
                        () =>
                            gps.setAccuracy(MockLocationService.poorAccuracyM),
                      ),
                      child: const Text('Poor accuracy (±28 m)'),
                    ),
                    if (gps.walking)
                      OutlinedButton(
                        onPressed: () => setState(gps.stopWalk),
                        child: const Text('Stop walk'),
                      )
                    else
                      OutlinedButton(
                        onPressed: () {
                          final walk = gps.walkBoundary();
                          setState(() {});
                          unawaited(
                            walk.then((_) {
                              if (mounted) setState(() {});
                            }),
                          );
                        },
                        child: const Text('Start a boundary walk'),
                      ),
                  ],
                ),
              ),
            ],
            const _Header('Act as HO'),
            ListTile(
              leading: const Icon(Icons.edit_location_alt_outlined),
              title: const Text('HO edits Padma S Plot 2'),
              subtitle: const Text(
                'Plot 2 becomes 2 ac 0 gunta on the server. A queued edit of '
                'it then comes back as a conflict.',
              ),
              onTap: () => _asHo(
                'HO changed Padma S Plot 2',
                (b) => b.hoEditPlot(MockBackend.padmaPlot2Id, areaAcres: 2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.campaign_outlined),
              title: const Text('HO sends a note'),
              subtitle: const Text('A new note in Alerts after the sync.'),
              onTap: () => _asHo(
                'HO sent a note',
                (b) => b.addAlert(
                  title: 'Soil samples',
                  titleTe: 'మట్టి నమూనాలు',
                  body: 'Collect soil samples from Padma S by Thursday.',
                  bodyTe:
                      'గురువారం లోపు పద్మ ఎస్ నుండి మట్టి నమూనాలు తీసుకోండి.',
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.phone_callback_outlined),
              title: const Text('Farmer asks for call-back'),
              subtitle: const Text('Venkat R asks to be called (Alerts).'),
              onTap: () => _asHo(
                'Venkat R asked for a call-back',
                (b) => b.addCallback(MockBackend.venkatId),
              ),
            ),
          ],
          const _Header('Sync'),
          ListTile(
            leading: const Icon(Icons.sync),
            title: const Text('Force sync'),
            subtitle: Text(
              sync.running
                  ? 'Running…'
                  : '${sync.queuedCount} waiting · ${sync.records.length} '
                        'outbox rows · ${sync.conflicts.length} conflicts · '
                        '${sync.rejected.length} refused · '
                        '${sync.photosWaiting} photos',
            ),
            onTap: sync.running ? null : _sync,
          ),
          ListTile(
            title: const Text('Snapshot'),
            subtitle: Text(
              'ETag ${meta?.etag ?? '-'} · territory v'
              '${meta?.territoryVersion ?? '-'} · masters v'
              '${meta?.mastersVersion ?? '-'}\n'
              'Last pull ${meta?.lastPullAt?.toIso8601String() ?? 'never'}',
            ),
          ),
          if (scenario != null) ...[
            const _Header('Data'),
            ListTile(
              leading: const Icon(Icons.restart_alt),
              title: const Text('Reset mock data'),
              subtitle: const Text(
                'Reloads the server seed, wipes this phone and signs out.',
              ),
              onTap: _reset,
            ),
          ],
          // A const condition, so staging and prod builds drop the mock
          // logins along with the mock backend.
          if (mockBuildAllowed) ...[
            const _Header('Mock logins'),
            const ListTile(
              title: Text('FA-KDP-014 / orbit2026'),
              subtitle: Text('Suresh Kumar, Kondapur and Gachibowli'),
            ),
            const ListTile(
              title: Text('FA-KDP-099 / temp1234'),
              subtitle: Text('Temporary password: must change it'),
            ),
            const ListTile(
              title: Text('FA-KDP-077 / temp5678'),
              subtitle: Text('Temporary password expired'),
            ),
            const ListTile(
              title: Text('FA-CVL-002 / chevella2026'),
              subtitle: Text('Lakshmi P, Chevella (another FA)'),
            ),
            ListTile(
              title: Text(
                'OTP 123456 · HO ${formatHelpline(hoHelplineNumber)}',
              ),
              subtitle: const Text(
                'Lookup: 91234 56780 Raju P (merges) · 90000 00201 other FA · '
                '90000 00301 outside area · 90000 00302 deactivated',
              ),
            ),
          ],
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
