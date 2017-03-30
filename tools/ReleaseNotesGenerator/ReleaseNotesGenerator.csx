var octokit = Require<OctokitPack>();
var client = octokit.Create("ReleaseNotes");

var owner = Env.ScriptArgs[0];
var repo = Env.ScriptArgs[1];
var milestone = Env.ScriptArgs[2];
var state = Env.ScriptArgs[3] != null ? (ItemStateFilter)Enum.Parse(typeof(ItemStateFilter), Env.ScriptArgs[3]) : ItemStateFilter.Open;

Console.WriteLine("Getting all {0} issues in milestone '{1}' of repository {2}\\{3}", state, milestone, owner, repo);
var milestones = client.Issue.Milestone.GetAllForRepository(owner, repo).Result;
var milestoneNumber = milestones.First(m => m.Title == milestone).Number;
var milestoneIssues = client.Issue.GetAllForRepository(owner, repo, new Octokit.RepositoryIssueRequest { Milestone = milestoneNumber.ToString(), State = state }).Result;
if(milestoneIssues.Any())
{
	foreach(var issue in milestoneIssues)
	{
        var files = client.PullRequest.Files(owner, repo, issue.Number).Result;
        var fileName = "";
        var status = "";
        if(files.Count() == 1)
        {
            fileName += " - `";
            fileName += files[0].FileName.Replace("step-templates/", "");
            fileName += "`";
            status = files[0].Deletions == 0 ? "New: " : "Improved: ";
        }
        else
        {
            fileName += " - ";
            fileName += string.Format("[{0}]", string.Join(", ", files.Select(f=>string.Format("`{0}`", f.FileName.Replace("step-templates/", ""))).ToList()));
            status = files.All(f=>f.Deletions == 0) ? "New: " : "Improved: ";
        }
		Console.WriteLine("- {0}[#{1}]({2}){3} - {4} - via @{5}", status, issue.Number, issue.HtmlUrl, fileName, issue.Title, issue.User.Login);
	}
}
else
{
	Console.WriteLine("Yippee! There are no closed issues in milestone {0}. Great work!", milestone);
}