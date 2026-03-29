import subprocess
import sys
import tempfile

# Install Conjur SDK
subprocess.check_call([sys.executable, '-m', 'pip', 'install', 'conjur-api', '--disable-pip-version-check'])
subprocess.check_call([sys.executable, '-m', 'pip', 'install', 'async-timeout', '--disable-pip-version-check'])

# Conjur SDK imports
from conjur_api.models import SslVerificationMode, ConjurConnectionInfo
from conjur_api.providers import JWTAuthenticationStrategy
from conjur_api import Client
from conjur_api.errors.errors import HttpStatusError

# Fetch configuration values
def retrieve_inputs():
    inputs = {}
    inputs["service_id"] = get_octopusvariable('CyberArk.SecretsManager.ServiceId')
    inputs["account"] = get_octopusvariable('CyberArk.SecretsManager.Account')
    inputs["url"] = get_octopusvariable('CyberArk.SecretsManager.Url')
    inputs["token"] = get_octopusvariable('CyberArk.SecretsManager.Jwt.OpenIdConnect.Jwt')
    inputs["variables"] = get_octopusvariable('CyberArk.SecretsManager.Variables')
    inputs["ca_bundle"] = get_octopusvariable('CyberArk.SecretsManager.Certificate')
    inputs["print_outputs"] = get_octopusvariable('CyberArk.SecretsManager.PrintVariableNames')
    return inputs

# Validate the required inputs are not empty
def validate_inputs(inputs):
    if not inputs["service_id"]:
        raise ValueError("Service ID is required.")
    if not inputs["account"]:
        raise ValueError("Account is required.")
    if not inputs["url"]:
        raise ValueError("Conjur URL is required.")
    if not inputs["token"]:
        raise ValueError("JWT token is required.")
    if not inputs["variables"]:
        raise ValueError("At least one variable must be specified.")

# Parse the requested input/output variables
# If no output variable name is provided, the Conjur var ID will be used
def parse_variables(variables):
    var_map = {}
    for line_number, line in enumerate(variables.strip().splitlines(), start=1):
        line = line.strip()
        if not line:
            continue

        parts = [part.strip() for part in line.split('|')]
        input_var = parts[0]
        if len(parts) == 1:
            output_var = input_var
        elif len(parts) == 2:
            output_var = parts[1]
        else:
            raise ValueError(f"Variables line {line_number} has too many '|' characters: '{line}'")

        # Basic validations
        if not input_var:
            raise ValueError(f"Variables line {line_number} is missing an input variable name: '{line}'")
        if ' ' in input_var or ' ' in output_var:
            raise ValueError(f"Variables line {line_number} has illegal spaces in a variable name: '{line}'")

        # Warn if any duplicate output vars exist
        if output_var in var_map.values():
            print(f"WARN: Two or more secrets mapped to the same output variable: `{output_var}`. The earlier value will be overwritten.")
        var_map[input_var] = output_var
    return var_map

# Configure a Conjur client for JWT authentication
def create_conjur_client(inputs):
    ssl_verification_mode = SslVerificationMode.TRUST_STORE
    cert_file = None
    # If a server certificate or CA was provided, use that instead of the default trust store
    if inputs["ca_bundle"]:
        with tempfile.NamedTemporaryFile(mode='w', delete=False) as temp_cert_file:
            temp_cert_file.write(inputs["ca_bundle"])
            cert_file = temp_cert_file.name
        ssl_verification_mode = SslVerificationMode.CA_BUNDLE

    connection_info = ConjurConnectionInfo(conjur_url=inputs["url"],
                                           account=inputs["account"],
                                           service_id=inputs["service_id"],
                                           cert_file=cert_file)
    jwt_provider = JWTAuthenticationStrategy(inputs["token"])
    return Client(connection_info,
                    authn_strategy=jwt_provider,
                    ssl_verification_mode=ssl_verification_mode,
                    async_mode=False)

# Retrieve requested secrets from Conjur and set them as sensitive Octopus variables
def retrieve_secrets(var_map, client, inputs):
    variable_ids = list(var_map.keys())
    print(f"INFO: Attempting to authenticate and retrieve {len(variable_ids)} secrets...")
    try:
        retrieval_response = client.get_many(*variable_ids)
    except HttpStatusError as e:
        if e.response is not None:
            if e.status == 401:
                print("ERROR: Authentication failed. Please validate the JWT and authenticator configuration.")
            elif e.status == 403:
                print("ERROR: Access denied. Please ensure the role has permissions to access the requested variables.")
            elif e.status == 404:
                print("ERROR: One or more requested variables not found.")
        raise

    print("INFO: Successfully retrieved secrets.")

    # Set the output variables
    for input_var, output_var in var_map.items():
        if input_var in retrieval_response:
            set_octopusvariable(output_var, retrieval_response[input_var], True)

    # Print a list output variable names if requested
    if inputs["print_outputs"]:
        output_var_names = list(dict.fromkeys(var_map.values()))
        print(f"INFO: Populated sensitive output variables: {', '.join(output_var_names)}")

# Main execution starts here - this has to be inline to run in the Octopus environment
inputs = retrieve_inputs()
validate_inputs(inputs)
var_map = parse_variables(inputs["variables"])
client = create_conjur_client(inputs)
retrieve_secrets(var_map, client, inputs)
