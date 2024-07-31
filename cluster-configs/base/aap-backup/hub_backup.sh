#!/usr/bin/env bash

set -euo pipefail

export KEEP_DAYS=5
export HUB_NAME="automation-hub"
export NAMESPACE="ansible-automation-platform"
export BACKUP_NAME=$(date +'%Y-%m-%d-%H%M')
export BACKUP_PVC=hub-backup

# Create PVC ourselves, otherwise funny (& too long identifiers) such as 'automationhub-backup-storage-automation-hub-backup-2024-07-31-1438' are picked
cat <<EOF | oc apply --validate=strict -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  finalizers:
  - kubernetes.io/pvc-protection
  labels:
    app.kubernetes.io/name: $BACKUP_PVC
    app.kubernetes.io/part-of: automationhub
  name: $BACKUP_PVC
  namespace: ansible-automation-platform
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
EOF

# Create a new backup resource
cat <<EOF | oc apply --validate=strict -f -
apiVersion: automationhub.ansible.com/v1beta1
kind: AutomationHubBackup
metadata:
    name: $BACKUP_NAME
    labels:
        app.kubernetes.io/name: $BACKUP_NAME
        app.kubernetes.io/part-of: $BACKUP_NAME
spec:
    deployment_name: $HUB_NAME
    backup_pvc: $BACKUP_PVC
    no_log: false
EOF
#
## Delete older backups 
## sed outputs: <backup-name> <YYYY-MM-DD>
## awk returns the entries where the date is $KEEP_DAYS before the current date
## xargs deletes those filtered backups
#oc get AutomationControllerBackup -n $NAMESPACE -o go-template --template '{{range .items}}{{.metadata.name}} {{.metadata.creationTimestamp}}{{"\n"}}{{end}}' \
#    | sed -e 's/\(^.*\) \(....-..-..\)T.*$/\1 \2/g' \
#    | awk '$2 <= "'$(date -d "$(echo $KEEP_DAYS) day ago" +'%Y-%m-%d')'" { print $1 }' \
#    | xargs --no-run-if-empty oc delete AutomationControllerBackup -n $NAMESPACE