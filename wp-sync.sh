#!/bin/bash

# Sync a wp-install using ssh


now=$(date +%Y%m%d%H%M)
interactive=
config="default.conf"
syncDb=
syncFiles=


function pause(){
   read -p "$*"
}

function init()
{
    if [ -f ${config} ]; then
        . ${config}
    fi
}

function fn_ssh_setup()
{
    # From https://unix.stackexchange.com/questions/50508/reusing-ssh-session-for-repeated-rsync-commands
    if [ ! -d "${controlDir}" ]; then
      mkdir -p ${controlDir}
    fi

    # if [ ! -f ${controlPath} ]; then
    #    ssh -nNf -o ControlMaster=yes -o ControlPath="${controlPath}" -o ControlPersist=600 -p ${remotePort} ${remoteUser}@${remote}
    # fi

    if ! ssh -O check -o ControlPath="${controlPath}" -p ${remotePort} ${remoteUser}@${remote}; then
        echo "No SSH connection to ${remote}. Establishing a new one."
        ssh -nNf -o ControlMaster=yes -o ControlPath="${controlPath}" -o ControlPersist=600 -p ${remotePort} ${remoteUser}@${remote}
    fi
}

function fn_ssh_end()
{
    while true; do
        read -p "Do you wish to close the SSH connection? (y/n)" yn
        case $yn in
            [Yy]* ) 
                ssh -O exit -o ControlPath="${controlPath}" -p ${remotePort} ${remoteUser}@${remote};
                # rm -f ${controlPath}; 
                break;;
            [Nn]* ) exit;;
            * ) echo "Please answer yes or no.";;
        esac
    done
    
}


function fn_sync_db() 
{
    printf "Sync DB\n"

    ssh -o ControlPath="${controlPath}" -p ${remotePort} ${remoteUser}@${remote} "mkdir -p $(dirname ${remoteDbFile}); mysqldump -u ${remoteDbUser} -p\"${remoteDbPass}\" ${remoteDbName} > ${remoteDbFile}"
    # pause "Press [Enter] key to continue..."

    mkdir -p $(dirname ${localDbFile})
    rsync -az -e "ssh -o ControlPath=\"${controlPath}\" -p ${remotePort}" ${remoteUser}@${remote}:${remoteDbFile} ${localDbFile}
}

fn_sync_files()
{
    mkdir -p $(dirname ${localFilesPath})
    rsync -rz -e "ssh -o ControlPath=\"${controlPath}\" -p ${remotePort}" ${remoteUser}@${remote}:${remoteFilesPath} ${localFilesPath}
}

usage()
{
    printf "cp-wp [-i] | [-c CONFIG_FILE] | -u SSH_REMOTE_USER -P PORT | [-h]"
    printf "[files]"
    printf "[db --remote-db-name REMOTE_DB_NAME --remote-db-user REMOTE_DB_USERNAME --remote-db-pass REMOTE_DB_PASSWORD [--remote-db-file FULL_PATH_TO_FILE]"
    printf "[--local-db-name LOCAL_DB_NAME] [--local-db-user LOCAL_DB_USERNAME] [--local-db-pass LOCAL_DB_PASSWORD] [--local-db-file EXPORTED_LOCAL_DB_FILENAME]]"

}


if [ "$1" = "" ]; then
    usage
fi

while [ "$1" != "" ]; do
    case $1 in
        -c | --config )         shift
                                config=$1
                                ;;
        -r | --remote )         shift
                                remote=$1
                                ;;
        -u | --user )           shift
                                remoteUser=$1
                                ;;
        -p | --password )       shift
                                remotePass=$1
                                ;;
        -P | --port )           shift
                                remotePort=$1
                                ;;
        db )                    shift
                                syncDb=1
                                ;;
        --remote-db-name )      shift
                                remoteDbName=$1
                                ;;
        --remote-db-user )      shift
                                remoteDbUser=$1
                                ;;
        --remote-db-pass )      shift
                                remoteDbPass=$1
                                ;;
        --remote-db-file )      shift
                                remoteDbFile=$1
                                ;;
        --local-db-name )       shift
                                localDbName=$1
                                ;;
        --local-db-user )       shift
                                localDbUser=$1
                                ;;
        --local-db-pass )       shift
                                localDbPass=$1
                                ;;
        --local-db-file )       shift
                                localDbFile=$1
                                ;;


        -P | --port )           shift
                                remotePort=$1
                                ;;
        files )                 shift
                                syncFiles=1
                                ;;
        -i | --interactive )    interactive=1
                                ;;
        -h | --help )           usage
                                exit
                                ;;
        * )                     usage
                                exit 1
    esac
    shift
done

init
fn_ssh_setup

if [ "$syncDb" = 1 ]; then
    fn_sync_db
fi

if [ "$syncFiles" = 1 ]; then
    pause "Waiting..."
    fn_sync_files
fi


fn_ssh_end