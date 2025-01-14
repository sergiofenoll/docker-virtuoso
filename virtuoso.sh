#!/bin/bash
SETTINGS_DIR=/settings
mkdir -p $SETTINGS_DIR

cd /data

mkdir -p dumps

if [ ! -f ./virtuoso.ini ];
then
  mv /virtuoso.ini . 2>/dev/null
fi

chmod +x /clean-logs.sh
mv /clean-logs.sh . 2>/dev/null

if [ ! -f "$SETTINGS_DIR/.config_set" ];
then
  echo "Converting environment variables to ini file"
  printenv | grep -P "^VIRT_" | while read setting
  do
    section=`echo "$setting" | grep -o -P "^VIRT_[^_]+" | sed 's/^.\{5\}//g'`
    key=`echo "$setting" | sed -E 's/^VIRT_[^_]+_(.*)=.*$/\1/g'`
    value=`echo "$setting" | grep -o -P "=.*$" | sed 's/^=//g'`
    echo "Registering $section[$key] to be $value"
    crudini --set virtuoso.ini $section $key "$value"
  done
  echo "`date +%Y-%m%-dT%H:%M:%S%:z`" >  $SETTINGS_DIR/.config_set
  echo "Finished converting environment variables to ini file"
fi

# NOTE: Make a temporary copy of virtuoso.ini to start Virtuoso
#       for data loading on another port
cp virtuoso.ini /tmp/virtuoso.ini
crudini --set /tmp/virtuoso.ini HTTPServer ServerPort 27015

if [ ! -f ".backup_restored" -a -d "backups" -a ! -z "$BACKUP_PREFIX" ] ;
then
    echo "Start restoring a backup with prefix $BACKUP_PREFIX"
    cd backups
    virtuoso-t +restore-backup $BACKUP_PREFIX +configfile /tmp/virtuoso.ini
    if [ $? -eq 0 ]; then
        cd /data
        echo "`date +%Y-%m-%dT%H:%M:%S%:z`" > .backup_restored
    else
        exit -1
    fi
fi

if [ ! -f ".dba_pwd_set" ];
then
  touch /sql-query.sql
  if [ "$DBA_PASSWORD" ]; then echo "user_set_password('dba', '$DBA_PASSWORD');" >> /sql-query.sql ; fi
  if [ "$SPARQL_UPDATE" = "true" ]; then echo "GRANT SPARQL_UPDATE to \"SPARQL\";" >> /sql-query.sql ; fi
  virtuoso-t +configfile /tmp/virtuoso.ini +wait && isql-v -U dba -P dba < /docker-virtuoso/dump_nquads_procedure.sql && isql-v -U dba -P dba < /sql-query.sql
  kill "$(ps aux | grep '[v]irtuoso-t' | awk '{print $2}')"
  echo "`date +%Y-%m-%dT%H:%M:%S%:z`" >  .dba_pwd_set
fi

if [ ! -f ".data_loaded" -a -d "toLoad" ] ;
then
    echo "Start data loading from toLoad folder"
    pwd="dba"
    graph="http://localhost:8890/DAV"

    if [ "$DBA_PASSWORD" ]; then pwd="$DBA_PASSWORD" ; fi
    if [ "$DEFAULT_GRAPH" ]; then graph="$DEFAULT_GRAPH" ; fi
    echo "ld_dir('toLoad', '*', '$graph');" >> /load_data.sql
    echo "rdf_loader_run();" >> /load_data.sql
    echo "exec('checkpoint');" >> /load_data.sql
    echo "WAIT_FOR_CHILDREN; " >> /load_data.sql
    echo "$(cat /load_data.sql)"
    virtuoso-t +configfile /tmp/virtuoso.ini +wait && isql-v -U dba -P "$pwd" < /load_data.sql
    kill $(ps aux | grep '[v]irtuoso-t' | awk '{print $2}')
    echo "`date +%Y-%m-%dT%H:%M:%S%:z`" > .data_loaded
fi

if [ ! -z "$ENABLE_CORS" ];
then
    echo "enabling cors on SPARQL endpoint"
    virtuoso-t +configfile /tmp/virtuoso.ini +wait && isql-v -U dba -P dba < /docker-virtuoso/add_cors.sql
    kill $(ps aux | grep '[v]irtuoso-t' | awk '{print $2}')
fi

# NOTE: below command is a workaround for a bug introduced  in 7.2.8
# see https://community.openlinksw.com/t/sparul-insert-access-denied-even-after-granting-update-permission/3448/9
# and https://github.com/openlink/virtuoso-opensource/issues/1094
if [ "$SPARQL_UPDATE" = "true" ];
then
  echo "DB.DBA.RDF_DEFAULT_USER_PERMS_SET ('nobody', 7);" > /sql-query.sql
  virtuoso-t +configfile /tmp/virtuoso.ini +wait && isql-v -U dba -P dba < /sql-query.sql
  kill "$(ps aux | grep '[v]irtuoso-t' | awk '{print $2}')"
fi

rm /tmp/virtuoso.ini
exec virtuoso-t +wait +foreground
