#!/bin/bash

#===========#
# FUNCTIONS #
#===========#

enum_users() {

  local USERS=0
  echo -e "[+]Active users:\n"
  
  while read -r usr; do  

    echo -e "$((USERS++)) - $usr\n"
    echo "[+]Last login: $(last -1 $usr | cut -f4-8 -d' ')"

    if [ $(sudo -n true -u "$usr" 2>/dev/null) ]; then
      echo -e "[!] Warning! This user can use sudo without password!\n"
    fi
    
    echo -e "[+]Sudo permissions found:\n"
    grep "$usr" /etc/sudoers | grep -v "#" || echo "None."
    
    echo -e "[+]Groups that $usr belongs to:\n"
    grep "$usr" /etc/group | cut -f1 -d':'
    echo -e "\n"

  done <<< $(egrep -v '(false|nologin|sync)' /etc/passwd | cut -f1 -d':')
  
  echo -e "Total Users Found: $USERS\n"
  return 0

}

suid_guid() {

  local DIR="$1"

  if [ -z "$1" ]; then
    DIR="/"
  fi

  local FILE_COUNTER=0
  
  echo -e "\n[+]Searching for SUID/GUID files. This may take a while.\n"
  echo -e "[+]The following SUID/GUID files were found:\n"

  for f in $(find "$DIR" perm -type f 2>/dev/null); do
    FILE_COUNTER="$((FILE_COUNTER++))"
  done

  if [ "$FILE_COUNTER" -eq 0 ]; then
    echo -e "[!]No SUID/GUID files found.\n"
  fi

  echo -e "[+]Total found: $FILE_COUNTER.\n"
  return 0
}

#=============#
# ENTRY POINT #
#=============#

if [[ "$UID" -gt 0 ]]; then
  echo -e "[!]You must run this script as root.\n"
  exit 1
fi

#suid_guid "$(pwd)"
#enum_users 
