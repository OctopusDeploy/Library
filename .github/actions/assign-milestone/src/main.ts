import * as core from '@actions/core';
import * as github from '@actions/github';

async function run() {
  try {
    const milestone = core.getInput('milestone', { required: true });

    const prNumber = getPrNumber();
    if (!prNumber) {
      console.log('Could not get pull request number from context, exiting');
      return;
    }

    const client = new github.GitHub(process.env.GITHUB_TOKEN || "");

    core.debug('fetching milestone to assign to pull request');
    const milestones = await client.issues.listMilestonesForRepo({
      owner: github.context.repo.owner,
      repo: github.context.repo.repo
    });
    const milestoneToAssign = milestones.data.find(m => m.title === milestone);
    if (!milestoneToAssign) {
      console.log('Could not get milestone to assign to pull request, exiting');
      return;
    }

    await addMilestone(client, prNumber, milestoneToAssign?.number);
  } catch (error) {
    core.error(error);
    core.setFailed(error.message)
  }
}

function getPrNumber(): number | undefined {
  const pullRequest = github.context.payload.pull_request;
  if(!pullRequest) {
    return undefined;
  }

  return pullRequest.number;
}

async function addMilestone(
  client: github.GitHub,
  prNumber: number,
  milestoneNumber: number
) {
  await client.issues.update({
    owner: github.context.repo.owner,
    repo: github.context.repo.repo,
    issue_number: prNumber,
    milestone: milestoneNumber
  });
}
run();
