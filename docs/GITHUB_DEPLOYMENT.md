# GitHub deployment policy

This policy applies to humans, AI agents, bots, and all repository changes,
including documentation, workflows, dependencies, and host settings.

## Production boundary

**Merging into `main` results in a rebuild and, after successful checks and
build, deployment of that exact revision. Treat merging as a production action.**

Adam Arbour (**@adamarbour**) is the **sole reviewer and approver**. All changes
must use a feature branch and pull request targeting `main`. Only Adam may approve and
merge a PR. Do not push directly to `main`, force-push it, enable auto-merge,
bypass review, or let an agent/bot approve or merge. Passing CI is not approval.
A request to implement a change is not permission to commit, push, or merge it.

### Current implementation versus intended behavior

The policy above defines the intended automatic deployment boundary. Currently,
`.github/workflows/check.yml` runs validation and fixture builds on pushes and
PRs; it does **not** build the real deployment candidate or activate the host.
Automatic production deployment and GitHub enforcement still need to be
implemented and verified. These documentation changes do not enable either.
Until then, use the explicitly authorized [manual deployment procedure](DEPLOYMENT.md).
Do not report a merged revision as deployed without deployment evidence.

## Human and agent workflow

1. Read `AGENTS.md` and the required repository docs. Inspect `git status` and
   preserve existing changes. Work on a feature branch, not `main`.
2. Make a scoped change with tests and docs. Run `./scripts/check.sh`; run
   real-settings evaluation/build where applicable. Never substitute a fixture
   build for the production build gate.
3. Commit/push the feature branch and open a PR only when authorized. Request
   review from `@adamarbour`, Adam's confirmed GitHub account.
4. In the PR, include the change summary, exact validation commands/results,
   expected host/service impact, persistence/secret implications, rollback plan,
   and any reboot requirement or unverified behavior. Say explicitly that
   merging targets production; documentation-only PRs are not exempt.
5. Wait for required checks and Adam's review of the final diff. After changes
   to the PR, rerun checks and obtain renewed approval. Agents may address
   feedback but must never approve, merge, or change branch protections.
6. Adam merges only when ready for the production rebuild/deployment. Once
   automation exists, that merge is authorization for its defined routine
   activation, not permission for unrelated commands, disk formatting,
   installation, identity rotation, or automatic reboot.
7. Inspect the deployment run. Record the commit SHA, candidate closure,
   previous generation, activation result, and health checks. A successful
   merge, check, or build alone does not establish deployment success.

GitHub does not allow PR authors to approve their own PRs. Under a strict
required-review rule, an Adam-authored PR cannot receive Adam's approval.
Use a legitimate separate contributor/automation author where appropriate,
or have Adam explicitly decide a policy adjustment before enforcing the rule.
Do not silently bypass it or claim self-approval satisfies GitHub review.

## GitHub enforcement checklist (Adam configures)

Documentation is not enforcement. Before enabling deployment:

- `.github/CODEOWNERS` names `@adamarbour` for every path, including itself,
  workflows, and policy files. Verify that this account has the required
  repository write permission and that GitHub recognizes the file on the PR's
  base branch after merging it. CODEOWNERS alone does not require approval,
  restrict all reviewers, or control who can merge.
- Protect `main` with a ruleset/branch protection: require PRs, at least one
  approval, required code-owner review, dismissal of stale approvals, resolved
  conversations, and successful required checks against the current PR revision.
  Ensure the required owner is Adam, with no alternate owners.
- Restrict merge/write access to `main` to Adam and disallow bypasses, direct
  pushes, force pushes, and deletion as supported by the repository's GitHub
  plan. Verify that the combined rules enforce PR-only changes even for Adam.
  Do not grant agents or Actions a bypass or merge permission. Other people
  may comment; their reviews cannot replace Adam's approval.
- Keep Actions permissions minimal. PR validation must not receive production
  credentials or execute untrusted PR code in a privileged deployment context.
- Restrict the production environment to `main`. If a separate environment
  approval is retained, Adam must be its only approver; this introduces an
  intentional post-merge gate rather than fully unattended activation.
- Review the author/self-approval constraint above before enabling strict
  required approvals. Verify actual settings and behavior; do not claim these
  controls are configured just because they are documented here.

## Automatic deployment contract (to implement next)

- A push to `main` following Adam's PR merge triggers the real-settings
  `./scripts/build.sh` on x86_64 Linux. Do not skip documentation-only commits.
  PRs and other branches validate/build only; they never deploy.
- Deploy only after successful validation and real-system realization. Transfer
  and root the exact built closure over verified OpenSSH through Tailscale;
  do not pull/rebuild on the target. Keep deployment credentials out of Git and
  logs and restrict the deployment identity's network and command access.
- Serialize production activations. Never cancel an in-progress activation.
  Before activation, reject superseded queued revisions so an older run cannot
  overwrite a newer deployment. Fail closed on build/transfer/health failures.
- Record provenance and the previous generation, preserve recovery access,
  perform post-activation health checks, and surface failures to Adam. Keep
  the previous generation for recovery; rollback does not undo persistent data.
- No automatic disk operations, installation, identity rotation, or reboot.
  Changes needing reboot retain the separately authorized acceptance procedure
  in [DEPLOYMENT.md](DEPLOYMENT.md#runtime-acceptance).

An emergency recovery is a separate, explicitly authorized operator action,
not a reason for an agent to bypass PR policy. Reconcile recovery changes back
through an Adam-reviewed PR before subsequent automatic deployments.
