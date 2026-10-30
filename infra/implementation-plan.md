# Infra implementation plan

## Purpose

Terraform for Orbit Shifting on AWS in India: the Go api and worker, PostgreSQL 17 + PostGIS, Redis, S3, the web
bundles behind CloudFront, secrets, logs and alarms, for three environments (dev, staging, prod). This file is
enough to start building `infra/` without other context. Sized for the pilot: 5,000 farmers and 25 FAs.

## Read first

1. Build plan, sections "Stack", "Repository" and "Guarding production": https://claude.ai/artifact/M85KFgHynuZ4gWBqz87pSa
2. `backend/internal/platform/config/config.go` and `backend/.env.example`: every variable the backend reads.
3. `backend/README.md` ("Configuration") and `backend/implementation-plan.md` (the image, migrate with only
   `DATABASE_URL` and the worker health listener are built; Sentry is Phase 0 item 2, `orbit_app` item 4).
4. `backend/Dockerfile`, `backend/cmd/migrate/main.go`, `backend/cmd/worker/main.go`, `backend/internal/app/app.go`
   (`periodicJobs`).
5. `.github/workflows/backend.yml`: the existing CI, for style.

## Current state

`infra/envs/dev`, `infra/envs/staging`, `infra/envs/prod` and `infra/modules` exist and are empty. No AWS
account, no state bucket, no deploy workflow.

The backend side is ready for ECS: `backend/Dockerfile` (`make image IMAGE_TAG=<sha>`) builds one distroless,
non-root image with four binaries: `api` (default command, `:8080`), `worker` (`/healthz`, `/readyz` on
`WORKER_HEALTH_ADDR`, `:8081`), `migrate` (`migrate up|down|status`, needs only `DATABASE_URL`) and `seed`. The
image sets `ORBIT_ENV=prod`, `LOG_FORMAT=json` and exposes 8080 and 8081. The backend cannot run with
`ORBIT_ENV=prod` yet, because only the dev adapters exist (log SMS/push, local storage) and prod refuses them.
Infra can still be built and tested now with `ORBIT_ENV=dev` set on the tasks in the AWS dev environment.

## Decisions (fixed)

- Terraform, everything in one repo. Envs under `infra/envs/{dev,staging,prod}`, modules under `infra/modules/*`.
- AWS India region only (data residency). Managed services: ECS Fargate, RDS, ElastiCache, S3, CloudFront, KMS,
  Secrets Manager, CloudWatch. Sentry for crashes and errors.
- Two processes from one image: `api` (HTTP) and `worker` (River jobs and event subscribers). Migrations run as a
  one-off task with the same image (`migrate up`) before services roll.
- No AWS keys anywhere. GitHub Actions gets short-lived credentials through OIDC. Only the job running in the
  GitHub `production` environment can assume the prod role.
- Plan on every PR that touches `infra/`, posted as a PR comment. Apply only from `main`. Dev and staging apply
  automatically; prod waits for the `production` environment with two required reviewers.
- A deploy is a one-line PR in `infra/envs/<env>` that changes the image tag. Merging app code never changes prod.
- Secrets (JWT, TOTP key, SMS, FCM, later Razorpay and payout keys) live in Secrets Manager, referenced by name.
- Trimmed for launch (plan): no WAF, no OpenTelemetry/Grafana, no hash-chained audit. Each can be added later.

## Open decision: region (Phase 0)

The plan says "AWS Hyderabad (ap-south-2) or Mumbai (ap-south-1)". Not decided. Make the region a variable
(`var.aws_region`, set per env in `terraform.tfvars`); never hard-code it in modules.

| | Hyderabad `ap-south-2` | Mumbai `ap-south-1` |
|---|---|---|
| For | Closest to Telangana users (lower latency on 2G/3G) | Widest service coverage, oldest India region, often slightly cheaper |
| Against | Newer region; some services or instance types may be missing | A little further from users |

Before choosing ap-south-2, check in that region: ECS Fargate (including ARM64/Graviton), RDS for PostgreSQL 17
with the PostGIS extension version we need, ElastiCache (Valkey or Redis OSS) on `t4g` nodes, S3 Object Lock,
AWS Backup, Secrets Manager, KMS, and SES if email is ever needed. Whichever is chosen, the other India region is
the target for cross-region backup copies. CloudFront is global, but its ACM certificate must be in `us-east-1`
(use a provider alias for that one resource; it holds no data).

## Target layout

```
infra/
  bootstrap/                one-time per account: state bucket, OIDC provider, GitHub roles (applied by hand)
  modules/
    network/                VPC, 2 AZs, public/private/db subnets, NAT, S3 gateway endpoint, security groups
    rds-postgis/            RDS PostgreSQL 17, parameter group, subnet group, backups, managed master secret
    elasticache-redis/      Valkey/Redis OSS replication group, TLS + AUTH
    s3/                     media, audit (Object Lock), web buckets with policies and lifecycle
    kms/                    one CMK per env for RDS, S3, Secrets Manager, logs
    ecs-service/            task definition + service (+ optional ALB target group), log group, IAM roles
    alb/                    ALB, HTTPS listener, ACM cert, health checks
    cloudfront/             distribution with OAC for a web bucket, ACM cert in us-east-1
    observability/          SNS topic, CloudWatch alarms, dashboards, AWS Budgets
    github-oidc/            OIDC provider and plan/apply roles (used by bootstrap)
  envs/
    dev/ staging/ prod/     main.tf (module calls), variables.tf, terraform.tfvars (region, sizes, image_tag),
                            backend.tf (S3 state, use_lockfile = true)
  scripts/run-migrate.sh    runs the migrate task and fails on a non-zero exit
```

Accounts: two AWS accounts under one Organization, `orbit-nonprod` (dev + staging) and `orbit-prod`. ECR lives in
nonprod with a repository policy that lets prod pull. State: one S3 bucket per account, KMS-encrypted, versioned,
native S3 locking (`use_lockfile = true`, Terraform 1.10+), so no DynamoDB table.

## Build order

Week 0 is Monday 9 Nov 2026. The FA pilot (~1 Feb 2027, end of week 12) needs prod by week 10.

1. **Accounts and bootstrap (Phase 0, wk 0-2).** Region decided; accounts created; `infra/bootstrap` applied by an
   admin: state buckets, GitHub OIDC provider, roles `orbit-gha-plan` (read-only, trusted for
   `repo:<org>/orbit:pull_request` and `ref:refs/heads/main`), `orbit-gha-apply-nonprod` (trusted for
   `ref:refs/heads/main`), `orbit-gha-apply-prod` (trusted only for `environment:production`).
   *Done when* a workflow on a PR can run `aws sts get-caller-identity` as the plan role and nothing else can.
2. **Network + data in dev (wk 1-3).** `network`, `kms`, `rds-postgis`, `elasticache-redis`, `s3`.
   *Done when* an ECS one-off task in dev (no bastion) runs `migrate up` successfully (extensions
   `postgis`, `citext`, `pg_trgm` created by migration `00001`).
3. **api and worker in dev (wk 2-4).** `alb`, `ecs-service` x2, secrets, migrate task and script, DNS.
   *Done when* `https://api.dev.<domain>/readyz` is 200, `seed` runs as a one-off task (same image, command
   `seed`), and the worker's `:8081/readyz` is 200 with periodic jobs scheduled.
4. **CI/CD (wk 3-4).** `infra.yml` and the backend image workflow below.
   *Done when* a PR changing `infra/envs/dev` shows a plan comment, and merging it applies dev with no human step.
5. **Web hosting (wk 4-6).** `cloudfront` + web bucket prefixes for the HO portal (`ho-portal/`) and farmer web
   (`farmer-web/`), plus voice prompts.
   *Done when* the web team's pipeline can `aws s3 sync` and invalidate with outputs from Terraform.
6. **Staging in prod mode (Phase 1a, wk 6-9).** Same modules, `ORBIT_ENV=prod`, real adapters (backend item 5)
   with vendor sandboxes. *Done when* staging starts in prod mode and the smoke flow passes there
   (`tools/smoke_test.py` needs a staging mode first; see `tools/implementation-plan.md` item 6).
7. **Prod (wk 8-10).** Multi-AZ RDS, Redis replica, 2 api + 2 worker tasks, alarms to on-call, backups and
   cross-region copies, budget alerts. *Done when* a restore drill from a snapshot into a scratch instance works
   and the first prod deploy went through the two-reviewer gate.
8. **Nightly audit export (Phase 1a).** Audit bucket ready with Object Lock before backend item 7 ships.
   *Done when* a test object in prod cannot be deleted before its retention date.
9. **Phase 1b.** Weather feed and WhatsApp BSP secrets; short-link domain DNS. **Phase 2:** Razorpay and payout
   secrets and webhooks (`/hooks/*` via the ALB), a static NAT egress IP if a payout partner needs an allowlist,
   consider WAF on the ALB. *Done when* the Phase 2 penny test runs in prod.

## Components and sizing (pilot)

| Component | dev | staging | prod |
|---|---|---|---|
| NAT | 1 NAT gateway | 1 | 1 for the pilot, 2 (one per AZ) after |
| ALB | 1 | 1 | 1, HTTPS only, idle timeout 120 s (snapshot downloads) |
| api (Fargate, ARM64 if available) | 1 task, 0.25 vCPU / 0.5 GB | 1 x 0.5 / 1 GB | 2 x 0.5 vCPU / 1 GB, autoscale to 4 on CPU |
| worker | 1 x 0.25 / 0.5 GB (Fargate Spot ok) | 1 x 0.5 / 1 GB | 2 x 0.5 vCPU / 1 GB |
| RDS PostgreSQL 17 | `db.t4g.small`, single-AZ, 20 GB gp3 | `db.t4g.small` | `db.t4g.medium` Multi-AZ, 50 GB gp3 autoscaling |
| ElastiCache | `cache.t4g.micro`, 1 node | 1 node | `cache.t4g.small`, primary + 1 replica across AZs |
| Backups | 7 days PITR | 7 days | 30 days PITR, daily copy to the other India region |
| Logs retention | 14 days | 30 days | 90 days |

Rough prod cost at these sizes is a few hundred US dollars a month; nonprod well under that. Check the AWS
pricing calculator for the chosen region before committing, and put an AWS Budget alert on each account.

## How the backend runs on ECS

- **Image**: one image from ECR for every task; the task's `command` picks the process (`["api"]` is the default,
  `["worker"]`, `["migrate", "up"]`, `["seed"]` in dev only). It is distroless: no shell, no curl.
- **api**: `HTTP_ADDR=:8080` behind the ALB. ALB target health check `GET /readyz` (503 when Postgres is down,
  200 `degraded` when only Redis is down, so Redis loss never drains targets); `GET /healthz` is liveness only.
  `TRUST_PROXY_HEADERS=true` (only the ALB can reach the tasks). Request bodies are capped by the app (2 MiB,
  5 MiB for sync batches and CSV imports). `GET /v1/auth/app-config` sends `Cache-Control: public, max-age=300`,
  so a forced update (raising `APP_MIN_VERSION_*`) reaches phones within about 5 minutes of the task roll.
- **worker**: no public port. River elects a leader in Postgres, and only the leader schedules periodic jobs
  (`identity.maintenance`, `visits.mark_missed`, `messaging.fa_offline` hourly; `sync.retention` daily), so two
  or more worker tasks are safe. ECS `stopTimeout` 30 s, above `SHUTDOWN_TIMEOUT=20s`, so running jobs finish.
  Health: `GET :8081/readyz` (DB ping) and `/healthz` on `WORKER_HEALTH_ADDR`; keep port 8081 closed to
  everything except the VPC. The distroless image has no shell or curl, so the ECS container
  `healthCheck` uses the worker binary itself: `["CMD", "/usr/local/bin/worker", "-healthcheck"]` (probes
  `127.0.0.1:<WORKER_HEALTH_ADDR port>/readyz`, exits 0/1).
- **migrate**: a task definition with the same image and command `migrate up` (goose, then River's tables).
  `scripts/run-migrate.sh` runs it with `aws ecs run-task`, waits with `aws ecs wait tasks-stopped`, and fails
  on a non-zero exit code. Terraform runs it from a `terraform_data` resource triggered by `image_tag`, and the
  api and worker services `depends_on` it, so services roll only after migrations succeed. In prod, the script
  first takes a manual RDS snapshot. Migrations must stay backward compatible (expand, then contract), because
  old tasks keep serving during the roll. `migrate` needs only `DATABASE_URL` (owner role) and ignores the rest
  of the config, so the migrate task gets just that one secret. Run it from the same image tag before every
  deploy.
- **Database roles**: migrations run as the owner role (RDS master user, password managed by RDS in Secrets
  Manager), since they create extensions and tables. The api and worker use `orbit_app` with DML only, plus
  `REVOKE UPDATE, DELETE` on `audit_log` and `consents` (they are already append-only by trigger; this is defence
  in depth, as the plan asks). Creating `orbit_app` and its default privileges is backend Phase 0 item 4 (backlog);
  until it lands, staging uses the owner role.
- **Deploy order**: build image on tag `backend/vX.Y.Z` → push to ECR (immutable tags, scan on push) → PR bumping
  `image_tag` in `infra/envs/<env>/terraform.tfvars` → plan comment → merge → apply (migrate, then services with
  the ECS deployment circuit breaker and rollback on).

## Config and secrets mapping

Plain values go in the task definition `environment`; secrets in `secrets` (`valueFrom` a Secrets Manager ARN and
JSON key). One secret per env and service family, for example `orbit/prod/backend`.

| Variable | Source | prod value / note |
|---|---|---|
| `ORBIT_ENV` | env | `prod` in staging and prod; `dev` only in the AWS dev env until real adapters exist (dev logs OTPs: never real farmer data there) |
| `LOG_LEVEL`, `LOG_FORMAT` | env | `info`, `json` |
| `HTTP_ADDR` | env | `:8080` |
| `PUBLIC_BASE_URL` | env | `https://api.<domain>` |
| `FARMER_WEB_BASE_URL` | env | farmer-web origin, e.g. `https://f.<domain>` (or the short-link domain); SMS/WhatsApp links are `<value>/web/notices/{id}?t=...`. Empty means `PUBLIC_BASE_URL`, which is wrong once farmer-web is on CloudFront, so always set it |
| `CORS_ORIGINS` | env | the admin and farmer-web origins; `*` is refused in prod |
| `TRUST_PROXY_HEADERS` | env | `true` |
| `HTTP_MAX_BODY_BYTES`, `HTTP_LARGE_BODY_BYTES` | env | defaults |
| `DATABASE_URL` | secret | `orbit_app` user, `sslmode=require` (or `verify-full` with the RDS CA bundle in the image) |
| `DATABASE_MAX_CONNS` | env | api 20, worker 20; keep tasks x conns under the instance's `max_connections` |
| `REDIS_URL` | secret | `rediss://:<auth-token>@<primary-endpoint>:6379/0` (TLS + AUTH). Empty runs without Redis (cache misses, rate limits on Postgres) |
| `JWT_SECRET` | secret | 48 random bytes, base64; rotating it signs everyone out |
| `JWT_ISSUER`, `ACCESS_TOKEN_TTL`, `REFRESH_TTL_*`, `WEB_LINK_TTL`, `OTP_TTL` | env | defaults |
| `TOTP_ENC_KEY` | secret | required in prod; `openssl rand -base64 32`; **never change once set** |
| `DEV_FIXED_OTP` | not set | refused in prod |
| `OTP_SMS_APP_HASH` | env | the farmer app's 11-character SMS Retriever hash for the release signing key (from the mobile team); empty sends the plain OTP SMS |
| `STORAGE_PROVIDER` | env | `s3` once the adapter exists (`local` is refused in prod) |
| `STORAGE_DIR`, `STORAGE_SIGNING_KEY` | not set | dev only |
| `SMS_PROVIDER`, `PUSH_PROVIDER` | env | vendor name, `fcm` (`log` is refused in prod) |
| `WORKER_CONCURRENCY`, `SHUTDOWN_TIMEOUT` | env | `20`, `20s` |
| `WORKER_HEALTH_ADDR` | env | `:8081` (worker only; the image sets it) |
| `APP_MIN_VERSION_FARMER`, `APP_MIN_VERSION_FA` | env | default `0.0.0` (forces nothing); raise to force an update (`update_required` on heartbeats) |
| `APP_LATEST_VERSION_FARMER`, `APP_LATEST_VERSION_FA` | env | current store version (soft update prompt) |
| `APP_STORE_URL_FARMER`, `APP_STORE_URL_FA` | env | Play Store link (FA app: the closed-testing or managed link) |
| `APP_FLAGS_FARMER`, `APP_FLAGS_FA` | env | feature flags `name=true,other=false` |
| New with the adapters (names to confirm in code) | env / secret | `AWS_REGION`, media and audit bucket names (env); SMS API key, FCM service-account JSON, `SENTRY_DSN` (secret) |

Keeping secret values out of Terraform state: Terraform creates the secret containers and IAM access; values are
set out of band (`aws secretsmanager put-secret-value`) or through write-only arguments where the provider
supports them. The RDS master password uses `manage_master_user_password`.

## IAM

- Task execution role: pull from ECR, read this env's secrets, write its log groups.
- api task role: `s3:PutObject`/`GetObject` on the media bucket (presigned URLs are signed with the task role),
  KMS encrypt/decrypt with the env key.
- worker task role: the same, plus `s3:PutObject` on the audit bucket for the nightly export.
- No IAM users. Humans use SSO; break-glass prod access is logged.

## S3 and CloudFront

| Bucket | Use | Settings |
|---|---|---|
| `orbit-<env>-media` | visit and farmer photos (presigned PUT/GET) | private, SSE-KMS, versioning, abort incomplete uploads after 1 day, Intelligent-Tiering after 30 days |
| `orbit-<env>-audit` | nightly `audit_log` and `consents` export | Object Lock at creation; compliance mode in prod, governance in dev/staging; retention period is an open decision |
| `orbit-<env>-web` | `ho-portal/`, `farmer-web/`, `voice/te/` | private, served only through CloudFront with OAC |

CloudFront: one distribution per web app (HO portal from `web/apps/ho-portal`, farmer web pages from
`web/apps/farmer-web`), SPA fallback to `index.html` for the portal, long cache on hashed assets, short on
`index.html`. Voice prompts (`i18n/voice/te`) are served from the same bucket under `voice/`. The farmer-web
distribution is the `FARMER_WEB_BASE_URL` host: `/web/*` from the bucket, `/v1/web/*` forwarded to the ALB with
caching off (same origin for the page, no CORS). The API stays on the ALB domain; no farmer data is cached at the
edge.

## CI workflows (`.github/workflows/`)

- `infra.yml`: on PR touching `infra/**`: `terraform fmt -check`, `validate`, `tflint`, a security scan (trivy or
  checkov), then `plan` for each env whose folder or modules changed, posted as a PR comment (plan role). On push
  to `main`: apply dev, then staging (nonprod apply role). Prod apply job: `environment: production` (two required
  reviewers, `main` only), assumes the prod role, applies the plan it shows.
- `backend-image.yml`: on tag `backend/v*` (and on `main` for dev, tagged with the git SHA): build
  `backend/Dockerfile` (same as `make -C backend image IMAGE_TAG=<sha>`) for `linux/arm64` (and amd64 if needed),
  push to ECR. Optionally open the dev tag-bump PR automatically.
- Path filters keep workflows independent, as in `backend.yml`. CODEOWNERS: `infra/` needs the tech lead.

## Observability

- CloudWatch log groups per service; JSON logs from the backend (phones are masked, OTPs and link tokens redacted
  outside dev).
- Alarms to an SNS topic (email/Slack): ALB 5xx rate and p95 latency, unhealthy targets, ECS service running
  count below desired, RDS CPU, free storage, connections, ElastiCache health and evictions, failed migrate task,
  missing nightly audit export. A River queue-depth metric from the worker is a later backend task.
- Sentry projects for api/worker and for each app; DSNs in secrets.

## Backups and recovery

RDS automated backups with point-in-time recovery (retention in the sizing table), deletion protection and a
final snapshot in staging and prod, a manual snapshot before each prod migration, AWS Backup copying daily
snapshots to the other India region. S3 versioning on media; Object Lock on audit. Restore drill once per phase.
Redis holds nothing that can't be rebuilt, so it has no backup.

## Open decisions and blockers

| Decision | Blocks |
|---|---|
| Region: ap-south-2 or ap-south-1 (and service availability check) | everything |
| Domain names (api, admin, farmer web, short links) and who owns DNS | 3, 5, SMS links |
| AWS account and Organization owner, SSO set-up | 1 |
| Audit export retention period (Object Lock) | 8 |
| SMS vendor, FCM project, later WhatsApp BSP, Razorpay, payout partner | 6, 9 |
| Backend prerequisites: S3/SMS/FCM adapters, real DLT IDs, `orbit_app` role, a health probe usable in the distroless image | 6, 7 |

## Definition of done for the infra folder

- `terraform fmt`, `validate` and `tflint` pass; every env plans clean from `main` with no drift.
- No secrets in the repo or in plaintext Terraform variables; no long-lived AWS keys anywhere.
- Prod applies only through the `production` environment with two approvals; dev and staging apply on merge.
- A deploy is a tag bump PR; migrations run before services and a failed migration stops the deploy.
- Backups, cross-region copies and a tested restore exist; alarms reach a person.
- Region is a variable; changing it in one env's tfvars is the only edit needed to build there.
