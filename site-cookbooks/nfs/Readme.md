## Description

Installs and configures NFS client or server components

## Requirements

Debian distro

## Attributes ##

*  ['nfs']['shared_dirs'] = [ { "/mnt/data"=> "/data"}, {"/mnt/scratch"=> "/scratch"} ]
      - an array of hashes of directories exported from the server { nfsexport => mountpoint }

*  ['nfs']['headnode_addr'] = ["10.193.29.218"]
      - the nfs server node ip address for clients to mount and add to fstab
