# Deployment runbook

This runbook explains how to adapt the starter to a customer's tenant. Use a Power Platform administrator for tenant setup and a separate release identity for GitHub Actions. Do not run a tenant-wide change without reviewing its target scope.

## 1. Prerequisites

- Power Platform administrator for environment and tenant policy setup.
- Dataverse System Administrator in each participating environment during initial configuration.
- Entra administrator able to create security groups, if groups do not already exist.
- PAC CLI, PowerShell 7, and the Power Platform Administration PowerShell module where used.
- Private GitHub repository with Actions enabled.
- Dedicated service principal for solution release; keep bootstrap administration separate from routine solution deployment.
- Customer-approved location, Dataverse database language/currency, environment types, retention posture, and licensing.

Copy the example file and provide customer values. Confirm `location`, `currencyName`, and `languageName` against `Get-AdminPowerAppEnvironmentLocations`, `Get-AdminPowerAppCdsDatabaseCurrencies`, and `Get-AdminPowerAppCdsDatabaseLanguages` in the target tenant:

```powershell
Copy-Item config/lab.parameters.example.json config/lab.parameters.json
# Edit config/lab.parameters.json in your editor.
pwsh ./scripts/Validate-Config.ps1 -Path ./config/lab.parameters.json
pwsh ./scripts/Show-DeploymentPlan.ps1 -Path ./config/lab.parameters.json
```

`lab.parameters.json` is git-ignored. Do not place secrets, access tokens, environment IDs, or connection strings in it. Record sensitive identifiers in GitHub Secrets or the customer's approved vault.

## 2. Provision environments and groups

Use the manifest's names as examples; reuse an existing environment only after verifying its owner, purpose, location, Dataverse database, and current workload. Do not delete or repurpose existing environments automatically.

Create or identify:

1. Dev sandbox with Dataverse.
2. UAT sandbox with Dataverse.
3. Prod environment with Dataverse.
4. Dedicated pipeline host with Dataverse in the same geography as the stages.
5. Admins, Makers, Approvers, and umbrella Environment Access Entra groups.

Create security groups before environment creation where the environment's access group is to be set at creation time. Manage people by group membership. Assign the least privilege required for environment and Dataverse functions. Enable Managed Environments for pipeline target environments and account for its licensing and terms.

### PPAC tasks requiring a human readback

- Restrict Developer, Trial, and Production/Sandbox environment creation to the appropriate platform-admin boundary. Tenant settings may only accept platform admin role principals; do not assume an Entra group can be selected.
- Scope Copilot Studio authoring to the intended group where supported; verify nested group evaluation.
- Add environments to NonProd/Prod environment groups and read back the applied rules. Recheck settings after moving an environment between groups.
- Review Default, NonProd, and Prod DLP connector classifications and policy precedence. Do not copy a connector allow-list from another tenant without review.
- Configure sharing, authentication, transcript retention, AI, and preview posture. Keep AI and preview features available unless a specific risk decision says otherwise.

After creating the umbrella access group and copying its object ID, create only missing environments with Windows PowerShell 5.1. First preview with `-WhatIf`; creation provisions Dataverse and attaches the umbrella access group. Matching existing names are reported for manual review and are never modified. The script does not create Entra groups or memberships.

```powershell
./scripts/Provision-Environments.ps1 `
  -ConfigPath ./config/lab.parameters.json `
  -EnvironmentAccessGroupId <ENTRA_GROUP_OBJECT_ID> `
  -WhatIf

# After reviewing the exact preview, rerun without -WhatIf; PowerShell prompts per environment.
./scripts/Provision-Environments.ps1 `
  -ConfigPath ./config/lab.parameters.json `
  -EnvironmentAccessGroupId <ENTRA_GROUP_OBJECT_ID>
```

This starter does not automate tenant-wide settings, DLP connector classifications, environment-group rules, or the pipeline app/stage configuration. The portal/API support surface for these settings varies; use the current PPAC-supported control and retain a change record.

## 3. Install and configure the pipeline host

In PPAC, install the **Power Platform Pipelines** app in the dedicated host. In the Deployment Pipeline Configuration app:

1. Register Dev as a development environment and UAT/Prod as target environments, using their environment IDs.
2. Wait for and verify successful environment validation.
3. Create a pipeline with UAT and Prod stages in sequence.
4. Enable **Pre-deployment step required** on Prod.
5. Share the pipeline with the maker groups and assign pipeline user/admin roles in the host.
6. Record pipeline stage IDs for GitHub configuration.

The pipeline host itself need not be a Managed Environment. Pipeline target environments should be Managed Environments. See Microsoft's [custom-host setup](https://learn.microsoft.com/power-platform/alm/custom-host-pipelines).

## 4. Create the approval flow

Import or create a solution in the host containing a cloud flow triggered by the Dataverse **When an action is performed** trigger for **Power Platform Pipelines** and `OnPreDeploymentStarted`. Filter it to the intended pipeline name. Request approval from the Approvers group, then call `UpdatePreDeploymentStepStatus`: status `20` completes; status `30` rejects. Pass the stage run ID and maker-facing comments. Turn the flow on and verify connection references.

The flow must be deployed in the custom pipeline host. Package it as a separate managed solution when the organization needs source-controlled repeatability. This starter does not include an export of an existing tenant approval flow; export and review the customer's flow before adding it to source control.

Microsoft's [pipeline extension guide](https://learn.microsoft.com/power-platform/alm/extend-pipelines) documents the event and status action. Test both approval and rejection in a nonproduction path before treating the gate as operational.

## 5. Prepare the solution source

The committed `solutions/LabPipelineDemo` folder is a blank seed created with PAC CLI. To create a useful demonstration component, first create the solution in Dev, then run the helper. It requires typing the full environment URL and confirming the active PAC organization, creates one table only if absent, and will not change a pre-existing table.

```powershell
pac auth create --environment <DEV_URL>
pac org who
./scripts/New-SampleTable.ps1 `
  -EnvironmentUrl <DEV_URL> `
  -SolutionUniqueName <SOLUTION_UNIQUE_NAME> `
  -PublisherPrefix <PUBLISHER_PREFIX>
```

Then:

1. Create the solution in Dev using the unique name and publisher prefix from the manifest.
2. Add the helper-created sample table to the solution (the helper uses the documented `MSCRM.SolutionUniqueName` header when creating the table).
3. Export it as unmanaged from Dev and unpack it to replace the seed source folder.
4. Review the source diff for environment URLs, connection IDs, credentials, or tenant-specific metadata.
5. Update solution version and commit the source through a pull request.

Typical commands (confirm the exact solution unique name and environment URL first):

```powershell
pac auth list
pac org who
pac solution export --name <SOLUTION_UNIQUE_NAME> --path ./artifacts/sample-unmanaged.zip --managed false --environment <DEV_URL>
pac solution unpack --zipfile ./artifacts/sample-unmanaged.zip --folder ./solutions/LabPipelineDemo/src --packagetype Unmanaged
```

The ZIP is a build artifact and must not be committed. The unpacked source is the source of truth. Follow [PAC solution commands](https://learn.microsoft.com/power-platform/developer/cli/reference/solution).

## 6. Configure GitHub Actions

Create GitHub Environments named `uat` and `prod`. Add required reviewers to `prod`; restrict who can deploy to it. Configure these repository secrets and variables:

| Name | Type | Value |
|---|---|---|
| `PP_TENANT_ID` | Variable | Entra tenant ID |
| `PP_CLIENT_ID` | Variable | Release service principal application ID |
| `PP_DEV_URL` | Variable | Dev environment URL |
| `PP_PIPELINE_HOST_URL` | Variable | Custom pipeline host environment URL |
| `PP_SOLUTION_UNIQUE_NAME` | Variable | Exact Dataverse solution unique name |
| `PP_UAT_STAGE_ID` | Variable | UAT deployment stage ID |
| `PP_PROD_STAGE_ID` | Variable | Prod deployment stage ID |

Configure a Microsoft Entra federated identity credential for this repository and the `promote.yml` workflow, following Microsoft's [GitHub OIDC/FIC guide](https://learn.microsoft.com/power-platform/alm/tutorials/github-actions-oidc-fic). Grant the service principal only required Dataverse roles: solution import in Dev and the roles needed to request/run its shared native pipeline. Do not grant tenant-wide Power Platform Administrator to the release identity. Verify the native pipeline's delegated deployment model and stage-owner requirements for the selected configuration.

GitHub's `prod` Environment approval is an additional workflow check. The Power Platform Prod stage must retain its own required pre-deployment gate. Configure independent reviewers for a real separation-of-duties control.

## 7. Release

After merging source to the protected default branch:

1. Run **Promote through Power Platform pipeline** from Actions with the `uat` stage and new/current versions.
2. Validate the target environment using the customer's acceptance checks.
3. Start a separate run with the `prod` stage only after UAT acceptance; GitHub waits at the protected Prod Environment and the native Power Platform gate applies its own approval.
4. Record commit SHA, solution version, deployment run IDs, approver, and outcome.

The workflow imports source into Dev and then invokes `pac pipeline deploy`. That native pipeline, rather than a direct ZIP import, owns promotion to UAT and Prod. Review the actual behavior against the tenant's service-principal/delegated deployment setup before first use.

## 8. Rebuild and recovery notes

The repo can recreate source-controlled artifacts, but a Power Platform tenant is not fully represented by Git. Maintain a secured inventory with environment IDs, database properties, group object IDs, DLP connector classifications, environment-group rules, pipeline/stage IDs, approval-flow connection references, and any retention or licensing decisions.

Before a destructive reset, export solution source, back up data, review dependencies, and obtain explicit approval. This starter has no delete or environment migration commands. Existing Copilot Studio agents should remain untouched unless an owner separately approves a supported migration plan.

