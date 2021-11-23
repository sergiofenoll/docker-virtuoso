#!/bin/bash
USERNAME=${3:-"dba"}
PASSWORD=${4:-"dba"}
TRIPLESTORE=${2:-"triplestore"}
DATE=`date +%Y%0m%0d%0H%0M%0S`
PREFIX=${1:-"backup_${DATE}_"}
if [[ "$#" -ge 4 ]]; then
    echo "Usage:"
    echo "   mu script triplestore [prefix] [hostname] [username] [password]"
    exit -1;
fi

if [[ -d "/project/data/db" ]];then
    mkdir -p /project/data/db/backups
else
    echo "WARNING:"
    echo "    did not find data/db folder in your project, so did not create data/db/backups!"
    echo " "
fi

echo "connecting to $TRIPLESTORE with $USERNAME"
isql-v -H $TRIPLESTORE -U $USERNAME -P $PASSWORD <<EOF
    exec('checkpoint');
    backup_context_clear();
    backup_online('${PREFIX}',30000,0,vector('backups'));
    exit;
EOF

