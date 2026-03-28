# This script forks a GitHub repo. It creates a token from a GitHub App installation to avoid
# having to use a regular user account.
import subprocess
import sys

# Install our own dependencies
subprocess.check_call([sys.executable, '-m', 'pip', 'install', 'jwt'])

import json
import subprocess
import sys
import os
import urllib.request
import base64
import re
import jwt
import time
import argparse
import platform
from urllib.request import urlretrieve

# If this script is not being run as part of an Octopus step, setting variables is a noop
if 'set_octopusvariable' not in globals():
    def set_octopusvariable(variable, value):
        pass

# If this script is not being run as part of an Octopus step, return variables from environment variables.
# Periods are replaced with underscores, and the variable name is converted to uppercase
if "get_octopusvariable" not in globals():
    def get_octopusvariable(variable):
        return os.environ[re.sub('\\.', '_', variable.upper())]

# If this script is not being run as part of an Octopus step, print directly to std out.
if 'printverbose' not in globals():
    def printverbose(msg):
        print(msg)


def printverbose_noansi(output):
    """
    Strip ANSI color codes and print the output as verbose
    :param output: The output to print
    """
    output_no_ansi = re.sub('\x1b\[[0-9;]*m', '', output)
    printverbose(output_no_ansi)


def get_octopusvariable_quiet(variable):
    """
    Gets an octopus variable, or an empty string if it does not exist.
    :param variable: The variable name
    :return: The variable value, or an empty string if the variable does not exist
    """
    try:
        return get_octopusvariable(variable)
    except:
        return ''


def execute(args, cwd=None, env=None, print_args=None, print_output=printverbose_noansi, raise_on_non_zero=False):
    """
        The execute method provides the ability to execute external processes while capturing and returning the
        output to std err and std out and exit code.
    """
    process = subprocess.Popen(args,
                               stdout=subprocess.PIPE,
                               stderr=subprocess.PIPE,
                               text=True,
                               cwd=cwd,
                               env=env)
    stdout, stderr = process.communicate()
    retcode = process.returncode

    if not retcode == 0 and raise_on_non_zero:
        raise Exception('command returned exit code ' + retcode)

    if print_args is not None:
        print_output(' '.join(args))

    if print_output is not None:
        print_output(stdout)
        print_output(stderr)

    return stdout, stderr, retcode


def init_argparse():
    parser = argparse.ArgumentParser(
        usage='%(prog)s [OPTION] [FILE]...',
        description='Fork a GitHub repo'
    )
    parser.add_argument('--new-repo-name', action='store',
                        default=get_octopusvariable_quiet(
                            'ForkGithubRepo.Git.Url.NewRepoName') or get_octopusvariable_quiet(
                            'Exported.Project.Name'))
    parser.add_argument('--new-repo-name-prefix', action='store',
                        default=get_octopusvariable_quiet(
                            'ForkGithubRepo.Git.Url.NewRepoNamePrefix') or get_octopusvariable_quiet(
                            'Git.Url.NewRepoNamePrefix'))
    parser.add_argument('--template-repo-name', action='store',
                        default=get_octopusvariable_quiet(
                            'ForkGithubRepo.Git.Url.OriginalRepoName') or
                                re.sub('[^a-zA-Z0-9-]', '_', get_octopusvariable_quiet('Octopus.Project.Name')))
    parser.add_argument('--tenant-name', action='store',
                        default=get_octopusvariable_quiet('Octopus.Deployment.Tenant.Name'))
    parser.add_argument('--git-organization', action='store',
                        default=get_octopusvariable_quiet(
                            'ForkGithubRepo.Git.Url.Organization') or get_octopusvariable_quiet('Git.Url.Organization'))
    parser.add_argument('--mainline-branch',
                        action='store',
                        default=get_octopusvariable_quiet(
                            'ForkGiteaRepo.Git.Branch.MainLine') or get_octopusvariable_quiet('Git.Branch.MainLine'),
                        help='The branch name to use for the fork. Defaults to "main".')
    parser.add_argument('--github-app-id', action='store',
                        default=get_octopusvariable_quiet(
                            'ForkGithubRepo.GitHub.App.Id') or get_octopusvariable_quiet('GitHub.App.Id'))
    parser.add_argument('--github-app-installation-id', action='store',
                        default=get_octopusvariable_quiet(
                            'ForkGithubRepo.GitHub.App.InstallationId') or get_octopusvariable_quiet(
                            'GitHub.App.InstallationId'))
    parser.add_argument('--github-app-private-key', action='store',
                        default=get_octopusvariable_quiet(
                            'ForkGithubRepo.GitHub.App.PrivateKey') or get_octopusvariable_quiet(
                            'GitHub.App.PrivateKey'))
    parser.add_argument('--github-access-token', action='store',
                        default=get_octopusvariable_quiet(
                            'ForkGithubRepo.GitHub.Credentials.AccessToken') or get_octopusvariable_quiet(
                            'GitHub.Credentials.AccessToken'),
                        help='The GitHub access token. This takes precedence over the --github-app-id,  --github-app-installation-id, and --github-app-private-key')

    return parser.parse_known_args()


def generate_github_token(github_app_id, github_app_private_key, github_app_installation_id):
    # Generate the tokens used by git and the GitHub API
    app_id = github_app_id
    signing_key = jwt.jwk_from_pem(github_app_private_key.encode('utf-8'))

    payload = {
        # Issued at time
        'iat': int(time.time()),
        # JWT expiration time (10 minutes maximum)
        'exp': int(time.time()) + 600,
        # GitHub App's identifier
        'iss': app_id
    }

    # Create JWT
    jwt_instance = jwt.JWT()
    encoded_jwt = jwt_instance.encode(payload, signing_key, alg='RS256')

    # Create access token
    url = 'https://api.github.com/app/installations/' + github_app_installation_id + '/access_tokens'
    headers = {
        'Authorization': 'Bearer ' + encoded_jwt,
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28'
    }
    request = urllib.request.Request(url, headers=headers, method='POST')
    response = urllib.request.urlopen(request)
    response_json = json.loads(response.read().decode())
    return response_json['token']


def generate_auth_header(token):
    auth = base64.b64encode(('x-access-token:' + token).encode('ascii'))
    return 'Basic ' + auth.decode('ascii')


def verify_template_repo(token, cac_org, template_repo):
    # Attempt to view the template repo
    url = 'https://api.github.com/repos/' + cac_org + '/' + template_repo
    try:
        headers = {
            'Accept': 'application/vnd.github+json',
            'Authorization': 'Bearer ' + token,
            'X-GitHub-Api-Version': '2022-11-28'
        }
        request = urllib.request.Request(url, headers=headers)
        urllib.request.urlopen(request)
    except:
        print('Could not find the template repo at ' + url)
        print('Check that the repo exists, and that the authentication credentials are correct')
        sys.exit(1)


def verify_new_repo(token, cac_org, new_repo):
    # Attempt to view the new repo
    try:
        url = 'https://api.github.com/repos/' + cac_org + '/' + new_repo
        headers = {
            'Accept': 'application/vnd.github+json',
            'Authorization': 'Bearer ' + token,
            'X-GitHub-Api-Version': '2022-11-28'
        }
        request = urllib.request.Request(url, headers=headers)
        urllib.request.urlopen(request)
        return True
    except:
        return False


def create_new_repo(token, cac_org, new_repo):
    # If we could not view the repo, assume it needs to be created.
    # https://docs.github.com/en/rest/repos/repos?apiVersion=2022-11-28#create-an-organization-repository
    # Note you have to use the token rather than the JWT:
    # https://stackoverflow.com/questions/39600396/bad-credentails-for-jwt-for-github-integrations-api

    headers = {
        'Authorization': 'token ' + token,
        'Content-Type': 'application/json',
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
    }

    try:
        # First try to create an organization repo:
        # https://docs.github.com/en/free-pro-team@latest/rest/repos/repos#create-an-organization-repository
        url = 'https://api.github.com/orgs/' + cac_org + '/repos'
        body = {'name': new_repo}
        request = urllib.request.Request(url, headers=headers, data=json.dumps(body).encode('utf-8'))
        urllib.request.urlopen(request)
    except urllib.error.URLError as ex:
        # Then fall back to creating a repo for the user:
        # https://docs.github.com/en/free-pro-team@latest/rest/repos/repos?apiVersion=2022-11-28#create-a-repository-for-the-authenticated-user
        if ex.code == 404:
            url = 'https://api.github.com/user/repos'
            body = {'name': new_repo}
            request = urllib.request.Request(url, headers=headers, data=json.dumps(body).encode('utf-8'))
            urllib.request.urlopen(request)
        else:
            raise ex


def fork_repo(git_executable, token, cac_org, new_repo, template_repo):
    # Clone the repo and add the upstream repo
    _, _, retcode = execute([git_executable, 'clone', 'https://' + 'x-access-token:' + token + '@'
                             + 'github.com/' + cac_org + '/' + new_repo + '.git'])

    if not retcode == 0:
        print('Failed to clone repo ' + 'https://github.com/' + cac_org + '/' + new_repo + '.git.' +
              ' Check the verbose logs for details.')
        sys.exit(1)

    _, _, retcode = execute(
        [git_executable, 'remote', 'add', 'upstream', 'https://' + 'x-access-token:' + token + '@'
         + 'github.com/' + cac_org + '/' + template_repo + '.git'],
        cwd=new_repo)

    if not retcode == 0:
        print('Failed to add remote ' + 'https://github.com/' + cac_org + '/' + template_repo + '.git. ' +
              'Check the verbose logs for details.')
        sys.exit(1)

    _, _, retcode = execute([git_executable, 'fetch', '--all'], cwd=new_repo)

    if not retcode == 0:
        print('Failed to fetch. Check the verbose logs for details.')
        sys.exit(1)

    _, _, retcode = execute(['git', 'checkout', '-b', 'upstream-' + branch, 'upstream/' + branch], cwd=new_repo)

    if not retcode == 0:
        print('Failed to checkout branch ' + branch + '. Check the verbose logs for details.')
        sys.exit(1)

    if branch != 'master' and branch != 'main':
        _, _, retcode = execute(['git', 'checkout', '-b', branch, 'origin/' + branch], cwd=new_repo)
    else:
        _, _, retcode = execute(['git', 'checkout', branch], cwd=new_repo)

    if not retcode == 0:
        print('Failed to checkout branch ' + branch + '. Check the verbose logs for details.')
        sys.exit(1)

    # Hard reset it to the template main branch.
    _, _, retcode = execute([git_executable, 'reset', '--hard', 'upstream/' + branch], cwd=new_repo)

    if not retcode == 0:
        print(
            'Failed to perform a hard reset against branch upstream/' + branch + '.'
            + ' Check the verbose logs for details.')
        sys.exit(1)

    # Push the changes.
    _, _, retcode = execute([git_executable, 'push', 'origin', branch], cwd=new_repo)

    if not retcode == 0:
        print('Failed to push changes. Check the verbose logs for details.')
        sys.exit(1)


def is_windows():
    return platform.system() == 'Windows'


def ensure_git_exists():
    if is_windows():
        print("Checking git is installed")
        try:
            stdout, _, exit_code = execute(['git', 'version'])
            printverbose(stdout)
            if not exit_code == 0:
                raise "git not found"
        except:
            print("Downloading git")
            urlretrieve('https://www.7-zip.org/a/7zr.exe', '7zr.exe')
            urlretrieve(
                'https://github.com/git-for-windows/git/releases/download/v2.42.0.windows.2/PortableGit-2.42.0.2-64-bit.7z.exe',
                'PortableGit.7z.exe')
            print("Installing git")
            print("Consider installing git on the worker or using a standard worker-tools image")
            execute(['7zr.exe', 'x', 'PortableGit.7z.exe', '-o' + os.getcwd() + '\\git', '-y'])
            return os.getcwd() + '\\git\\bin\\git'

    return 'git'


git_executable = ensure_git_exists()
parser, _ = init_argparse()

if not parser.github_access_token.strip() and not (
        parser.github_app_id.strip() and parser.github_app_private_key.strip() and parser.github_app_installation_id.strip()):
    print("You must supply the GitHub token, or the GitHub App ID and private key and installation ID")
    sys.exit(1)

if not parser.template_repo_name.strip():
    print("You must supply the upstream (or template) repo")
    sys.exit(1)

if not parser.tenant_name.strip() and not parser.new_repo_name_prefix.strip():
    print("You must define the new repo prefix or run this script against a tenant")
    sys.exit(1)

# The access token is generated from a github app or supplied directly as an access token
token = generate_github_token(parser.github_app_id, parser.github_app_private_key,
                              parser.github_app_installation_id) if len(
    parser.github_access_token.strip()) == 0 else parser.github_access_token.strip()

# The process followed here is:
# 1. Verify the manually supplied upstream repo exists
# 2. Build the name of the new downstream repo with a prefix and the new project name.
#    a. The prefix is either specified or assumed to be the name of a tenant
#    b. The new project name is either specified or assumed to be the same as the upstream project name
# 3. Create a new downstream repo if it doesn't exist
# 4. Fork the upstream repo into the downstream repo with a hard git reset

cac_org = parser.git_organization.strip()
template_repo = parser.template_repo_name.strip()
new_repo_custom_prefix = re.sub('[^a-zA-Z0-9-]', '_', parser.new_repo_name_prefix.strip())
tenant_name_sanitized = re.sub('[^a-zA-Z0-9-]', '_', parser.tenant_name.strip())
project_repo_sanitized = re.sub('[^a-zA-Z0-9-]', '_',
                                parser.new_repo_name.strip() if parser.new_repo_name.strip() else template_repo)

# The new repo is prefixed either with the custom prefix or the tenant name if no custom prefix is defined
new_repo_prefix = new_repo_custom_prefix if len(new_repo_custom_prefix) != 0 else tenant_name_sanitized

# The new repo name is the prefix + the name of thew new project
new_repo = new_repo_prefix + '_' + project_repo_sanitized if len(new_repo_prefix) != 0 else project_repo_sanitized

# Assume the main branch if nothing else was specified
branch = parser.mainline_branch or 'main'

# This is the value of the forked git repo
set_octopusvariable('NewRepo', 'https://github.com/' + cac_org + '/' + new_repo)

verify_template_repo(token, cac_org, template_repo)

if not verify_new_repo(token, cac_org, new_repo):
    create_new_repo(token, cac_org, new_repo)
    fork_repo(git_executable, token, cac_org, new_repo, template_repo)
    print(
        'Repo was forked from ' + 'https://github.com/' + cac_org + '/' + template_repo + ' to '
        + 'https://github.com/' + cac_org + '/' + new_repo)
else:
    print('Repo at https://github.com/' + cac_org + '/' + new_repo + ' already exists and has not been modified')

print('New repo URL is defined in the output variable "NewRepo": #{Octopus.Action[' +
      get_octopusvariable_quiet('Octopus.Step.Name') + '].Output.NewRepo}')
