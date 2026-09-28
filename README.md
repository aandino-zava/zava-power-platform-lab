# Governed Power Platform Lab

A customer-neutral starter repository for a demo-friendly, governed Power Platform and Copilot Studio lab. It describes a repeatable **Dev → UAT → Prod** model, parameterized tenant setup, source-controlled Power Platform solutions, GitHub Actions, and a production approval path.

> This repository is a deployment starter, not a tenant snapshot. It does not contain credentials, tenant IDs, customer-specific URLs, or an export of another tenant's solution. Supply your own values in `config/lab.parameters.json` and follow the bootstrap guide. Existing environments and agents are never moved or deleted by these scripts.

## What it builds

- A personal-productivity-only Default environment posture.
- Dev, UAT, and Prod environments, plus a dedicated deployment-pipeline host.
- Environment groups and access groups, with group-based role assignments.
- Separate DLP policy scopes for Default, NonProd, and Prod.
- A small Dataverse sample solution that can be promoted through the native Power Platform pipeline.
- A host-based deployment pipeline with a production pre-deployment approval step.
- GitHub workflows for source validation, packaging, and controlled pipeline promotion.

## Repository map

| Path | Purpose |
|---|---|
| `config/lab.parameters.example.json` | Customer inputs for names, region, group names, solution identity, and pipeline stages. |
| `scripts/` | Configuration validation, safe environment creation, and an opt-in sample table creation helper. |
| `solutions/LabPipelineDemo/` | Blank unmanaged solution seed; add a demo component in Dev and replace it with exported/unpacked source before release. |
| `.github/workflows/` | CI and manually dispatched promotion workflow. |
| `docs/` | Blog-style architecture explanation, approval-flow blueprint, and operator runbook. |

## Start here

1. Read [`docs/architecture-and-rationale.md`](docs/architecture-and-rationale.md).
2. Copy `config/lab.parameters.example.json` to `config/lab.parameters.json` and replace every `REPLACE_ME` value. The customer file is git-ignored.
3. Review [the approval-flow blueprint](docs/approval-flow-spec.md) and [the deployment runbook](docs/deployment-runbook.md), especially prerequisites and manual PPAC steps.
4. Run `pwsh ./scripts/Validate-Config.ps1 -Path ./config/lab.parameters.json` before any tenant operation.
5. Use a dedicated admin identity for initial setup. `Provision-Environments.ps1` creates missing environments only; `New-SampleTable.ps1` creates one demo table only after two exact-target confirmations. Neither overwrites existing resources. Other governance settings remain guided PPAC steps.
6. Configure GitHub Actions secrets/variables and the protected `uat` and `prod` GitHub Environments as described in the runbook.

## Deployment model

GitHub Actions validates and packages committed solution source. A manually dispatched release imports the unmanaged source into Dev and asks the **native Power Platform deployment pipeline** to promote it to the selected stage. Production must pass both the GitHub `prod` Environment protection rule and the Power Platform Prod pre-deployment gate. Do not replace the native pipeline with a direct import to Prod.

The Power Platform pipeline host, stage IDs, DLP connector classification, and some tenant-wide policies have tenant-specific requirements. The runbook calls out steps that require PPAC or a Power Platform admin review; it does not claim that every tenant setting has a supported idempotent API.

## Safety boundaries

- No automatic deletion, archiving, or movement of existing environments or Copilot Studio agents.
- Existing agents are outside this sample solution. Use Microsoft's supported Copilot Studio ALM only after assessing agent-specific dependencies.
- Tenant-wide creation restrictions and DLP changes require review because they can affect workloads beyond this lab.
- Production promotion is gated; GitHub secrets are never written to config files or solution source.
- The solution source here is a generic demonstration artifact. It is not an export of the Zava tenant's existing solution.

## References

- [Power Platform ALM](https://learn.microsoft.com/power-platform/alm/basics-alm)
- [Power Platform GitHub Actions](https://learn.microsoft.com/power-platform/alm/devops-github-actions)
- [Custom Power Platform pipeline hosts](https://learn.microsoft.com/power-platform/alm/custom-host-pipelines)
- [Extend pipelines with approval logic](https://learn.microsoft.com/power-platform/alm/extend-pipelines)
- [Power Platform CLI pipeline commands](https://learn.microsoft.com/power-platform/developer/cli/reference/pipeline)
- [Copilot Studio ALM guidance](https://learn.microsoft.com/microsoft-copilot-studio/guidance/alm)

