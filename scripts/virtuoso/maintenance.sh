#!/bin/bash
USERNAME=${3:-"dba"}
PASSWORD=${4:-"dba"}
TRIPLESTORE=${2:-"triplestore"}
COMMAND=$1

if [[ "$#" -lt 1 ]]; then
    echo "command is a required parameter"
    exit -1
fi

case $COMMAND in
    "checkpoint")
        isql-v -H $TRIPLESTORE -U $USERNAME -P $PASSWORD <<EOF
    exec('checkpoint');
EOF
        ;;
    "vacuum")
        isql-v -H $TRIPLESTORE -U $USERNAME -P $PASSWORD <<EOF
    DB.DBA.vacuum();
EOF
        ;;
    "dump_quads")
        isql-v -H $TRIPLESTORE -U $USERNAME -P $PASSWORD <<EOF
         dump_nquads ('dumps', 1, 100000000, 1);
EOF
        echo "dumped quads to data/db/dumps"
        ;;
    *)
        echo "unrecognized command $COMMAND"
        exit -1
esac
