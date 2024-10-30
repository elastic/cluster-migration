# cluster-migration
Tools and scripts for migrating large clusters using searchable snapshots as the primary data movement mechanism.

*DISCLAIMER: These scripts are offered in support of the idea of using searchable snapshots to re-home data to a new cluster. You agree to use them, and the procedure below, at your own risk.*

## Setup
Download the contents of this repository. Place the files in the bin/ directory somewhere on your PATH. Put etc/profile.d/elastic-services.sh in your /etc/profile.d/ (make it executable!) and etc/elastic-services.json in your /etc.

I highly suggest creating a `migration/` directory and performing these steps there, or in a subdirectory named for your cluster, if you're migrating more than one.

## Steps
The basic set of steps follows.

### Metadata & cluster prep
To create the various json dumps that you'll need.
```
dump-cluster-files src_cluster
postcurl dest_cluster _ilm/stop
``` 

#### Users
```sh
split_users
put_templates dest_cluster _security/user users
```

#### Component Templates
```sh
split_component_templates
put_templates dest_cluster _component_template component_templates
```

#### Index Templates
```sh
split_index_templates
put_templates dest_cluster _index_template index_templates
```

#### Snapshot Repos
```sh
split_snapshots
```
Right now, you'll need to update these so that they're mounted read-only on the destination cluster by editing the .json files for each.
```sh
put_templates dest_cluster _snapshot snapshots
```

#### ILM Policies
```sh
split_ilm_policies
put_templates dest_cluster _ilm/policy ilm_policies
```

#### Roles
```sh
split_roles
put_templates dest_cluster _security/role roles
```

#### Watches
```sh
split_watches
put_templates dest_cluster _watchers/watch watches
```

### ILM Updates

Create two ILM policies, `migration-dtc` and `migration-dtf`. If you use other names, you'll still need to have `-dtc` and `-dtf` appended and will need to provide the basename in later steps.

The difference between the two is that `-dtc` is the Direct To Cold policy, which ages data from hot to cold at 0m, then uses your preferred aging to move it to frozen after that. `-dtf`, accordingly, is the Direct To Frozen policy, which will age data from hot to frozen at 0m.

### Data migration

#### Frozen
```sh
split_searchable_snapshots -f dest_cluster
remount_snapshots dest_cluster
```
You can set a different number of shards in recovery, but the remount command defaults to 400. You can also set a maximum usage percent for the most-utilized disk in that tier.
Once done, proceed to update the ilm policy again. I wish this wasn't required, but it seems to be:
```sh
replace-ilm-policies dest_cluster migration-dtf frozen_indexes.txt
```
The frozen_indices.txt file is created in whatever directory holds your migration data (the directory where you ran the `remount_snapshots` script.

#### Cold
```sh
split_searchable_snapshots dest_cluster
remount_snapshots dest_cluster
```
Like the Frozen tier, you can set a different number of shards in recovery, but the remount command defaults to 400. You can also set a maximum usage percent for the most-utilized disk in that tier.
Once done, proceed to update the ilm policy again.
```sh
replace-ilm-policies dest_cluster migration-dtf cold_indexes.txt
```
The cold_indices.txt file is created in whatever directory holds your migration data (the directory where you ran the `remount_snapshots` script.

#### Hot
Hot data is best migrated by moving all feeds to the new cluster, ensuring that data ingest on the source cluster has stopped, and then using ILM to advance the hot data still on the source cluster to the cold tier (edit the ILM policy and set the transition to 0m).

Then, after the hot tier is empty apart from system indices, repeat the `dump-cluster-files` command to get a fresh set of index data and repeat the Cold migration steps above. Indexes that already exist will generate errors, but that's okay because we don't want a second copy. The indices that don't exist on the destination cluster yet will get added.

### Cleanup
After you're ready to go live, remember to:

- Make the snapshot repos read-only on the source cluster
- Make the snapshot repos read-write on the destination cluster
- `postcurl dest_cluster _ilm/start` on the destination cluster.

## Authors

- Bret Wortman, Principal Consulting Architect   bret.wortman@elastic.co

This code leverages code developed by others as well. Any issues are purely with my implemntation of their efforts, not with their contributions. Huge thanks to [cp-elastic](https://github.com/cp-elastic) for his invaluable work on the early split_* scripts and for helping me get a good grip on `jq`.
