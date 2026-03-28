import argparse
import os
import stat
import re
import socket
import subprocess
import sys
from datetime import datetime
from urllib.parse import urlparse
import urllib.request
from itertools import chain
import platform
from urllib.request import urlretrieve
import zipfile
import json
import tarfile
import random, time

# If this script is not being run as part of an Octopus step, return variables from environment variables.
# Periods are replaced with underscores, and the variable name is converted to uppercase
if "get_octopusvariable" not in globals():
    def get_octopusvariable(variable):
        return os.environ[re.sub('\\.', '_', variable.upper())]

# If this script is not being run as part of an Octopus step, print directly to std out.
if "printverbose" not in globals():
    def printverbose(msg):
        print(msg)


def printverbose_noansi(output):
    """
    Strip ANSI color codes and print the output as verbose
    :param output: The output to print
    """
    if not output:
        return

    # https://stackoverflow.com/questions/14693701/how-can-i-remove-the-ansi-escape-sequences-from-a-string-in-python
    output_no_ansi = re.sub(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])', '', output)
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


def retry_with_backoff(fn, retries=5, backoff_in_seconds=1):
    x = 0
    while True:
        try:
            return fn()
        except Exception as e:

            print(e)

            if x == retries:
                raise

            sleep = (backoff_in_seconds * 2 ** x +
                     random.uniform(0, 1))
            time.sleep(sleep)
            x += 1


def execute(args, cwd=None, env=None, print_args=None, print_output=printverbose_noansi):
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

    if print_args is not None:
        print_output(' '.join(args))

    if print_output is not None:
        print_output(stdout)
        print_output(stderr)

    return stdout, stderr, retcode


def is_windows():
    return platform.system() == 'Windows'


def init_argparse():
    parser = argparse.ArgumentParser(
        usage='%(prog)s [OPTION] [FILE]...',
        description='Serialize an Octopus project to a Terraform module'
    )
    parser.add_argument('--ignore-all-changes',
                        action='store',
                        default=get_octopusvariable_quiet(
                            'SerializeProject.Exported.Project.IgnoreAllChanges') or get_octopusvariable_quiet(
                            'Exported.Project.IgnoreAllChanges') or 'false',
                        help='Set to true to set the "lifecycle.ignore_changes" ' +
                             'setting on each exported resource to "all"')
    parser.add_argument('--ignore-variable-changes',
                        action='store',
                        default=get_octopusvariable_quiet(
                            'SerializeProject.Exported.Project.IgnoreVariableChanges') or get_octopusvariable_quiet(
                            'Exported.Project.IgnoreVariableChanges') or 'false',
                        help='Set to true to set the "lifecycle.ignore_changes" ' +
                             'setting on each exported octopus variable to "all"')
    parser.add_argument('--terraform-backend',
                        action='store',
                        default=get_octopusvariable_quiet(
                            'SerializeProject.ThisInstance.Terraform.Backend') or get_octopusvariable_quiet(
                            'ThisInstance.Terraform.Backend') or 'pg',
                        help='Set this to the name of the Terraform backend to be included in the generated module.')
    parser.add_argument('--server-url',
                        action='store',
                        default=get_octopusvariable_quiet(
                            'SerializeProject.ThisInstance.Server.Url') or get_octopusvariable_quiet(
                            'ThisInstance.Server.Url'),
                        help='Sets the server URL that holds the project to be serialized.')
    parser.add_argument('--api-key',
                        action='store',
                        default=get_octopusvariable_quiet(
                            'SerializeProject.ThisInstance.Api.Key') or get_octopusvariable_quiet(
                            'ThisInstance.Api.Key'),
                        help='Sets the Octopus API key.')
    parser.add_argument('--space-id',
                        action='store',
                        default=get_octopusvariable_quiet(
                            'SerializeProject.Exported.Space.Id') or get_octopusvariable_quiet(
                            'Exported.Space.Id') or get_octopusvariable_quiet('Octopus.Space.Id'),
                        help='Set this to the space ID containing the project to be serialized.')
    parser.add_argument('--project-name',
                        action='store',
                        default=get_octopusvariable_quiet(
                            'SerializeProject.Exported.Project.Name') or get_octopusvariable_quiet(
                            'Exported.Project.Name') or get_octopusvariable_quiet(
                            'Octopus.Project.Name'),
                        help='Set this to the name of the project to be serialized.')
    parser.add_argument('--upload-space-id',
                        action='store',
                        default=get_octopusvariable_quiet(
                            'SerializeProject.Octopus.UploadSpace.Id') or get_octopusvariable_quiet(
                            'Octopus.UploadSpace.Id') or get_octopusvariable_quiet('Octopus.Space.Id'),
                        help='Set this to the space ID of the Octopus space where ' +
                             'the resulting package will be uploaded to.')
    parser.add_argument('--ignore-cac-managed-values',
                        action='store',
                        default=get_octopusvariable_quiet(
                            'SerializeProject.Exported.Project.IgnoreCacValues') or get_octopusvariable_quiet(
                            'Exported.Project.IgnoreCacValues') or 'false',
                        help='Set this to true to exclude cac managed values like non-secret variables, ' +
                             'deployment processes, and project versioning into the Terraform module. ' +
                             'Set to false to have these values embedded into the module.')
    parser.add_argument('--exclude-cac-project-settings',
                        action='store',
                        default=get_octopusvariable_quiet(
                            'SerializeProject.Exported.Project.ExcludeCacProjectValues') or get_octopusvariable_quiet(
                            'Exported.Project.ExcludeCacProjectValues') or 'false',
                        help='Set this to true to exclude CaC settings like git connections from the exported module.')
    parser.add_argument('--ignored-library-variable-sets',
                        action='store',
                        default=get_octopusvariable_quiet(
                            'SerializeProject.Exported.Project.IgnoredLibraryVariableSet') or get_octopusvariable_quiet(
                            'Exported.Project.IgnoredLibraryVariableSet'),
                        help='A comma separated list of library variable sets to ignore.')
    parser.add_argument('--ignored-accounts',
                        action='store',
                        default=get_octopusvariable_quiet(
                            'SerializeProject.Exported.Project.IgnoredAccounts') or get_octopusvariable_quiet(
                            'Exported.Project.IgnoredAccounts'),
                        help='A comma separated list of accounts to ignore.')
    parser.add_argument('--ignored-tenants',
                        action='store',
                        default=get_octopusvariable_quiet(
                            'SerializeProject.Exported.Project.IgnoredTenants') or get_octopusvariable_quiet(
                            'Exported.Project.IgnoredTenants'),
                        help='A comma separated list of tenants to ignore.')
    parser.add_argument('--ignored-channels',
                        action='store',
                        default=get_octopusvariable_quiet(
                            'SerializeProject.Exported.Project.IgnoredChannels') or get_octopusvariable_quiet(
                            'Exported.Project.IgnoredChannels'),
                        help='A comma separated list of channels to ignore.')
    parser.add_argument('--include-step-templates',
                        action='store',
                        default=get_octopusvariable_quiet(
                            'SerializeProject.Exported.Project.IncludeStepTemplates') or get_octopusvariable_quiet(
                            'Exported.Project.IncludeStepTemplates') or 'false',
                        help='Set this to true to include step templates in the exported module. ' +
                             'This disables the default behaviour of detaching step templates.')
    parser.add_argument('--lookup-project-link-tenants',
                        action='store',
                        default=get_octopusvariable_quiet(
                            'SerializeProject.Exported.Project.LookupProjectLinkTenants') or get_octopusvariable_quiet(
                            'Exported.Project.LookupProjectLinkTenants') or 'false',
                        help='Set this option to link tenants and create tenant project variables.')
    parser.add_argument('--default-secret-variables',
                        action='store',
                        default=get_octopusvariable_quiet(
                            'SerializeProject.Exported.Project.DefaultSecrets') or get_octopusvariable_quiet(
                            'Exported.Project.DefaultSecrets') or 'false',
                        help='Set to true to set sensitive variables to the octostache template that represents the variable')
    parser.add_argument('--octopus-managed-terraform-vars',
                        action='store',
                        default=get_octopusvariable_quiet(
                            'SerializeProject.Exported.Project.OctopusManagedTerraformVars') or get_octopusvariable_quiet(
                            'Exported.Project.OctopusManagedTerraformVars'),
                        help='The name of an Octopus variable to use as the terraform.tfvars file.')

    return parser.parse_known_args()


def get_latest_github_release(owner, repo, filename):
    url = f"https://api.github.com/repos/{owner}/{repo}/releases/latest"
    releases = urllib.request.urlopen(url).read()
    contents = json.loads(releases)

    download = [asset for asset in contents.get('assets') if asset.get('name') == filename]

    if len(download) != 0:
        return download[0].get('browser_download_url')

    return None


def ensure_octo_cli_exists():
    if is_windows():
        print("Checking for the Octopus CLI")
        try:
            stdout, _, exit_code = execute(['octo.exe', 'help'])
            printverbose(stdout)
            if not exit_code == 0:
                raise "Octo CLI not found"
            return ""
        except:
            print("Downloading the Octopus CLI")
            urlretrieve('https://download.octopusdeploy.com/octopus-tools/9.0.0/OctopusTools.9.0.0.win-x64.zip',
                        'OctopusTools.zip')
            with zipfile.ZipFile('OctopusTools.zip', 'r') as zip_ref:
                zip_ref.extractall(os.getcwd())
            return os.getcwd()
    else:
        print("Checking for the Octopus CLI for Linux")
        try:
            stdout, _, exit_code = execute(['octo', 'help'])
            printverbose(stdout)
            if not exit_code == 0:
                raise "Octo CLI not found"
            return ""
        except:
            print("Downloading the Octopus CLI for Linux")
            urlretrieve('https://download.octopusdeploy.com/octopus-tools/9.0.0/OctopusTools.9.0.0.linux-x64.tar.gz',
                        'OctopusTools.tar.gz')
            with tarfile.open('OctopusTools.tar.gz') as file:
                file.extractall(os.getcwd())
                os.chmod(os.path.join(os.getcwd(), 'octo'), stat.S_IRWXO | stat.S_IRWXU | stat.S_IRWXG)
            return os.getcwd()


def ensure_octoterra_exists():
    if is_windows():
        print("Checking for the Octoterra tool for Windows")
        try:
            stdout, _, exit_code = execute(['octoterra.exe', '-version'])
            printverbose(stdout)
            if not exit_code == 0:
                raise "Octoterra not found"
            return ""
        except:
            print("Downloading Octoterra CLI for Windows")
            retry_with_backoff(lambda: urlretrieve(
                "https://github.com/OctopusSolutionsEngineering/OctopusTerraformExport/releases/latest/download/octoterra_windows_amd64.exe",
                'octoterra.exe'), 10, 30)
            return os.getcwd()
    else:
        print("Checking for the Octoterra tool for Linux")
        try:
            stdout, _, exit_code = execute(['octoterra', '-version'])
            printverbose(stdout)
            if not exit_code == 0:
                raise "Octoterra not found"
            return ""
        except:
            print("Downloading Octoterra CLI for Linux")
            retry_with_backoff(lambda: urlretrieve(
                "https://github.com/OctopusSolutionsEngineering/OctopusTerraformExport/releases/latest/download/octoterra_linux_amd64",
                'octoterra'), 10, 30)
            os.chmod(os.path.join(os.getcwd(), 'octoterra'), stat.S_IRWXO | stat.S_IRWXU | stat.S_IRWXG)
            return os.getcwd()


octocli_path = ensure_octo_cli_exists()
octoterra_path = ensure_octoterra_exists()
parser, _ = init_argparse()

# Variable precondition checks
if len(parser.server_url) == 0:
    print("--server-url, ThisInstance.Server.Url, or SerializeProject.ThisInstance.Server.Url must be defined")
    sys.exit(1)

if len(parser.api_key) == 0:
    print("--api-key, ThisInstance.Api.Key, or ThisInstance.Api.Key must be defined")
    sys.exit(1)

print("Octopus URL: " + parser.server_url)
print("Octopus Space ID: " + parser.space_id)

# Build the arguments to ignore library variable sets
ignores_library_variable_sets = parser.ignored_library_variable_sets.split(',')
ignores_library_variable_sets_args = [['-excludeLibraryVariableSet', x] for x in ignores_library_variable_sets]

# Build the arguments to ignore accounts
ignored_accounts = parser.ignored_accounts.split(',')
ignored_accounts = [['-excludeAccounts', x] for x in ignored_accounts]

# Build the arguments to ignore tenants
ignored_tenants = parser.ignored_tenants.split(',')
ignored_tenants_args = [['-excludeTenants', x] for x in ignored_tenants]

# Build the arguments to ignore channels
ignored_channels = parser.ignored_channels.split(',')
ignored_channels_args = [['-excludeChannels', x] for x in ignored_channels]

os.mkdir(os.getcwd() + '/export')

export_args = [os.path.join(octoterra_path, 'octoterra'),
               # the url of the instance
               '-url', parser.server_url,
               # the api key used to access the instance
               '-apiKey', parser.api_key,
               # add a postgres backend to the generated modules
               '-terraformBackend', parser.terraform_backend,
               # dump the generated HCL to the console
               '-console',
               # dump the project from the current space
               '-space', parser.space_id,
               # the name of the project to serialize
               '-projectName', parser.project_name,
               # ignoreProjectChanges can be set to ignore all changes to the project, variables, runbooks etc
               '-ignoreProjectChanges=' + parser.ignore_all_changes,
               # use data sources to lookup external dependencies (like environments, accounts etc) rather
               # than serialize those external resources
               '-lookupProjectDependencies',
               # for any secret variables, add a default value set to the octostache value of the variable
               # e.g. a secret variable called "database" has a default value of "#{database}"
               '-defaultSecretVariableValues=' + parser.default_secret_variables,
               # Any value that can't be replaced with an Octostache template, add a dummy value
               '-dummySecretVariableValues',
               # detach any step templates, allowing the exported project to be used in a new space
               '-detachProjectTemplates=' + str(not parser.include_step_templates),
               # allow the downstream project to move between project groups
               '-ignoreProjectGroupChanges',
               # allow the downstream project to change names
               '-ignoreProjectNameChanges',
               # CaC enabled projects will not export the deployment process, non-secret variables, and other
               # CaC managed project settings if ignoreCacManagedValues is true. It is usually desirable to
               # set this value to true, but it is false here because CaC projects created by Terraform today
               # save some variables in the database rather than writing them to the Git repo.
               '-ignoreCacManagedValues=' + parser.ignore_cac_managed_values,
               # Excluding CaC values means the resulting module does not include things like git credentials.
               # Setting excludeCaCProjectSettings to true and ignoreCacManagedValues to false essentially
               # converts a CaC project back to a database project.
               '-excludeCaCProjectSettings=' + parser.exclude_cac_project_settings,
               # This value is always true. Either this is an unmanaged project, in which case we are never
               # reapplying it; or it is a variable configured project, in which case we need to ignore
               # variable changes, or it is a shared CaC project, in which case we don't use Terraform to
               # manage variables.
               '-ignoreProjectVariableChanges=' + parser.ignore_variable_changes,
               # To have secret variables available when applying a downstream project, they must be scoped
               # to the Sync environment. But we do not need this scoping in the downstream project, so the
               # Sync environment is removed from any variable scopes when serializing it to Terraform.
               '-excludeVariableEnvironmentScopes', 'Sync',
               # Exclude any variables starting with "Private."
               '-excludeProjectVariableRegex', 'Private\\..*',
               # Capture the octopus endpoint, space ID, and space name as output vars. This is useful when
               # querying th Terraform state file to know which space and instance the resources were
               # created in. The scripts used to update downstream projects in bulk work by querying the
               # Terraform state, finding all the downstream projects, and using the space name to only process
               # resources that match the current tenant (because space names and tenant names are the same).
               # The output variables added by this option are octopus_server, octopus_space_id, and
               # octopus_space_name.
               '-includeOctopusOutputVars',
               # Where steps do not explicitly define a worker pool and reference the default one, this
               # option explicitly exports the default worker pool by name. This means if two spaces have
               # different default pools, the exported project still uses the pool that the original project
               # used.
               '-lookUpDefaultWorkerPools',
               # Link any tenants that were originally link to the project and create project tenant variables
               '-lookupProjectLinkTenants=' + parser.lookup_project_link_tenants,
               # Add support for experimental step templates
               '-experimentalEnableStepTemplates=' + parser.include_step_templates,
               # Ignore invalid channels
               '-excludeInvalidChannels',
               # The directory where the exported files will be saved
               '-dest', os.getcwd() + '/export',
               # Define the name of an Octopus variable to populate the terraform.tfvars file
               '-octopusManagedTerraformVars=' + parser.octopus_managed_terraform_vars,
               # This is a management runbook that we do not wish to export
               '-excludeRunbookRegex', '__ .*'] + list(chain(*ignores_library_variable_sets_args)) + list(
    chain(*ignored_accounts)) + list(chain(*ignored_tenants_args)) + list(chain(*ignored_channels_args))

print("Exporting Terraform module")
_, _, octoterra_exit = execute(export_args)

if not octoterra_exit == 0:
    print("Octoterra failed. Please check the logs for more information.")
    sys.exit(1)

date = datetime.now().strftime('%Y.%m.%d.%H%M%S')

print("Creating Terraform module package")
if is_windows():
    execute([os.path.join(octocli_path, 'octo.exe'),
             'pack',
             '--format', 'zip',
             '--id', re.sub('[^0-9a-zA-Z]', '_', parser.project_name),
             '--version', date,
             '--basePath', os.getcwd() + '\\export',
             '--outFolder', os.getcwd()])
else:
    _, _, _ = execute([os.path.join(octocli_path, 'octo'),
                       'pack',
                       '--format', 'zip',
                       '--id', re.sub('[^0-9a-zA-Z]', '_', parser.project_name),
                       '--version', date,
                       '--basePath', os.getcwd() + '/export',
                       '--outFolder', os.getcwd()])

print("Uploading Terraform module package")
if is_windows():
    _, _, _ = execute([os.path.join(octocli_path, 'octo.exe'),
                       'push',
                       '--apiKey', parser.api_key,
                       '--server', parser.server_url,
                       '--space', parser.upload_space_id,
                       '--package', os.getcwd() + "\\" +
                       re.sub('[^0-9a-zA-Z]', '_', parser.project_name) + '.' + date + '.zip',
                       '--replace-existing'])
else:
    _, _, _ = execute([os.path.join(octocli_path, 'octo'),
                       'push',
                       '--apiKey', parser.api_key,
                       '--server', parser.server_url,
                       '--space', parser.upload_space_id,
                       '--package', os.getcwd() + "/" +
                       re.sub('[^0-9a-zA-Z]', '_', parser.project_name) + '.' + date + '.zip',
                       '--replace-existing'])

print("##octopus[stdout-default]")

print("Done")
