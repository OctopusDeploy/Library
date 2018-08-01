System.Net.ServicePointManager.SecurityProtocol |= System.Net.SecurityProtocolType.Tls12;

var octokit = Require<OctokitPack>();
var client = octokit.Create("Octopus.Library.ReleaseNotesGenerator");

var owner = Env.ScriptArgs[0];
var repo = Env.ScriptArgs[1];
var milestone = Env.ScriptArgs[2];
var state = Env.ScriptArgs[3] != null ? (ItemStateFilter)Enum.Parse(typeof(ItemStateFilter), Env.ScriptArgs[3]) : ItemStateFilter.Open;
bool isTeamCity;
if(!bool.TryParse(Env.ScriptArgs[4], out isTeamCity))
{
    isTeamCity = false;
}
async Task<string> BuildGitHubReleaseNotes()
{
    var releaseNotesBuilder = new StringBuilder();
    var milestones = await client.Issue.Milestone.GetAllForRepository(owner, repo);

    var milestoneNumber = milestones.First(m => m.Title == milestone).Number;
    var milestoneIssues = await client.Issue.GetAllForRepository(owner, repo, new Octokit.RepositoryIssueRequest { Milestone = milestoneNumber.ToString(), State = state });
    if (milestoneIssues.Any())
    {
        Console.WriteLine($"Found {milestoneIssues.Count()} closed PRs in milestone {milestone}");
        foreach (var issue in milestoneIssues)
        {
            var files = (await client.PullRequest.Files(owner, repo, issue.Number)).Where(f => f.FileName.EndsWith(".json") || f.FileName.EndsWith(".png")).ToList();
            var status = "";
            var fileNameFormat = "{0}";
            if (files.Count() > 1)
            {
                fileNameFormat = $"[{fileNameFormat}]";
            }
            var fileNameList = string.Format(fileNameFormat, string.Join(", ", files.Select(f => $"`{f.FileName.Replace("step-templates/", "")}`").ToList()));
            status = files.All(f => f.Deletions == 0) ? "New: " : "Improved: ";
            releaseNotesBuilder.AppendLine($"- {status}[#{issue.Number}]({issue.HtmlUrl}) - {fileNameList} - {issue.Title} - via @{issue.User.Login}");
        }
    }
    else
    {
        Console.WriteLine($"Well played sir! There are no closed PRs in milestone {milestone}. Woohoo!");
    }

    return releaseNotesBuilder.ToString();
}

Console.WriteLine($"Getting all {state} issues in milestone {milestone} of repository {owner}\\{repo}");
var releaseNotes = BuildGitHubReleaseNotes().Result;
if(!isTeamCity)
{
    Console.WriteLine(releaseNotes);
}
else
{
    var cwd = Directory.GetCurrentDirectory();
    var releaseNotesFile = $"{cwd}\\Library_ReleaseNotes.txt";
    File.WriteAllText(releaseNotesFile, releaseNotes);

    Console.WriteLine($"##teamcity[setParameter name='Library.ReleaseNotesFile' value='{releaseNotesFile}']");
}