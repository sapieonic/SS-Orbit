import 'package:flutter/material.dart';
import 'package:orbit_l10n/orbit_l10n.dart';
import 'package:orbit_ui/orbit_ui.dart';

import '../../../data/data.dart';
import '../farm_format.dart';

/// The profile block of My farm (F10): avatar, name (Telugu first), plan
/// badge, phone and village. The village is read-only: it changes through
/// the FA or HO.
class ProfileCard extends StatelessWidget {
  /// Creates the profile card.
  const ProfileCard({
    super.key,
    required this.home,
    required this.language,
    required this.onEditName,
    this.onPhotoFailed,
  });

  /// The home payload.
  final FarmerHome home;

  /// The app language.
  final Language language;

  /// Opens the change-name dialog.
  final VoidCallback onEditName;

  /// The photo did not load (its presigned URL may have expired).
  final VoidCallback? onPhotoFailed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final farmer = home.farmer;
    final name = farmer.displayName(language);
    final other = farmer.displayName(
      language == Language.te ? Language.en : Language.te,
    );
    final village = home.village;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(OrbitSpace.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // TODO(photo): tap the avatar to change the photo. Needs
                // image_picker (camera / gallery: farmer.farm.take_photo,
                // farmer.farm.from_gallery), then createPhotoUpload, a PUT to
                // the presigned URL and updateProfile(photoKey:), then
                // invalidate farmerHomeProvider (farmer.farm.photo_updated).
                FarmerAvatar(
                  photoUrl: home.photoUrl,
                  initials: initialsFor(farmer),
                  onLoadFailed: onPhotoFailed,
                ),
                const SizedBox(width: OrbitSpace.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BilingualText(
                        name,
                        secondary: other.isEmpty || other == name
                            ? null
                            : other,
                        primaryStyle: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: OrbitSpace.s4),
                      OrbitTag(
                        label: l10n.labelFarmerPlan(farmer.plan.wire),
                        tone: farmer.plan == Plan.premium
                            ? OrbitTagTone.primary
                            : OrbitTagTone.highlight,
                        icon: farmer.plan == Plan.premium
                            ? OrbitIcons.premium
                            : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: onEditName,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, OrbitSize.controlLg),
                ),
                icon: const Icon(OrbitIcons.edit, size: OrbitSize.iconMd),
                label: Text(l10n.farmerFarmChangeName),
              ),
            ),
            const SizedBox(height: OrbitSpace.s4),
            InfoRow(icon: OrbitIcons.phone, text: displayPhone(farmer.phone)),
            if (village != null) ...[
              const SizedBox(height: OrbitSpace.s8),
              InfoRow(
                icon: OrbitIcons.location,
                text: l10n.commonDotJoin(
                  first: pickText(
                    language,
                    te: village.nameTe,
                    en: village.name,
                  ),
                  second: pickText(
                    language,
                    te: village.mandalNameTe,
                    en: village.mandalName,
                  ),
                ),
                secondaryText: l10n.farmerFarmVillageChangeNote,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The farmer's round photo, or their initials when there is no photo or it
/// fails to load (presigned URLs expire; mock URLs never resolve).
class FarmerAvatar extends StatelessWidget {
  /// Creates an avatar.
  const FarmerAvatar({
    super.key,
    required this.photoUrl,
    required this.initials,
    this.onLoadFailed,
  });

  /// Presigned photo URL from Home, or null.
  final String? photoUrl;

  /// Shown without a photo.
  final String initials;

  /// Called after a frame in which the photo failed to load (the initials
  /// show meanwhile), e.g. to fetch a fresh presigned URL.
  final VoidCallback? onLoadFailed;

  /// `.invalid` never resolves (RFC 2606); the mock backend uses it.
  static bool _loadable(String url) {
    final host = Uri.tryParse(url)?.host ?? '';
    return host.isNotEmpty && !host.endsWith('.invalid');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fallback = Center(
      child: Text(
        initials,
        style: theme.textTheme.titleMedium!.copyWith(
          color: scheme.onPrimaryContainer,
        ),
      ),
    );
    final url = photoUrl;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: OrbitSize.avatarLg,
        child: ClipOval(
          child: ColoredBox(
            color: scheme.primaryContainer,
            child: url == null || !_loadable(url)
                ? fallback
                : Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) {
                      if (onLoadFailed case final failed?) {
                        WidgetsBinding.instance.addPostFrameCallback(
                          (_) => failed(),
                        );
                      }
                      return fallback;
                    },
                  ),
          ),
        ),
      ),
    );
  }
}
