# Production approval flow blueprint

Use this as a customer-neutral build and migration specification for the Power Automate flow that gates the Prod stage. The flow belongs in the dedicated **custom pipeline host**, not in Dev/UAT/Prod.

## Required pipeline configuration

- Set **Pre-deployment step required** on the Prod deployment stage.
- Scope this flow to the configured pipeline name so it cannot accidentally complete another pipeline's gate.
- Set the approver group from `groups.approvers` in the parameter manifest.
- Use a Dataverse connection that can execute the documented pipeline action in the host.
- Save the approval-flow solution as a separate solution and include its connection references/environment variables in source control after exporting it from the host.

## Flow outline

1. Add the Microsoft Dataverse trigger **When an action is performed**.
2. Catalog: **Microsoft Dataverse Common**; Category: **Power Platform Pipelines**; Table: none; Action: `OnPreDeploymentStarted`.
3. Add a trigger condition scoped to the configured pipeline name (names are case-sensitive):

   ```text
   @equals(triggerOutputs()?['body/OutputParameters/DeploymentPipelineName'], '<PIPELINE_NAME>')
   ```

4. Start and wait for an **Approve/Reject — First to respond** approval assigned to the configured Approvers group. Include the solution, version, source/target environment, stage, deployment requester, and change summary available from the trigger.
5. On approval, call Dataverse **Perform an unbound action** for `UpdatePreDeploymentStepStatus`, passing the deployment stage run ID, status `20`, and approver comments.
6. On rejection, call the same action with status `30` and a maker-facing rejection comment.
7. Handle timeout/failure explicitly. Never mark the pending pre-deployment step complete if no approval result was received. Notify the pipeline administrator for recovery.
8. Turn the flow on, verify its connection references, and test both approval and rejection in a nonproduction deployment path.

The status/action shape is documented by Microsoft in [Extend pipelines in Power Platform](https://learn.microsoft.com/power-platform/alm/extend-pipelines). Confirm trigger output names and action parameters in the current host solution before building; use dynamic content rather than hard-coded run IDs.

## Source-control procedure

The tenant-specific flow currently must be created or exported from the custom host, then added as a solution package. Do not hand-author a flow definition JSON: connection references, trigger metadata, and action bindings are environment-sensitive. Export the host solution as unmanaged, unpack it with PAC CLI, inspect the diff, replace tenant-specific IDs with environment variables where supported, then commit the unpacked source. Deploy the managed flow solution to a recreated host and reconnect references before enabling it.

An approval flow and a deployment pipeline configuration are separate from the demo Dataverse solution. The repository preserves their design and recreation sequence but does not claim to include a portable export from any customer's tenant.

