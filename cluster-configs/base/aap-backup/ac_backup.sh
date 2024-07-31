#!/usr/bin/env bash

set -euo pipefail

export KEEP_DAYS=5
export BACKUPS_DIR="/backups"
export AC_NAME="controller"
export NAMESPACE="ansible-automation-platform"
export BACKUP_NAME=$AC_NAME-backup-$(date +'%Y-%m-%d-%H%M')
export BACKUP_PVC=aap-controller-backup
export CLEAN_BACKUP_ON_DELETE=false

# Create a new backup resource
cat <<EOF | oc apply --validate=strict -f -
apiVersion: automationcontroller.ansible.com/v1beta1
kind: AutomationControllerBackup
metadata:
    name: $BACKUP_NAME
    labels:
        app.kubernetes.io/name: $BACKUP_NAME
        app.kubernetes.io/part-of: $BACKUP_NAME
spec:
    deployment_name: $AC_NAME
    clean_backup_on_delete: $CLEAN_BACKUP_ON_DELETE
EOF

# Delete older backups 
# sed outputs: <backup-name> <YYYY-MM-DD>
# awk returns the entries where the date is $KEEP_DAYS before the current date
# xargs deletes those filtered backups
oc get AutomationControllerBackup -n $NAMESPACE -o go-template --template '{{range .items}}{{.metadata.name}} {{.metadata.creationTimestamp}}{{"\n"}}{{end}}' \
    | sed -e 's/\(^.*\) \(....-..-..\)T.*$/\1 \2/g' \
    | awk '$2 <= "'$(date -d "$(echo $KEEP_DAYS) day ago" +'%Y-%m-%d')'" { print $1 }' \
    | xargs --no-run-if-empty oc delete AutomationControllerBackup -n $NAMESPACE