## Description

Installs and configures GridEngine Master and Client Nodes
You MUST have defined a Master to use Clients and the Master can technically be a client (Compute Node).

## Requirements

Debian distro

## Attributes ##


*  ['gridengine']['master'] = ["localhost"]
      - defines the gridenine master for the clients to push the config too
*  ['gridengine']['noexec_master'] = ''
      - set to true to disable the master as being an exec node in SGE (default enabled)
