#!/usr/bin/env bash
# set -x
function backup_name() {
  echo "backup-`date +%Y-%m-%d.%H.%M`"
}
#Function for backup all resources in all namespaces
function backup_cluster_all() {
folderName=$(backup_name)
mkdir -p ./$folderName

kubectl get --export -o=json ns | \
jq '.items[] |
    del(.status,
        .metadata.uid,
        .metadata.selfLink,
        .metadata.resourceVersion,
        .metadata.creationTimestamp,
        .metadata.generation
    )' > ./$folderName/ns.json
#Backup roles and related resources
for ns in $(jq -r '.metadata.name' < ./$folderName/ns.json);do
    echo "Creating backup of roles and bindings in: $ns"
    kubectl --namespace="${ns}" get --export -o=json roles,rolebindings,clusterroles,clusterrolebindings,sa | \
    jq '.items[] |
        select(.type!="kubernetes.io/service-account-token") |
        del(
            .spec.clusterIP, # clusterIP is dynamically assigned
            .spec.claimRef,  # Throw this out so we can rebind
            .metadata.uid,
            .metadata.selfLink,
            .metadata.resourceVersion,
            .metadata.creationTimestamp,
            .metadata.generation,
            .spec.template.spec.securityContext,
            .spec.template.spec.terminationGracePeriodSeconds,
            .spec.template.spec.restartPolicy,
            .spec?.ports[]?.nodePort? # Delete nodePort from service since this is dynamic
        ) |

        # Set reclaim policy to retain so we can recover volumes
        if .kind == "PersistentVolume" then 
            .spec.persistentVolumeReclaimPolicy = "Retain" 
        else
            . 
        end' >> ./$folderName/rolesAndBindings.json
done
#Backup workloads
for ns in $(jq -r '.metadata.name' < ./$folderName/ns.json);do
    echo "Creating backup of workloads in: $ns"
    kubectl --namespace="${ns}" get --export -o=json cronjobs,jobs,ing,svc,rc,secrets,ds,cm,deploy,sts,hpa,pv,pvc,quota,limits,storageclass | \
    jq '.items[] |
        select(.type!="kubernetes.io/service-account-token") |
        del(
            .spec.clusterIP, # clusterIP is dynamically assigned
            .spec.claimRef,  # Throw this out so we can rebind
            .metadata.uid,
            .metadata.selfLink,
            .metadata.resourceVersion,
            .metadata.creationTimestamp,
            .metadata.generation,
            .spec.template.spec.securityContext,
            .spec.template.spec.terminationGracePeriodSeconds,
            .spec.template.spec.restartPolicy,
            .spec?.ports[]?.nodePort? # Delete nodePort from service since this is dynamic
        ) |

        # Set reclaim policy to retain so we can recover volumes
        if .kind == "PersistentVolume" then 
            .spec.persistentVolumeReclaimPolicy = "Retain" 
        else
            . 
        end' >> ./$folderName/workloads.json
done
echo "Use "./$folderName/ns.json" to restore all namespaces into cluster"
echo "Use "./$folderName/rolesAndBindings.json" to restore all workloads into cluster"
echo "Use "./$folderName/workloads.json" to restore all workloads into cluster"
exit 0
}

#For namespace backup
function backup_namespace {
  folderName=$(backup_name)
  mkdir -p ./$folderName
  ns=(${1})
for ns in "${ns[@]}"; do
    # echo $ns
   kubectl get --export -o=json ns $ns | \
   jq 'del(.status,
        .metadata.uid,
        .metadata.selfLink,
        .metadata.resourceVersion,
        .metadata.creationTimestamp,
        .metadata.generation
    )' | tee ./$folderName/ns.json >>  ./$folderName/namespaces.json
done
#Backup roles and related resources
for ns in $(jq -r '.metadata.name' < ./$folderName/ns.json);do
    echo "Creating backup of roles and bindings in: $ns"
    kubectl --namespace="${ns}" get --export -o=json roles,rolebindings,clusterroles,clusterrolebindings,sa | \
    jq '.items[] |
        select(.type!="kubernetes.io/service-account-token") |
        del(
            .spec.clusterIP, # clusterIP is dynamically assigned
            .spec.claimRef,  # Throw this out so we can rebind
            .metadata.uid,
            .metadata.selfLink,
            .metadata.resourceVersion,
            .metadata.creationTimestamp,
            .metadata.generation,
            .spec.template.spec.securityContext,
            .spec.template.spec.terminationGracePeriodSeconds,
            .spec.template.spec.restartPolicy,
            .spec?.ports[]?.nodePort? # Delete nodePort from service since this is dynamic
        ) |

        # Set reclaim policy to retain so we can recover volumes
        if .kind == "PersistentVolume" then 
            .spec.persistentVolumeReclaimPolicy = "Retain" 
        else
            . 
        end' >> ./$folderName/rolesAndBindings.json
done
#Backup workloads
for ns in $(jq -r '.metadata.name' < ./$folderName/ns.json);do
    echo "Creating backup of workloads in: $ns"
    kubectl --namespace="${ns}" get --export -o=json cronjobs,jobs,ing,svc,rc,secrets,ds,cm,deploy,sts,hpa,pv,pvc,quota,limits,storageclass | \
    jq '.items[] |
        select(.type!="kubernetes.io/service-account-token") |
        del(
            .spec.clusterIP, # clusterIP is dynamically assigned
            .spec.claimRef,  # Throw this out so we can rebind
            .metadata.uid,
            .metadata.selfLink,
            .metadata.resourceVersion,
            .metadata.creationTimestamp,
            .metadata.generation,
            .spec.template.spec.securityContext,
            .spec.template.spec.terminationGracePeriodSeconds,
            .spec.template.spec.restartPolicy,
            .spec?.ports[]?.nodePort? # Delete nodePort from service since this is dynamic
        ) |

        # Set reclaim policy to retain so we can recover volumes
        if .kind == "PersistentVolume" then 
            .spec.persistentVolumeReclaimPolicy = "Retain" 
        else
            . 
        end' >> ./$folderName/workloads.json
done
rm ./$folderName/ns.json #<--For proper order
}
function main(){
while getopts ":an:" opt; do
  case $opt in
    a)
      backup_cluster_all
      exit 0
      ;;
    n)
      backup_namespace "${OPTARG}"
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
    \?)
    cat <<EOF
You should choose which namespace or namespaces with their related resource will be backed up

Usage:
  cluster-ops.sh backupCluster [args]

  Namespace Based Commands:
    -n,                             (-n $namespace_name -n $namespacename)  Set namespace to backup all it's related resources
    -a                              Backup all namespaces and all related resources
EOF
        exit 1
      ;;
    esac
done

}
main "$@"
