# Repo root shortcuts. Backend targets live in backend/Makefile.
.PHONY: dev-up dev-down migrate backend-%

dev-up:
	$(MAKE) -C backend dev-up

dev-down:
	$(MAKE) -C backend dev-down

migrate:
	$(MAKE) -C backend migrate

# backend-<target> runs `make <target>` in backend/, e.g. make backend-test
backend-%:
	$(MAKE) -C backend $*
