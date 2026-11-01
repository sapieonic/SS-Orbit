# Repo root shortcuts. Backend targets live in backend/Makefile.
.PHONY: dev-up dev-down migrate backend-% tokens i18n mobile-check farmer-run

dev-up:
	$(MAKE) -C backend dev-up

dev-down:
	$(MAKE) -C backend dev-down

migrate:
	$(MAKE) -C backend migrate

# backend-<target> runs `make <target>` in backend/, e.g. make backend-test
backend-%:
	$(MAKE) -C backend $*

# Mobile generators and checks (need Flutter on PATH and `dart pub global activate melos 8.10.0`,
# the version in mobile/pubspec.lock). mobile-check is the local check (fine with uncommitted
# work); CI runs `melos run check:ci`, which also fails on stale or unformatted files.
tokens:
	cd mobile && melos run gen:tokens

i18n:
	cd mobile && melos run gen:l10n

mobile-check:
	cd mobile && melos run check

# Farmer app on the connected Android device or emulator, dev flavour, mock data. Android only
# for now: iOS flavour schemes need Xcode on a Mac.
farmer-run:
	cd mobile/apps/farmer && flutter run --flavor dev
