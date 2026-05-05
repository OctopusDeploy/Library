# Import subprocess 
import subprocess

# Define function to install specified package
def install(package):
    subprocess.check_call([sys.executable, "-m", "pip", "install", package])


# Supress warning when in a docker container
print('##octopus[stderr-ignore]',flush = True)    
    
# Check to see if cassandra-module is installed
print('Checking for Cassandra module ...',flush = True)
if 'cassandra-driver' not in sys.modules:
  # Install the cassandra-driver module
  print('Installing cassandra-driver module ...',flush = True)
  install('cassandra-driver')
else:
  print('cassandra-driver module is present ...',flush = True)

# Import cassandra modules
from cassandra.cluster import Cluster
from cassandra.auth import PlainTextAuthProvider

# Set username/password authentication provider
auth_provider = PlainTextAuthProvider(
        username='#{Cassandra.User.Name}', password='#{Cassandra.User.Password}')

# Connect to server
print('Connecting to server ...',flush = True)
cluster = None

if '#{Cassandra.User.Name}' != '' and '#{Cassandra.User.Password}' != '':
	cluster = Cluster(['#{Cassandra.Server.Name}'], auth_provider=auth_provider, port=#{Cassandra.Server.Port})
else:
	cluster = Cluster(['#{Cassandra.Server.Name}'], port=#{Cassandra.Server.Port})
                    
# Conect to cluster
session = cluster.connect()
rows = session.execute("SELECT keyspace_name FROM system_schema.keyspaces;")
keyspace = next((x for x in rows if x.keyspace_name == '#{Cassandra.Keyspace.Name}'), None)

if keyspace == None:
  # Create json document
  strategyjson = None
  if '#{Cassandra.Server.Mode}' == "SimpleStrategy":
      strategyjson = { 'class' : '#{Cassandra.Server.Mode}', 'replication_factor': '#{Cassandra.Replicas.Number}' }

  if '#{Cassandra.Server.Mode}' == "NetworkTopologyStrategy":
      strategyjson = { 'class' : '#{Cassandra.Server.Mode}', '#{Cassandra.Server.Name}' : '#{Cassandra.Replicas.Number}'}

  # Create keyspace
  print('Creating keyspace #{Cassandra.Keyspace.Name} ...',flush = True)
  session.execute("CREATE KEYSPACE IF NOT EXISTS #{Cassandra.Keyspace.Name} WITH REPLICATION = {0};".format(strategyjson))

  # Verify keyspace was created
  rows = session.execute("SELECT keyspace_name FROM system_schema.keyspaces;")

  keyspace = next((x for x in rows if x.keyspace_name == '#{Cassandra.Keyspace.Name}'), None)

  if keyspace != None:
    print('#{Cassandra.Keyspace.Name} created successfully!',flush = True)
  else:
    print('#{Cassandra.Keyspace.Name} was not created!',flush = True)
    exit(1)
else:
  print('Keyspace #{Cassandra.Keyspace.Name} already exists.',flush = True)