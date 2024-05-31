# cluster-migration
Tools and scripts for migrating large clusters using searchable snapshots as the primary data movement mechanism.

## Setup
Download the contents of this repository. Place the files in the bin/ directory somewhere on your PATH. Put etc/profile.d/elastic-services.sh in your /etc/profile.d/ (make it executable!) and etc/elastic-services.json in your /etc.

I highly suggest creating a `migration/` directory and performing these steps there, or in a subdirectory named for your cluster, if you're migrating more than one.

## Steps
The basic set of steps follows.

### Metadata & cluster prep

-[ ] Run `dump-cluster-files mycluster` to create the various json dumps that you'll need.

#### Users
```sh
split_users
put_templates mycluster _security/user users
```
