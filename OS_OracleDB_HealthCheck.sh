#! /bin/bash
# unset any variable which system may be using

echo -e '\E[36m'"*********************************************************************" $tecreset $setis
echo -e '\E[36m'"Author : prashant Dixit ---> prashantdixit@fatdba.com" $tecreset $auth
echo -e '\E[36m'"Date/Version : 07/20/2022  #1.0" $tecreset $date
echo -e '\E[36m'"*********************************************************************" $tecreset $setis

unset tecreset os architecture kernelrelease internalip externalip nameserver loadaverage

while getopts iv name
do
        case $name in
          i)iopt=1;;
          v)vopt=1;;
          *)echo "Invalid arg";;
        esac
done

if [[ ! -z $iopt ]]
then
{
wd=$(pwd)
basename "$(test -L "$0" && readlink "$0" || echo "$0")" > /tmp/scriptname
scriptname=$(echo -e -n $wd/ && cat /tmp/scriptname)
su -c "cp $scriptname /usr/bin/monitor" root && echo "test, test" || echo "Installation failed"
}
fi

if [[ ! -z $vopt ]]
then
{
echo -e "testv1.0\Test\PrashantTest"
}
fi

if [[ $# -eq 0 ]]
then
{


# Define Variable tecreset
tecreset=$(tput sgr0)


# Check OS Type
os=$(uname -o)
echo -e '\E[32m'"Operating System Type :" $tecreset $os
echo
echo
# Check OS Release Version and Name
###################################
OS=`uname -s`
REV=`uname -r`
MACH=`uname -m`

GetVersionFromFile()
{
    VERSION=`cat $1 | tr "\n" ' ' | sed s/.*VERSION.*=\ // `
}

if [ "${OS}" = "SunOS" ] ; then
    OS=Solaris
    ARCH=`uname -p`
    OSSTR="${OS} ${REV}(${ARCH} `uname -v`)"
elif [ "${OS}" = "AIX" ] ; then
    OSSTR="${OS} `oslevel` (`oslevel -r`)"
elif [ "${OS}" = "Linux" ] ; then
    KERNEL=`uname -r`
    if [ -f /etc/redhat-release ] ; then
        DIST='RedHat'
        PSUEDONAME=`cat /etc/redhat-release | sed s/.*\(// | sed s/\)//`
        REV=`cat /etc/redhat-release | sed s/.*release\ // | sed s/\ .*//`
    elif [ -f /etc/SuSE-release ] ; then
        DIST=`cat /etc/SuSE-release | tr "\n" ' '| sed s/VERSION.*//`
        REV=`cat /etc/SuSE-release | tr "\n" ' ' | sed s/.*=\ //`
    elif [ -f /etc/mandrake-release ] ; then
        DIST='Mandrake'
        PSUEDONAME=`cat /etc/mandrake-release | sed s/.*\(// | sed s/\)//`
        REV=`cat /etc/mandrake-release | sed s/.*release\ // | sed s/\ .*//`
    elif [ -f /etc/os-release ]; then
        DIST=`awk -F "PRETTY_NAME=" '{print $2}' /etc/os-release | tr -d '\n"'`
    elif [ -f /etc/debian_version ] ; then
        DIST="Debian `cat /etc/debian_version`"
        REV=""

    fi
    if ${OSSTR} [ -f /etc/UnitedLinux-release ] ; then
        DIST="${DIST}[`cat /etc/UnitedLinux-release | tr "\n" ' ' | sed s/VERSION.*//`]"
    fi

    OSSTR="${OS} ${DIST} ${REV}(${PSUEDONAME} ${KERNEL} ${MACH})"

fi

##################################
#cat /etc/os-release | grep 'NAME\|VERSION' | grep -v 'VERSION_ID' | grep -v 'PRETTY_NAME' > /tmp/osrelease
#echo -n -e '\E[32m'"OS Name :" $tecreset  && cat /tmp/osrelease | grep -v "VERSION" | grep -v CPE_NAME | cut -f2 -d\"
#echo -n -e '\E[32m'"OS Version :" $tecreset && cat /tmp/osrelease | grep -v "NAME" | grep -v CT_VERSION | cut -f2 -d\"
echo -e '\E[32m'"OS Version :" $tecreset $OSSTR
# Check Architecture
architecture=$(uname -m)
echo -e '\E[32m'"Architecture :" $tecreset $architecture
echo
echo

# Check Kernel Release
kernelrelease=$(uname -r)
echo -e '\E[32m'"Kernel Release :" $tecreset $kernelrelease
echo
echo

# Check hostname
echo -e '\E[32m'"Hostname :" $tecreset $HOSTNAME

echo
echo

# Check Logged In Users
who>/tmp/who
echo -e '\E[32m'"Logged In users :" $tecreset && cat /tmp/who
echo
echo

# Check System Uptime
tecuptime=$(uptime | awk '{print $3,$4}' | cut -f1 -d,)
echo -e '\E[32m'"System Uptime Days/(HH:MM) :" $tecreset $tecuptime

echo
echo

# Check RAM and SWAP Usages
free -g | grep -v + > /tmp/ramcache
echo -e '\E[32m'"Ram Usages :" $tecreset
cat /tmp/ramcache | grep -v "Swap"
echo -e '\E[32m'"Swap Usages :" $tecreset
cat /tmp/ramcache | grep -v "Mem"
echo
echo

# Check Disk Usages
df -kh| grep 'Filesystem\|' > /tmp/diskusage
echo -e '\E[32m'"Disk Usages :" $tecreset
cat /tmp/diskusage

echo
echo

echo -e '\E[32m'"memory details :" $tecreset $memorydetails
vmstat -s |grep -E 'total memory|used memory|free memory|total swap|free swap|used swap'

echo
echo

echo -e '\E[32m'"VMStats results 5 iterations :" $tecreset $VMStatsRes
vmstat 1 5

echo
echo

echo -e '\E[32m'"IO Stats for all disk :" $tecreset $iostatsforalldisks
iostat -m -p

echo
echo

echo -e '\E[32m'"top head :" $tecreset $tophead
# TOP Head
top -bc -n 1 -b | head 

echo
echo

echo -e '\E[32m'"System Activity in last 3 Hours :" $tecreset $sysactivityinlast3hours
sar | head -n 20

echo
echo

echo -e '\E[32m'"Listener Status :" $tecreset $listenerstatus
ps -ef|grep tns
echo 
lsnrctl status LISTENER |grep -E 'Alias|Uptime|Start Date'

echo
echo

echo -e '\E[32m'"Database Life at OS Level :" $tecreset $DatabaseStatsAtOSLevel
ps -ef|grep pmon

echo
echo

echo -e '\E[32m'"CRS Related Process Status :" $tecreset $CRSrelatedProcessStatus
ps -ef | grep -E 'init|d.bin|ocls|oprocd|diskmon|evmlogger|PID'


# Unset Variables
unset tecreset os architecture kernelrelease internalip externalip nameserver loadaverage

# Remove Temporary Files
rm /tmp/who /tmp/ramcache /tmp/diskusage
}
fi
shift $(($OPTIND -1))
