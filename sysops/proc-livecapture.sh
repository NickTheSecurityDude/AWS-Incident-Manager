#!/bin/bash -x

MEM_CAPTURE=0
LINPEAS=1

logdate="$(date +%Y-%m-%d)-$(date +%H-%M-%S)"
logdir="/var/log/capture/live"

# Create Directories
if [[ ! -d /var/log/capture ]];then
  /bin/mkdir /var/log/capture
fi

/bin/chmod 700 /var/log/capture

if [[ ! -d ${logdir} ]];then
  /bin/mkdir ${logdir}
  /bin/chmod 700 ${logdir}
fi

# Get Open Files
if [[ ! -d ${logdir}/lsof ]];then
  /bin/mkdir ${logdir}/lsof
fi

/sbin/lsof -nP > ${logdir}/lsof/lsof_$logdate.txt

# Get Network Connections
if [[ ! -d ${logdir}/netstat ]];then
  /bin/mkdir ${logdir}/netstat
fi

/bin/netstat -anop > ${logdir}/netstat/netstat_$logdate.txt

# Get Processes
if [[ ! -d ${logdir}/ps ]];then
  /bin/mkdir ${logdir}/ps
fi

/bin/ps auwx > ${logdir}/ps/psauwx_$logdate.txt
/bin/pstree -a > ${logdir}/ps/pstree_$logdate.txt

# Get Kernel Modules
if [[ ! -d ${logdir}/lsmod ]];then
  /bin/mkdir ${logdir}/lsmod
fi

/sbin/lsmod > ${logdir}/lsmod/lsmod_$logdate.txt

# Get tmpdirs
if [[ ! -d ${logdir}/tempdirs ]];then
  /bin/mkdir ${logdir}/tempdirs
fi

/bin/ls -al /tmp/ > ${logdir}/tempdirs/tmp_$logdate.txt
/bin/ls -al /var/tmp/ > ${logdir}/tempdirs/var_tmp_$logdate.txt
/bin/ls -al /dev/shm/ > ${logdir}/tempdirs/dev_shm_$logdate.txt

# Get Users Logged In
if [[ ! -d ${logdir}/users ]];then
  /bin/mkdir ${logdir}/users
fi

/bin/w -i > ${logdir}/users/users_$logdate.txt

# Get Last Logins
if [[ ! -d ${logdir}/last ]];then
  /bin/mkdir ${logdir}/last
fi

/bin/last -Fxw > ${logdir}/last/last_$logdate.txt

# Get Mounted Disks
if [[ ! -d ${logdir}/disks ]];then
  /bin/mkdir ${logdir}/disks
fi

/bin/df -ah > ${logdir}/disks/disks_$logdate.txt

# Get top output
if [[ ! -d ${logdir}/top ]];then
  /bin/mkdir ${logdir}/top
fi

/bin/top -b -n 1 > ${logdir}/top/top_$logdate.txt

# Get Instnace Metadata
if [[ ! -d ${logdir}/metadata ]];then
  /bin/mkdir ${logdir}/metadata
fi

/bin/curl -s http://169.254.169.254/latest/dynamic/instance-identity/document > ${logdir}/metadata/document_$logdate.txt

/bin/curl -s http://169.254.169.254/latest/meta-data/public-ipv4 > ${logdir}/metadata/public-ipv4_$logdate.txt
/bin/curl -s http://169.254.169.254/latest/meta-data/iam/info > ${logdir}/metadata/iam-info_$logdate.txt
/bin/curl -s http://169.254.169.254/latest/meta-data/security-groups > ${logdir}/metadata/security-groups_$logdate.txt

macs=`/bin/curl -s http://169.254.169.254/latest/meta-data/network/interfaces/macs/`;
for mac in $macs;do
  macdir=`echo $mac |sed 's/\:/-/g'`
  /bin/mkdir ${logdir}/metadata/$macdir
  /bin/curl -s http://169.254.169.254/latest/meta-data/network/interfaces/macs/${mac}vpc-id > ${logdir}/metadata/${macdir}/vpc-id_$logdate.txt
  /bin/curl -s http://169.254.169.254/latest/meta-data/network/interfaces/macs/${mac}subnet-id > ${logdir}/metadata/${macdir}/subnet-id_$logdate.txt
  /bin/curl -s http://169.254.169.254/latest/meta-data/network/interfaces/macs/${mac}security-group-ids> ${logdir}/metadata/${macdir}/security-group-ids_$logdate.txt
  /bin/curl -s http://169.254.169.254/latest/meta-data/network/interfaces/macs/${mac}local-ipv4s > ${logdir}/metadata/${macdir}/local-ipv4s_$logdate.txt
  /bin/curl -s http://169.254.169.254/latest/meta-data/network/interfaces/macs/${mac}public-hostname > ${logdir}/metadata/${macdir}/public-hostname_$logdate.txt
  /bin/curl -s http://169.254.169.254/latest/meta-data/network/interfaces/macs/${mac}public-ipv4s > ${logdir}/metadata/${macdir}/public-ipv4s_$logdate.txt
done

# Run linpeas, if enabled
if [[ ! -d ${logdir}/linpeas ]];then
  /bin/mkdir ${logdir}/linpeas
fi

/root/sysops/linpeas-fast.sh > ${logdir}/linpeas/linpeas_$logdate.txt

# Do memory caputure, if enabled
#
# Prerequisite: (this should be done before you make the ami)
#  yum install kernel-devel
#  reboot
#
#  cd /usr/local/src
#  git clone https://github.com/504ensicsLabs/LiME

if [[ $MEM_CAPTURE -eq 1 ]];then
  if [[ ! -d ${logdir}/memory ]];then
    /bin/mkdir ${logdir}/memory
  fi

  cd /usr/local/src/LiME/src/
  if [[ ! -f /usr/local/src/LiME/src/lime-$(/bin/uname -r).ko ]];then
    make
  fi

  /sbin/rmmod lime
  /sbin/insmod /usr/local/src/LiME/src/lime-$(/bin/uname -r).ko "path=${logdir}/memory/lime_${logdate}.mem format=lime"
  /sbin/rmmod lime
fi
