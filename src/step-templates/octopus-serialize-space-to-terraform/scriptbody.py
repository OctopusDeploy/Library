import argparse
import os
import stat
import re
import socket
import subprocess
import sys
from datetime import datetime
from urllib.parse import urlparse
from itertools import chain
import platform
from urllib.request import urlretrieve
import zipfile
import urllib.request
import urllib.parse
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
    parser.add_argument('--terraform-backend',
                        action='store',
                        default=get_octopusvariable_quiet(
                            'SerializeSpace.ThisInstance.Terraform.Backend') or get_octopusvariable_quiet(
                            'ThisInstance.Terraform.Backend') or 'pg',
                        help='Set this to the name of the Terraform backend to be included in the generated module.')
    parser.add_argument('--server-url',
                        action='store',
                        default=get_octopusvariable_quiet(
                            'SerializeSpace.ThisInstance.Server.Url') or get_octopusvariable_quiet(
                            'ThisInstance.Server.Url'),
                        help='Sets the server URL that holds the project to be serialized.')
    parser.add_argument('--api-key',
                        action='store',
                        default=get_octopusvariable_quiet(
                            'SerializeSpace.ThisInstance.Api.Key') or get_octopusvariable_quiet(
                            'ThisInstance.Api.Key'),
                        help='Sets the Octopus API key.')
    parser.add_argument('--space-id',
                        action='store',
                        default=get_octopusvariable_quiet(
                            'SerializeSpace.Exported.Space.Id') or get_octopusvariable_quiet(
                            'Exported.Space.Id') or get_octopusvariable_quiet('Octopus.Space.Id'),
                        help='Set this to the space ID containing the project to be serialized.')
    parser.add_argument('--upload-space-id',
                        action='store',
                        default=get_octopusvariable_quiet(
                            'SerializeSpace.Octopus.UploadSpace.Id') or get_octopusvariable_quiet(
                            'Octopus.UploadSpace.Id') or get_octopusvariable_quiet('Octopus.Space.Id'),
                        help='Set this to the space ID of the Octopus space where ' +
                             'the resulting package will be uploaded to.')
    parser.add_argument('--ignored-library-variable-sets',
                        action='store',
                        default=get_octopusvariable_quiet(
                            'SerializeSpace.Exported.Space.IgnoredLibraryVariableSet') or get_octopusvariable_quiet(
                            'Exported.Space.IgnoredLibraryVariableSet'),
                        help='A comma separated list of library variable sets to ignore.')

    parser.add_argument('--ignored-all-library-variable-sets',
                        action='store',
                        default=get_octopusvariable_quiet(
                            'SerializeSpace.Exported.Space.IgnoredAllLibraryVariableSet') or get_octopusvariable_quiet(
                            'Exported.Space.IgnoredAllLibraryVariableSet') or 'false',
                        help='Set to true to exclude library variable sets from the exported module')

    parser.add_argument('--ignored-tenants',
                        action='store',
                        default=get_octopusvariable_quiet(
                            'SerializeSpace.Exported.Space.IgnoredTenants') or get_octopusvariable_quiet(
                            'Exported.Space.IgnoredTenants'),
                        help='A comma separated list of tenants ignore.')

    parser.add_argument('--ignored-tenants-with-tag',
                        action='store',
                        default=get_octopusvariable_quiet(
                            'SerializeSpace.Exported.Space.IgnoredTenantTags') or get_octopusvariable_quiet(
                            'Exported.Space.IgnoredTenants'),
                        help='A comma separated list of tenant tags that identify tenants to ignore.')
    parser.add_argument('--ignore-all-targets',
                        action='store',
                        default=get_octopusvariable_quiet(
                            'SerializeSpace.Exported.Space.IgnoreTargets') or get_octopusvariable_quiet(
                            'Exported.Space.IgnoreTargets') or 'false',
                        help='Set to true to exclude targets from the exported module')

    parser.add_argument('--dummy-secret-variables',
                        action='store',
                        default=get_octopusvariable_quiet(
                            'SerializeSpace.Exported.Space.DummySecrets') or get_octopusvariable_quiet(
                            'Exported.Space.DummySecrets') or 'false',
                        help='Set to true to set secret values, like account and feed passwords, to a dummy value by default')

    parser.add_argument('--default-secret-variables',
                        action='store',
                        default=get_octopusvariable_quiet(
                            'SerializeSpace.Exported.Space.DefaultSecrets') or get_octopusvariable_quiet(
                            'Exported.Space.DefaultSecrets') or 'false',
                        help='Set to true to set sensitive variables to the octostache template that represents the variable')
    parser.add_argument('--include-step-templates',
                        action='store',
                        default=get_octopusvariable_quiet(
                            'SerializeSpace.Exported.Space.IncludeStepTemplates') or get_octopusvariable_quiet(
                            'Exported.Space.IncludeStepTemplates') or 'false',
                        help='Set this to true to include step templates in the exported module. ' +
                             'This disables the default behaviour of detaching step templates.')
    parser.add_argument('--ignored-accounts',
                        action='store',
                        default=get_octopusvariable_quiet(
                            'SerializeSpace.Exported.Space.IgnoredAccounts') or get_octopusvariable_quiet(
                            'Exported.Space.IgnoredAccounts'),
                        help='A comma separated list of accounts to ignore.')
    parser.add_argument('--octopus-managed-terraform-vars',
                        action='store',
                        default=get_octopusvariable_quiet(
                            'SerializeSpace.Exported.Space.OctopusManagedTerraformVars') or get_octopusvariable_quiet(
                            'Exported.Space.OctopusManagedTerraformVars'),
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
    print("--server-url, ThisInstance.Server.Url, or SerializeSpace.ThisInstance.Server.Url must be defined")
    sys.exit(1)

if len(parser.api_key) == 0:
    print("--api-key, ThisInstance.Api.Key, or SerializeSpace.ThisInstance.Api.Key must be defined")
    sys.exit(1)


print("Octopus URL: " + parser.server_url)
print("Octopus Space ID: " + parser.space_id)

# Build the arguments to ignore library variable sets
ignores_library_variable_sets = parser.ignored_library_variable_sets.split(',')
ignores_library_variable_sets_args = [['-excludeLibraryVariableSetRegex', x] for x in ignores_library_variable_sets if
                                      x.strip() != '']

# Build the arguments to ignore tenants
ignores_tenants = parser.ignored_tenants.split(',')
ignores_tenants_args = [['-excludeTenants', x] for x in ignores_tenants if x.strip() != '']

# Build the arguments to ignore tenants with tags
ignored_tenants_with_tag = parser.ignored_tenants_with_tag.split(',')
ignored_tenants_with_tag_args = [['-excludeTenantsWithTag', x] for x in ignored_tenants_with_tag if x.strip() != '']

# Build the arguments to ignore accounts
ignored_accounts = parser.ignored_accounts.split(',')
ignored_accounts = [['-excludeAccountsRegex', x] for x in ignored_accounts]

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
               # Use default dummy values for secrets (e.g. a feed password). These values can still be overridden if known,
               # but allows the module to be deployed and have the secrets updated manually later.
               '-dummySecretVariableValues=' + parser.dummy_secret_variables,
               # for any secret variables, add a default value set to the octostache value of the variable
               # e.g. a secret variable called "database" has a default value of "#{database}"
               '-defaultSecretVariableValues=' + parser.default_secret_variables,
               # Add support for experimental step templates
               '-experimentalEnableStepTemplates=' + parser.include_step_templates,
               # Don't export any projects
               '-excludeAllProjects',
               # Output variables allow the Octopus space and instance to be determined from the Terraform state file.
               '-includeOctopusOutputVars',
               # Provide an option to ignore targets.
               '-excludeAllTargets=' + parser.ignore_all_targets,
               # Provide an option to exclude all library variable sets
               '-excludeAllLibraryVariableSets=' + parser.ignored_all_library_variable_sets,
               # Define the name of an Octopus variable to populte the terraform.tfvars file
               '-octopusManagedTerraformVars=' + parser.octopus_managed_terraform_vars,
               # The directory where the exported files will be saved
               '-dest', os.getcwd() + '/export'] + list(
    chain(*ignores_library_variable_sets_args, *ignores_tenants_args, *ignored_tenants_with_tag_args,
          *ignored_accounts))

print("Exporting Terraform module")
_, _, octoterra_exit = execute(export_args)

if not octoterra_exit == 0:
    print("Octoterra failed. Please check the verbose logs for more information.")
    sys.exit(1)

date = datetime.now().strftime('%Y.%m.%d.%H%M%S')

print('Looking up space name')
url = parser.server_url + '/api/Spaces/' + parser.space_id
headers = {
    'X-Octopus-ApiKey': parser.api_key,
    'Accept': 'application/json'
}
request = urllib.request.Request(url, headers=headers)

# Retry the request for up to a minute.
response = None
for x in range(12):
    response = urllib.request.urlopen(request)
    if response.getcode() == 200:
        break
    time.sleep(5)

if not response or not response.getcode() == 200:
    print('The API query failed')
    sys.exit(1)

data = json.loads(response.read().decode("utf-8"))
print('Space name is ' + data['Name'])

print("Creating Terraform module package")
if is_windows():
    execute([os.path.join(octocli_path, 'octo.exe'),
             'pack',
             '--format', 'zip',
             '--id', re.sub('[^0-9a-zA-Z]', '_', data['Name']),
             '--version', date,
             '--basePath', os.getcwd() + '\\export',
             '--outFolder', os.getcwd()])
else:
    _, _, _ = execute([os.path.join(octocli_path, 'octo'),
                       'pack',
                       '--format', 'zip',
                       '--id', re.sub('[^0-9a-zA-Z]', '_', data['Name']),
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
                       re.sub('[^0-9a-zA-Z]', '_', data['Name']) + '.' + date + '.zip',
                       '--replace-existing'])
else:
    _, _, _ = execute([os.path.join(octocli_path, 'octo'),
                       'push',
                       '--apiKey', parser.api_key,
                       '--server', parser.server_url,
                       '--space', parser.upload_space_id,
                       '--package', os.getcwd() + "/" +
                       re.sub('[^0-9a-zA-Z]', '_', data['Name']) + '.' + date + '.zip',
                       '--replace-existing'])

print("##octopus[stdout-default]")

print("Done")
