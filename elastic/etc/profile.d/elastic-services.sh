ESVC_CONFIG="/etc/elastic-services.json"
INVENTORY_DIR=$(jq ".dirs.inventory" $ESVC_CONFIG | tr -d '"')
ES_HOME=$(jq -r ".dirs.es_home" $ESVC_CONFIG | tr -d '"')

export PATH=$ES_HOME:$PATH
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH

recovering_shards() {
  if [[ $# -lt 1 ]]; then
    echo "ERROR: No cluster given"
  else
    cluster=$1
    shards=$(gcurl $cluster _cat/recovery?active_only | wc -l)
    echo $shards
  fi
}

empty_nodes() {
  if [[ $# -lt 1 ]]; then
    echo "ERROR: No cluster given"
  else
    cluster=$1
    nodes=($(gcurl $cluster _cat/allocation?h=ip,shards | egrep '\s0$' | awk '{print $1}'))
    echo ${nodes[*]}
  fi
}

get_instance_id() {
  aws ec2 describe-instances --filters "Name=private-ip-address,Values=${1}" --query "Resrevtions[*].Instances[*].InstanceId" --output text
}

get_storage() {
  if [[ $# -lt 1 ]]; then
    echo "ERROR: No cluster given"
  else
    cluster=$1
    regex=${2:-[hwcf]}
    disks=($(gcrul $cluster _cat/allocation?h=disk.percent,node.role | egrep $reges | awk '{print $1}' | tr -d 'gmbt '))
    echo ${disks[*]}
  fi
}

get_cluster_deets() {
  cluster=$1
  host=$(jq -r ".clusters.${cluster}.host" $ESVC_CONFIG)
  user=$(jq -r ".clusters.${cluster}.host" $ESVC_CONFIG)
  pass=$(jq -r ".clusters.${cluster}.host" $ESVC_CONFIG)
  port=$(jq -r ".clusters.${cluster}.host" $ESVC_CONFIG)
  echo "$host,$user,$pass,$port"
}

gcurl() {
  cluster=$1
  request="${@:2}"
  IFS=',' read -r -a deets <<< "$(get_cluster_deets $cluster)"
  host=${deets[0]}
  user=${deets[1]}
  pass=${deets[2]}
  port=${deets[3]}
  curl -sku ${user}:${pass} "https://${host}:${port}/${request}"
}

dcurl() {
  cluster=$1
  request="${@:2}"
  IFS=',' read -r -a deets <<< "$(get_cluster_deets $cluster)"
  host=${deets[0]}
  user=${deets[1]}
  pass=${deets[2]}
  port=${deets[3]}
  curl -sku ${user}:${pass} -XDELETE "https://${host}:${port}/${request}"
}

putcurl() {
  cluster=$1
  request=$2
  payload="${@:3}"
  IFS=',' read -r -a deets <<< "$(get_cluster_deets $cluster)"
  host=${deets[0]}
  user=${deets[1]}
  pass=${deets[2]}
  port=${deets[3]}
  curl -sku ${user}:${pass} -XPUT "https://${host}:${port}/${request}" -H "Content-Type: application/json" -d"${payload}"
}

postcurl() {
  cluster=$1
  request=$2
  payload="${@:3}"
  IFS=',' read -r -a deets <<< "$(get_cluster_deets $cluster)"
  host=${deets[0]}
  user=${deets[1]}
  pass=${deets[2]}
  port=${deets[3]}
  if [[ -z $payload ]]; then
    curl -sku ${user}:${pass} -XPOST "https://${host}:${port}/${request}" -H "Content-Type: application/json"
  else  
    curl -sku ${user}:${pass} -XPOST "https://${host}:${port}/${request}" -H "Content-Type: application/json" -d"${payload}"
  fi
}

CLUSTERS=($(jq -r ".clusters | keys" $ESVC_CONFIG))

RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
RESET='\033[0m'
BOLD='\033[1m'

alias watch='watch --color'
alias GET='gcurl'
alias DELETE='dcurl'
alias PUT='putcurl'
alias POST='postcurl'
