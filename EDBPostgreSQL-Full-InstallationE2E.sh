#!/bin/bash
#
GREEN='\033[0;32m'
NC='\033[0m'
RED='\e[0;31m'
echo -e "${GREEN}***********************************************************************${NC}"
echo -e "${GREEN}******* Tool   : EDB Advanced Server Installer ************************${NC}"
echo -e "${GREEN}******* Author : Prashant Dixit                ************************${NC}"
echo -e "${GREEN}******* Version: 1.0                           ************************${NC}"
echo -e "${GREEN}***********************************************************************${NC}"
echo -e ""
echo -e "Before running this script please make sure that:"
echo -e "++ the Logical Volume for Data   is created and mounted in /var/lib/edb/as<version>/data "
echo -e "++ the Logical Volume for PG Wal is created and mounted in /pg_wal "
echo -e "++ the AWS Image used to create this virtual machine is: ${RED}Amazon Linux 2${NC}"
echo -e ""

# Check if the script is being run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

dbVersion="xx"

while [ "$dbVersion" != "14" ] && [ "$dbVersion" != "15" ]; do
  if [[ $dbVersion == "0" ]]; then
   echo "Install canceled by user"
   exit 1
  fi
  echo "You are going to install EDB Advanced Server"
  read -p ">>>> Select the database version [ 14, 15, 0 (to exit) ]: " dbVersion
done

EDBdatabase_Version="edb-as${dbVersion}-server"
base_dir="/var/lib/edb/as${dbVersion}"
data_dir="/var/lib/edb/as${dbVersion}/data"
service_name="edb-as-${dbVersion}.service"

cat <<EOF > /root/.vimrc
syntax on
set mouse-=a
set noincsearch
EOF

cat << EOF > /root/.bashrc
alias vmi='vim'
# EDB
alias edb='su - enterprisedb'
EOF


# Remove Python 3.7
echo "Removing Python 3.7"
yum -y remove python3

# Install Ncurses Compat Library and Tuned
echo "Installing ncurses-compat-libs dependency and tuned "
yum -y install ncurses-compat-libs tuned

# Steps to prepare EDB Repository
echo "***************************************************"
echo "*************Preparing EDB Repo********************"
echo "***************************************************"

curl -1sLf 'https://downloads.enterprisedb.com/J6F8C0qXX4alGhAPhIBKlAPAlLfHMGOL/enterprise/setup.rpm.sh' | sudo -E bash
yum install -y yum-utils pygpgme

echo -e "${RED}  -------> You might get warning "Another app is currently holding the yum lock waiting for it to exit..." ${NC}"
echo -e "${RED}  -------> ++ Kill the PID which is coming on the screen from a parallel screen ${NC}"
echo -e "${RED}  -------> ++ If you are lazy like me, JUST WAIT!! and it will automatcally goes in to SLEEP and message will go away ${NC}"

rpm --import 'https://downloads.enterprisedb.com/J6F8C0qXX4alGhAPhIBKlAPAlLfHMGOL/enterprise/gpg.E71EB0829F1EF813.key'
curl -1sLf 'https://downloads.enterprisedb.com/J6F8C0qXX4alGhAPhIBKlAPAlLfHMGOL/enterprise/config.rpm.txt?distro=el&codename=7' > /tmp/enterprisedb-enterprise.repo
yum-config-manager --add-repo '/tmp/enterprisedb-enterprise.repo'
yum -q makecache -y --disablerepo='*' --enablerepo='enterprisedb-enterprise'


# Adding Epel repository
if [[ ! -f /etc/yum.repos.d/epel.repo ]]
then
  echo "Adding Epel repository"
  cat <<EOF > /etc/yum.repos.d/epel.repo
[epel]
name=Extra Packages for Enterprise Linux 7 - \$basearch
# It is much more secure to use the metalink, but if you wish to use a local mirror
# place its address here.
#baseurl=http://download.example/pub/epel/7/\$basearch
metalink=https://mirrors.fedoraproject.org/metalink?repo=epel-7&arch=\$basearch&infra=\$infra&content=\$contentdir
failovermethod=priority
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-7

[epel-debuginfo]
name=Extra Packages for Enterprise Linux 7 - \$basearch - Debug
# It is much more secure to use the metalink, but if you wish to use a local mirror
# place its address here.
#baseurl=http://download.example/pub/epel/7/\$basearch/debug
metalink=https://mirrors.fedoraproject.org/metalink?repo=epel-debug-7&arch=\$basearch&infra=\$infra&content=\$contentdir
failovermethod=priority
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-7
gpgcheck=1

[epel-source]
name=Extra Packages for Enterprise Linux 7 - \$basearch - Source
# It is much more secure to use the metalink, but if you wish to use a local mirror
# place it's address here.
#baseurl=http://download.example/pub/epel/7/source/tree/
metalink=https://mirrors.fedoraproject.org/metalink?repo=epel-source-7&arch=\$basearch&infra=\$infra&content=\$contentdir
failovermethod=priority
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-7
gpgcheck=1

EOF
fi

# Adding Centos 7 repository
if [[ ! -f /etc/yum.repos.d/centos7.repo ]]
then
  echo "Adding Centos 7 repository"
  cat <<EOF > /etc/yum.repos.d/centos7.repo
[Centos7]
name=Centos 7 (x86_64)
baseurl=http://mirror.centos.org/centos/7/os/x86_64/
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
gpgcheck=1
enabled=1
EOF
fi

# Disable Amazon Core Repository
echo "Disabling Amazon Core Repo"
sed -i 's/enabled=1/enabled=0/g' /etc/yum.repos.d/amzn2-core.repo

yum check-update

cat <<EOF > /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
-----BEGIN PGP PUBLIC KEY BLOCK-----
Version: GnuPG v1.4.5 (GNU/Linux)

mQINBFOn/0sBEADLDyZ+DQHkcTHDQSE0a0B2iYAEXwpPvs67cJ4tmhe/iMOyVMh9
Yw/vBIF8scm6T/vPN5fopsKiW9UsAhGKg0epC6y5ed+NAUHTEa6pSOdo7CyFDwtn
4HF61Esyb4gzPT6QiSr0zvdTtgYBRZjAEPFVu3Dio0oZ5UQZ7fzdZfeixMQ8VMTQ
4y4x5vik9B+cqmGiq9AW71ixlDYVWasgR093fXiD9NLT4DTtK+KLGYNjJ8eMRqfZ
Ws7g7C+9aEGHfsGZ/SxLOumx/GfiTloal0dnq8TC7XQ/JuNdB9qjoXzRF+faDUsj
WuvNSQEqUXW1dzJjBvroEvgTdfCJfRpIgOrc256qvDMp1SxchMFltPlo5mbSMKu1
x1p4UkAzx543meMlRXOgx2/hnBm6H6L0FsSyDS6P224yF+30eeODD4Ju4BCyQ0jO
IpUxmUnApo/m0eRelI6TRl7jK6aGqSYUNhFBuFxSPKgKYBpFhVzRM63Jsvib82rY
438q3sIOUdxZY6pvMOWRkdUVoz7WBExTdx5NtGX4kdW5QtcQHM+2kht6sBnJsvcB
JYcYIwAUeA5vdRfwLKuZn6SgAUKdgeOtuf+cPR3/E68LZr784SlokiHLtQkfk98j
NXm6fJjXwJvwiM2IiFyg8aUwEEDX5U+QOCA0wYrgUQ/h8iathvBJKSc9jQARAQAB
tEJDZW50T1MtNyBLZXkgKENlbnRPUyA3IE9mZmljaWFsIFNpZ25pbmcgS2V5KSA8
c2VjdXJpdHlAY2VudG9zLm9yZz6JAjUEEwECAB8FAlOn/0sCGwMGCwkIBwMCBBUC
CAMDFgIBAh4BAheAAAoJECTGqKf0qA61TN0P/2730Th8cM+d1pEON7n0F1YiyxqG
QzwpC2Fhr2UIsXpi/lWTXIG6AlRvrajjFhw9HktYjlF4oMG032SnI0XPdmrN29lL
F+ee1ANdyvtkw4mMu2yQweVxU7Ku4oATPBvWRv+6pCQPTOMe5xPG0ZPjPGNiJ0xw
4Ns+f5Q6Gqm927oHXpylUQEmuHKsCp3dK/kZaxJOXsmq6syY1gbrLj2Anq0iWWP4
Tq8WMktUrTcc+zQ2pFR7ovEihK0Rvhmk6/N4+4JwAGijfhejxwNX8T6PCuYs5Jiv
hQvsI9FdIIlTP4XhFZ4N9ndnEwA4AH7tNBsmB3HEbLqUSmu2Rr8hGiT2Plc4Y9AO
aliW1kOMsZFYrX39krfRk2n2NXvieQJ/lw318gSGR67uckkz2ZekbCEpj/0mnHWD
3R6V7m95R6UYqjcw++Q5CtZ2tzmxomZTf42IGIKBbSVmIS75WY+cBULUx3PcZYHD
ZqAbB0Dl4MbdEH61kOI8EbN/TLl1i077r+9LXR1mOnlC3GLD03+XfY8eEBQf7137
YSMiW5r/5xwQk7xEcKlbZdmUJp3ZDTQBXT06vavvp3jlkqqH9QOE8ViZZ6aKQLqv
pL+4bs52jzuGwTMT7gOR5MzD+vT0fVS7Xm8MjOxvZgbHsAgzyFGlI1ggUQmU7lu3
uPNL0eRx4S1G4Jn5
=OGYX
-----END PGP PUBLIC KEY BLOCK-----
EOF


# Here we are installing the required version of the EDB software
yum -y install $EDBdatabase_Version
echo "********************************"
echo "$EDBdatabase_Version is Installed"
echo "********************************"


# If limits.conf exists, add the following lines
if [[ -f /etc/security/limits.conf ]]
then
  echo "enterprisedb soft nofile 1024" >> /etc/security/limits.conf
  echo "enterprisedb hard nofile 65535" >> /etc/security/limits.conf
fi

# If /pg_wal doesn't exist, create it
if [[ ! -f /pg_wal ]]
then
  mkdir /pg_wal
fi
chmod 777 /pg_wal

# Change ownership of data and wal directories to enterprisedb
echo "Change ownership of data and wal directories to enterprisedb" 
chown enterprisedb:enterprisedb /pg_wal
chown enterprisedb:enterprisedb $data_dir



# Configure tuned.conf
echo "Configure tuned.conf for enterprisedb"
mkdir -p /etc/tuned/enterprisedb
tunedConfigFile="/etc/tuned/enterprisedb/tuned.conf"
touch $tunedConfigFile
echo "[main]"                                          >> $tunedConfigFile
echo "summary=Tuned profile for PostgreSQL Instances"  >> $tunedConfigFile
echo "[bootloader]"                                    >> $tunedConfigFile
echo "cmdline=transparent_hugepage=never"              >> $tunedConfigFile
echo "[cpu]"                                           >> $tunedConfigFile
echo "governor=performance"                            >> $tunedConfigFile
echo "energy_perf_bias=performance"                    >> $tunedConfigFile
echo "min_perf_pct=100"                                >> $tunedConfigFile
echo "[sysctl]"                                        >> $tunedConfigFile
echo "vm.swappiness = 10Í"                             >> $tunedConfigFile
echo "vm.dirty_expire_centisecs = 500"                 >> $tunedConfigFile
echo "vm.dirty_writeback_centisecs = 250"              >> $tunedConfigFile
echo "vm.dirty_ratio = 10"                             >> $tunedConfigFile
echo "vm.dirty_background_ratio = 5"                   >> $tunedConfigFile
echo "vm.overcommit_memory=2"                          >> $tunedConfigFile
echo "net.ipv4.tcp_timestamps=0"                       >> $tunedConfigFile

# low value for testing - change it to 51200 for SR
echo "vm.nr_hugepages = 51"                         >> $tunedConfigFile
echo "fs.file-max = 26290322"                          >> $tunedConfigFile
echo "kernel.sem = 250 32000 100 128"                  >> $tunedConfigFile

# low value for testing - change it to 4096 for SR
echo "kernel.shmmni = 512"                            >> $tunedConfigFile

# low value for testing - change it to 1073741824 for SR
echo "kernel.shmall = 1073741824"                      >> $tunedConfigFile

# low value for testing - change it to 4398046511104 for SR
echo "kernel.shmmax = 2147483648"                   >> $tunedConfigFile
echo "kernel.panic_on_oops = 1"                        >> $tunedConfigFile
echo "net.core.rmem_default = 262144"                  >> $tunedConfigFile
echo "net.core.rmem_max = 4194304"                     >> $tunedConfigFile
echo "net.core.wmem_default = 262144"                  >> $tunedConfigFile
echo "net.core.wmem_max = 1048576"                     >> $tunedConfigFile
echo "net.ipv4.conf.all.rp_filter = 2"                 >> $tunedConfigFile
echo "net.ipv4.conf.default.rp_filter = 2"             >> $tunedConfigFile
echo "fs.aio-max-nr = 1048576"                         >> $tunedConfigFile
echo "net.ipv4.ip_local_port_range = 9000 65500"       >> $tunedConfigFile
echo ""                                                >> $tunedConfigFile
echo "[vm]"                                            >> $tunedConfigFile
echo "transparent_hugepages=never"                     >> $tunedConfigFile

# Startup tuned
echo "Starting tuned" 
systemctl start tuned

# Activating enterprisedb profile 
echo "Activating enterprisedb profile" 
/usr/sbin/tuned-adm profile enterprisedb

# Displaying active profile
echo "Displaying active profile" 
/usr/sbin/tuned-adm active



cat << EOF > /var/lib/edb/.enterprisedb_profile
export PATH=/usr/edb/as${dbVersion}/bin:\$PATH
alias vmi='vim'
export PS1='[\u@\h \W]\$ '
EOF
chown enterprisedb:enterprisedb /var/lib/edb/.enterprisedb_profile


# Initial Database Setup:
echo "Initial Database Setup"
initialPath="/usr/edb/as${dbVersion}/bin/edb-as-${dbVersion}-setup"
PGSETUP_INITDB_OPTIONS="-E UTF-8" $initialPath initdb


# Changing pg_wal and extra_wal directories to inside the storage
echo "Modifying pg_wal and extra_wal directories"
cd $data_dir
echo "I'am at $(pwd)"
# Moving pg_wal to /pg_wal/pg_wal
mv pg_wal /pg_wal/.
mkdir -p /pg_wal/extra_wal
chown enterprisedb:enterprisedb /pg_wal/extra_wal
ln -s /pg_wal/pg_wal pg_wal
ln -s /pg_wal/extra_wal extra_wal

# Changing ownership of symlinks to enterprisedb
chown enterprisedb:enterprisedb --no-dereference pg_wal
chown enterprisedb:enterprisedb --no-dereference extra_wal


# Configuring postgresql.conf and pg_hba.conf
echo "Configuring postgresql.conf and pg_hba.conf"
echo "Backing up original files"
cp -p $data_dir/postgresql.conf  $data_dir/postgresql.conf_ORIGINAL
cp -p $data_dir/pg_hba.conf  $data_dir/pg_hba.conf_ORIGINAL

cat << EOF > $data_dir/pg_hba.conf

# TYPE  DATABASE        USER            ADDRESS                 METHOD

# "local" is for Unix domain socket connections only
local   all             all                                     trust
# IPv4 local connections:
host    all             all             127.0.0.1/32            ident
# IPv6 local connections:
host    all             all             ::1/128                 ident
# Allow replication connections from localhost, by a user with the
# replication privilege.
local   replication     all                                     trust
host    replication     all             127.0.0.1/32            ident
host    replication     all             ::1/128                 ident
host    all     all     0.0.0.0/0       trust
EOF



cat << EOF > $data_dir/postgresql.conf

# -----------------------------
# PostgreSQL configuration file
# -----------------------------
#
# This file consists of lines of the form:
#
#   name = value
#
# (The "=" is optional.)  Whitespace may be used.  Comments are introduced with
# "#" anywhere on a line.  The complete list of parameter names and allowed
# values can be found in the PostgreSQL documentation.
#
# The commented-out settings shown in this file represent the default values.
# Re-commenting a setting is NOT sufficient to revert it to the default value;
# you need to reload the server.
#
# This file is read on server startup and when the server receives a SIGHUP
# signal.  If you edit the file on a running system, you have to SIGHUP the
# server for the changes to take effect, run "pg_ctl reload", or execute
# "SELECT pg_reload_conf()".  Some parameters, which are marked below,
# require a server shutdown and restart to take effect.
#
# Any parameter can also be given as a command-line option to the server, e.g.,
# "postgres -c log_connections=on".  Some parameters can be changed at run time
# with the "SET" SQL command.
#
# Memory units:  B  = bytes            Time units:  us  = microseconds
#                kB = kilobytes                     ms  = milliseconds
#                MB = megabytes                     s   = seconds
#                GB = gigabytes                     min = minutes
#                TB = terabytes                     h   = hours
#                                                   d   = days


#------------------------------------------------------------------------------
# FILE LOCATIONS
#------------------------------------------------------------------------------

# The default values of these variables are driven from the -D command-line
# option or PGDATA environment variable, represented here as ConfigDir.

#data_directory = 'ConfigDir'           # use data in another directory
                                        # (change requires restart)
#hba_file = 'ConfigDir/pg_hba.conf'     # host-based authentication file
                                        # (change requires restart)
#ident_file = 'ConfigDir/pg_ident.conf' # ident configuration file
                                        # (change requires restart)

# If external_pid_file is not explicitly set, no extra PID file is written.
#external_pid_file = ''                 # write an extra PID file
                                        # (change requires restart)


#------------------------------------------------------------------------------
# CONNECTIONS AND AUTHENTICATION
#------------------------------------------------------------------------------

# - Connection Settings -

listen_addresses = '*'          # what IP address(es) to listen on;
                                        # comma-separated list of addresses;
                                        # defaults to 'localhost'; use '*' for all
                                        # (change requires restart)
port = 5444                             # (change requires restart)
#max_connections = 100                  # (change requires restart)
#superuser_reserved_connections = 3     # (change requires restart)
#unix_socket_directories = '/tmp'       # comma-separated list of directories
                                        # (change requires restart)
#unix_socket_group = ''                 # (change requires restart)
#unix_socket_permissions = 0777         # begin with 0 to use octal notation
                                        # (change requires restart)
#bonjour = off                          # advertise server via Bonjour
                                        # (change requires restart)
#bonjour_name = ''                      # defaults to the computer name
                                        # (change requires restart)

# - TCP settings -
# see "man tcp" for details

#tcp_keepalives_idle = 0                # TCP_KEEPIDLE, in seconds;
                                        # 0 selects the system default
#tcp_keepalives_interval = 0            # TCP_KEEPINTVL, in seconds;
                                        # 0 selects the system default
#tcp_keepalives_count = 0               # TCP_KEEPCNT;
                                        # 0 selects the system default
#tcp_user_timeout = 0                   # TCP_USER_TIMEOUT, in milliseconds;
                                        # 0 selects the system default

#client_connection_check_interval = 0   # time between checks for client
                                        # disconnection while running queries;
                                        # 0 for never

# - Authentication -

#authentication_timeout = 1min          # 1s-600s
#password_encryption = scram-sha-256    # scram-sha-256 or md5
#db_user_namespace = off

# GSSAPI using Kerberos
#krb_server_keyfile = 'FILE:\${sysconfdir}/krb5.keytab'
#krb_caseins_users = off

# - SSL -

#ssl = off
#ssl_ca_file = ''
#ssl_cert_file = 'server.crt'
#ssl_crl_file = ''
#ssl_crl_dir = ''
#ssl_key_file = 'server.key'
#ssl_ciphers = 'HIGH:MEDIUM:+3DES:!aNULL' # allowed SSL ciphers
#ssl_prefer_server_ciphers = on
#ssl_ecdh_curve = 'prime256v1'
#ssl_min_protocol_version = 'TLSv1.2'
#ssl_max_protocol_version = ''
#ssl_dh_params_file = ''
#ssl_passphrase_command = ''
#ssl_passphrase_command_supports_reload = off


#------------------------------------------------------------------------------
# RESOURCE USAGE (except WAL)
#------------------------------------------------------------------------------

# - Memory -

#shared_buffers = 128MB                 # min 128kB
                                        # (change requires restart)
#huge_pages = try                       # on, off, or try
                                        # (change requires restart)
#huge_page_size = 0                     # zero for system default
                                        # (change requires restart)
#temp_buffers = 8MB                     # min 800kB
#max_prepared_transactions = 0          # zero disables the feature
                                        # (change requires restart)
# Caution: it is not advisable to set max_prepared_transactions nonzero unless
# you actively intend to use prepared transactions.
#work_mem = 4MB                         # min 64kB
#hash_mem_multiplier = 1.0              # 1-1000.0 multiplier on hash table work_mem
#maintenance_work_mem = 64MB            # min 1MB
#autovacuum_work_mem = -1               # min 1MB, or -1 to use maintenance_work_mem
#logical_decoding_work_mem = 64MB       # min 64kB
#max_stack_depth = 2MB                  # min 100kB
#shared_memory_type = mmap              # the default is the first option
                                        # supported by the operating system:
                                        #   mmap
                                        #   sysv
                                        #   windows
                                        # (change requires restart)
dynamic_shared_memory_type = posix      # the default is the first option
                                        # supported by the operating system:
                                        #   posix
                                        #   sysv
                                        #   windows
                                        #   mmap
                                        # (change requires restart)
#min_dynamic_shared_memory = 0MB        # (change requires restart)

# - Disk -

#temp_file_limit = -1                   # limits per-process temp file space
                                        # in kilobytes, or -1 for no limit

# - Kernel Resources -

#max_files_per_process = 1000           # min 64
                                        # (change requires restart)

# - Cost-Based Vacuum Delay -

#vacuum_cost_delay = 0                  # 0-100 milliseconds (0 disables)
#vacuum_cost_page_hit = 1               # 0-10000 credits
#vacuum_cost_page_miss = 2              # 0-10000 credits
#vacuum_cost_page_dirty = 20            # 0-10000 credits
#vacuum_cost_limit = 200                # 1-10000 credits

# - Background Writer -

#bgwriter_delay = 200ms                 # 10-10000ms between rounds
#bgwriter_lru_maxpages = 100            # max buffers written/round, 0 disables
#bgwriter_lru_multiplier = 2.0          # 0-10.0 multiplier on buffers scanned/round
#bgwriter_flush_after = 512kB           # measured in pages, 0 disables

# - Asynchronous Behavior -

#backend_flush_after = 0                # measured in pages, 0 disables
#effective_io_concurrency = 1           # 1-1000; 0 disables prefetching
#maintenance_io_concurrency = 10        # 1-1000; 0 disables prefetching
#max_worker_processes = 8               # (change requires restart)
#max_parallel_workers_per_gather = 2    # taken from max_parallel_workers
#max_parallel_maintenance_workers = 2   # taken from max_parallel_workers
#max_parallel_workers = 8               # maximum number of max_worker_processes that
                                        # can be used in parallel operations
#parallel_leader_participation = on
#old_snapshot_threshold = -1            # 1min-60d; -1 disables; 0 is immediate
                                        # (change requires restart)

# - EDB Resource Manager -
#edb_max_resource_groups = 16           # 0-65536; (change requires restart)
#edb_resource_group = ''


#------------------------------------------------------------------------------
# WRITE-AHEAD LOG
#------------------------------------------------------------------------------

# - Settings -

#wal_level = replica                    # minimal, replica, or logical
                                        # (change requires restart)
#fsync = on                             # flush data to disk for crash safety
                                        # (turning this off can cause
                                        # unrecoverable data corruption)
#synchronous_commit = on                # synchronization level;
                                        # off, local, remote_write, remote_apply, or on
#wal_sync_method = fsync                # the default is the first option
                                        # supported by the operating system:
                                        #   open_datasync
                                        #   fdatasync (default on Linux and FreeBSD)
                                        #   fsync
                                        #   fsync_writethrough
                                        #   open_sync
#full_page_writes = on                  # recover from partial page writes
#wal_log_hints = off                    # also do full page writes of non-critical updates
                                        # (change requires restart)
#wal_compression = off                  # enable compression of full-page writes
#wal_init_zero = on                     # zero-fill new WAL files
#wal_recycle = on                       # recycle WAL files
#wal_buffers = -1                       # min 32kB, -1 sets based on shared_buffers
                                        # (change requires restart)
#wal_writer_delay = 200ms               # 1-10000 milliseconds
#wal_writer_flush_after = 1MB           # measured in pages, 0 disables
#wal_skip_threshold = 2MB

#commit_delay = 0                       # range 0-100000, in microseconds
#commit_siblings = 5                    # range 1-1000

# - Checkpoints -

#checkpoint_timeout = 5min              # range 30s-1d
#checkpoint_completion_target = 0.9     # checkpoint target duration, 0.0 - 1.0
#checkpoint_flush_after = 256kB         # measured in pages, 0 disables
#checkpoint_warning = 30s               # 0 disables
max_wal_size = 60GB
##min_wal_size = 80MB

# - Archiving -

#archive_mode = off             # enables archiving; off, on, or always
                                # (change requires restart)
#archive_command = ''           # command to use to archive a logfile segment
                                # placeholders: %p = path of file to archive
                                #               %f = file name only
                                # e.g. 'test ! -f /mnt/server/archivedir/%f && cp %p /mnt/server/archivedir/%f'
#archive_timeout = 0            # force a logfile segment switch after this
                                # number of seconds; 0 disables

# - Archive Recovery -

# These are only used in recovery mode.

#restore_command = ''           # command to use to restore an archived logfile segment
                                # placeholders: %p = path of file to restore
                                #               %f = file name only
                                # e.g. 'cp /mnt/server/archivedir/%f %p'
#archive_cleanup_command = ''   # command to execute at every restartpoint
#recovery_end_command = ''      # command to execute at completion of recovery

# - Recovery Target -

# Set these only when performing a targeted recovery.

#recovery_target = ''           # 'immediate' to end recovery as soon as a
                                # consistent state is reached
                                # (change requires restart)
#recovery_target_name = ''      # the named restore point to which recovery will proceed
                                # (change requires restart)
#recovery_target_time = ''      # the time stamp up to which recovery will proceed
                                # (change requires restart)
#recovery_target_xid = ''       # the transaction ID up to which recovery will proceed
                                # (change requires restart)
#recovery_target_lsn = ''       # the WAL LSN up to which recovery will proceed
                                # (change requires restart)
#recovery_target_inclusive = on # Specifies whether to stop:
                                # just after the specified recovery target (on)
                                # just before the recovery target (off)
                                # (change requires restart)
#recovery_target_timeline = 'latest'    # 'current', 'latest', or timeline ID
                                # (change requires restart)
#recovery_target_action = 'pause'       # 'pause', 'promote', 'shutdown'
                                # (change requires restart)


#------------------------------------------------------------------------------
# REPLICATION
#------------------------------------------------------------------------------

# - Sending Servers -

# Set these on the primary and on any standby that will send replication data.

#max_wal_senders = 10           # max number of walsender processes
                                # (change requires restart)
#max_replication_slots = 10     # max number of replication slots
                                # (change requires restart)
#wal_keep_size = 0              # in megabytes; 0 disables
#max_slot_wal_keep_size = -1    # in megabytes; -1 disables
#wal_sender_timeout = 60s       # in milliseconds; 0 disables
#track_commit_timestamp = off   # collect timestamp of transaction commit
                                # (change requires restart)

# - Primary Server -

# These settings are ignored on a standby server.

#synchronous_standby_names = '' # standby servers that provide sync rep
                                # method to choose sync standbys, number of sync standbys,
                                # and comma-separated list of application_name
                                # from standby(s); '*' = all
#synchronous_replication_availability = wait
#vacuum_defer_cleanup_age = 0   # number of xacts by which cleanup is delayed

# - Standby Servers -

# These settings are ignored on a primary server.

#primary_conninfo = ''                  # connection string to sending server
#primary_slot_name = ''                 # replication slot on sending server
#promote_trigger_file = ''              # file name whose presence ends recovery
#hot_standby = on                       # "off" disallows queries during recovery
                                        # (change requires restart)
#max_standby_archive_delay = 30s        # max delay before canceling queries
                                        # when reading WAL from archive;
                                        # -1 allows indefinite delay
#max_standby_streaming_delay = 30s      # max delay before canceling queries
                                        # when reading streaming WAL;
                                        # -1 allows indefinite delay
#wal_receiver_create_temp_slot = off    # create temp slot if primary_slot_name
                                        # is not set
#wal_receiver_status_interval = 10s     # send replies at least this often
                                        # 0 disables
#hot_standby_feedback = off             # send info from standby to prevent
                                        # query conflicts
#wal_receiver_timeout = 60s             # time that receiver waits for
                                        # communication from primary
                                        # in milliseconds; 0 disables
#wal_retrieve_retry_interval = 5s       # time to wait before retrying to
                                        # retrieve WAL after a failed attempt
#recovery_min_apply_delay = 0           # minimum delay for applying changes during recovery

# - Subscribers -

# These settings are ignored on a publisher.

#max_logical_replication_workers = 4    # taken from max_worker_processes
                                        # (change requires restart)
#max_sync_workers_per_subscription = 2  # taken from max_logical_replication_workers


#------------------------------------------------------------------------------
# QUERY TUNING
#------------------------------------------------------------------------------

# - Planner Method Configuration -

#enable_async_append = on
#enable_bitmapscan = on
#enable_gathermerge = on
#enable_hashagg = on
#enable_hashjoin = on
#enable_incremental_sort = on
#enable_indexscan = on
#enable_indexonlyscan = on
#enable_material = on
#enable_memoize = on
#enable_mergejoin = on
#enable_nestloop = on
#enable_parallel_append = on
#enable_parallel_hash = on
#enable_partition_pruning = on
#enable_partitionwise_join = off
#enable_partitionwise_aggregate = off
#enable_seqscan = on
#enable_sort = on
#enable_tidscan = on
#enable_hints = on                      # enable optimizer hints in SQL statements.
#edb_enable_pruning = on        # fast pruning for EDB-partitioned tables

# - Planner Cost Constants -

#seq_page_cost = 1.0                    # measured on an arbitrary scale
#random_page_cost = 4.0                 # same scale as above
#cpu_tuple_cost = 0.01                  # same scale as above
#cpu_index_tuple_cost = 0.005           # same scale as above
#cpu_operator_cost = 0.0025             # same scale as above
#parallel_setup_cost = 1000.0   # same scale as above
#parallel_tuple_cost = 0.1              # same scale as above
#min_parallel_table_scan_size = 8MB
#min_parallel_index_scan_size = 512kB
#effective_cache_size = 4GB

#jit_above_cost = 100000                # perform JIT compilation if available
                                        # and query more expensive than this;
                                        # -1 disables
#jit_inline_above_cost = 500000         # inline small functions if query is
                                        # more expensive than this; -1 disables
#jit_optimize_above_cost = 500000       # use expensive JIT optimizations if
                                        # query is more expensive than this;
                                        # -1 disables

# - Genetic Query Optimizer -

#geqo = on
#geqo_threshold = 12
#geqo_effort = 5                        # range 1-10
#geqo_pool_size = 0                     # selects default based on effort
#geqo_generations = 0                   # selects default based on effort
#geqo_selection_bias = 2.0              # range 1.5-2.0
#geqo_seed = 0.0                        # range 0.0-1.0

# - Other Planner Options -

#default_statistics_target = 100        # range 1-10000
#constraint_exclusion = partition       # on, off, or partition
#cursor_tuple_fraction = 0.1            # range 0.0-1.0
#from_collapse_limit = 8
#jit = on                               # allow JIT compilation
#join_collapse_limit = 8                # 1 disables collapsing of explicit
                                        # JOIN clauses
#plan_cache_mode = auto                 # auto, force_generic_plan or
                                        # force_custom_plan


#------------------------------------------------------------------------------
# REPORTING AND LOGGING
#------------------------------------------------------------------------------

# - Where to Log -

log_destination = 'stderr'              # Valid values are combinations of
                                        # stderr, csvlog, syslog, and eventlog,
                                        # depending on platform.  csvlog
                                        # requires logging_collector to be on.

# This is used when logging to stderr:
logging_collector = on          # Enable capturing of stderr and csvlog
                                        # into log files. Required to be on for
                                        # csvlogs.
                                        # (change requires restart)

# These are only used if logging_collector is on:
#log_directory = 'log'                  # directory where log files are written,
                                        # can be absolute or relative to PGDATA
#log_filename = 'edb-%Y-%m-%d_%H%M%S.log'       # log file name pattern,
                                        # can include strftime() escapes
#log_file_mode = 0600                   # creation mode for log files,
                                        # begin with 0 to use octal notation
#log_rotation_age = 1d                  # Automatic rotation of logfiles will
                                        # happen after that time.  0 disables.
#log_rotation_size = 10MB               # Automatic rotation of logfiles will
                                        # happen after that much log output.
                                        # 0 disables.
#log_truncate_on_rotation = off         # If on, an existing log file with the
                                        # same name as the new log file will be
                                        # truncated rather than appended to.
                                        # But such truncation only occurs on
                                        # time-driven rotation, not on restarts
                                        # or size-driven rotation.  Default is
                                        # off, meaning append to existing files
                                        # in all cases.

# These are relevant when logging to syslog:
#syslog_facility = 'LOCAL0'
#syslog_ident = 'postgres'
#syslog_sequence_numbers = on
#syslog_split_messages = on

# This is only relevant when logging to eventlog (Windows):
# (change requires restart)
#event_source = 'EnterpriseDB'

# - When to Log -

#log_min_messages = warning             # values in order of decreasing detail:
                                        #   debug5
                                        #   debug4
                                        #   debug3
                                        #   debug2
                                        #   debug1
                                        #   info
                                        #   notice
                                        #   warning
                                        #   error
                                        #   log
                                        #   fatal
                                        #   panic

#log_min_error_statement = error        # values in order of decreasing detail:
                                        #   debug5
                                        #   debug4
                                        #   debug3
                                        #   debug2
                                        #   debug1
                                        #   info
                                        #   notice
                                        #   warning
                                        #   error
                                        #   log
                                        #   fatal
                                        #   panic (effectively off)

#log_min_duration_statement = -1        # -1 is disabled, 0 logs all statements
                                        # and their durations, > 0 logs only
                                        # statements running at least this number
                                        # of milliseconds

#log_min_duration_sample = -1           # -1 is disabled, 0 logs a sample of statements
                                        # and their durations, > 0 logs only a sample of
                                        # statements running at least this number
                                        # of milliseconds;
                                        # sample fraction is determined by log_statement_sample_rate

#log_statement_sample_rate = 1.0        # fraction of logged statements exceeding
                                        # log_min_duration_sample to be logged;
                                        # 1.0 logs all such statements, 0.0 never logs


#log_transaction_sample_rate = 0.0      # fraction of transactions whose statements
                                        # are logged regardless of their duration; 1.0 logs all
                                        # statements from all transactions, 0.0 never logs

# - What to Log -

#debug_print_parse = off
#debug_print_rewritten = off
#debug_print_plan = off
#debug_pretty_print = on
#log_autovacuum_min_duration = -1       # log autovacuum activity;
                                        # -1 disables, 0 logs all actions and
                                        # their durations, > 0 logs only
                                        # actions running at least this number
                                        # of milliseconds.
#log_checkpoints = off
#log_connections = off
#log_disconnections = off
#log_duration = off
#log_error_verbosity = default          # terse, default, or verbose messages
#log_hostname = off
log_line_prefix = '%t '                 # Use '%t ' to enable log-reading
                                        # features in PEM and pgAdmin
                                        # special values:
                                        #   %a = application name
                                        #   %u = user name
                                        #   %d = database name
                                        #   %r = remote host and port
                                        #   %h = remote host
                                        #   %b = backend type
                                        #   %p = process ID
                                        #   %P = process ID of parallel group leader
                                        #   %t = timestamp without milliseconds
                                        #   %m = timestamp with milliseconds
                                        #   %n = timestamp with milliseconds (as a Unix epoch)
                                        #   %Q = query ID (0 if none or not computed)
                                        #   %i = command tag
                                        #   %e = SQL state
                                        #   %c = session ID
                                        #   %l = session line number
                                        #   %s = session start timestamp
                                        #   %v = virtual transaction ID
                                        #   %x = transaction ID (0 if none)
                                        #   %q = stop here in non-session
                                        #        processes
                                        #   %% = '%'
                                        # e.g. '<%u%%%d> '
#log_lock_waits = off                   # log lock waits >= deadlock_timeout
#log_recovery_conflict_waits = off      # log standby recovery conflict waits
                                        # >= deadlock_timeout
#log_parameter_max_length = -1          # when logging statements, limit logged
                                        # bind-parameter values to N bytes;
                                        # -1 means print in full, 0 disables
#log_parameter_max_length_on_error = 0  # when logging an error, limit logged
                                        # bind-parameter values to N bytes;
                                        # -1 means print in full, 0 disables
#log_statement = 'none'                 # none, ddl, mod, all
#log_replication_commands = off
#log_temp_files = -1                    # log temporary files equal or larger
                                        # than the specified size in kilobytes;
                                        # -1 disables, 0 logs all temp files
log_timezone = 'UTC'


#------------------------------------------------------------------------------
# PROCESS TITLE
#------------------------------------------------------------------------------

#cluster_name = ''                      # added to process titles if nonempty
                                        # (change requires restart)
#update_process_title = on

#utl_http.debug = off           # trace network conversations

#---------------------------------------------------------------------------
# EDB AUDIT
#---------------------------------------------------------------------------

#edb_audit = 'none'                     # none, csv or xml

# These are only used if edb_audit is not none:
#edb_audit_directory = 'edb_audit'      # Directory where log files are written
                                        # Can be absolute or relative to PGDATA

#edb_audit_filename = 'audit-%Y-%m-%d_%H%M%S' # Audit file name pattern.
                                        # Can include strftime() escapes

#edb_audit_rotation_day = 'every'       # Automatic rotation of logfiles based
                                        # on day of week. none, every, sun,
                                        # mon, tue, wed, thu, fri, sat

#edb_audit_rotation_size = 0            # Automatic rotation of logfiles will
                                        # happen after this many megabytes (MB)
                                        # of log output.  0 to disable.

#edb_audit_rotation_seconds = 0         # Automatic log file rotation will
                                        # happen after this many seconds.

#edb_audit_connect = 'failed'           # none, failed, all
#edb_audit_disconnect = 'none'          # none, all
#edb_audit_statement = 'ddl, error'     # Statement type to be audited:
                                        # none, dml, insert, update, delete, truncate,
                                        # select, error, rollback, ddl, create, drop,
                                        # alter, grant, revoke, set, all
                                        # {SELECT | UPDATE | DELETE | INSERT}@groupname
#edb_audit_tag = ''                     # Audit log session tracking tag.
#edb_log_every_bulk_value = off     # Writes every set of bulk operation
                                        # parameter values during logging.
                                        # This GUC applies to both EDB AUDIT and PG LOGGING.
#edb_audit_destination = 'file'         # file or syslog

#------------------------------------------------------------------------------
# EDB AUDIT ARCHIVER:
#------------------------------------------------------------------------------

#edb_audit_archiver = 'off'                             # Enable audit log archiver process,
                                                        # the size of the audit log directory
                                                        # & audit log files can be managed by
                                                        # using the below gucs.
                                                        # (change requires restart)

# These are only used if edb_audit_archiver is on:
#edb_audit_archiver_timeout = '300s'                    # Audit log archiver will check the
                                                        # audit log files based on this guc.
                                                        # range 30s-1d
#edb_audit_archiver_filename_prefix = 'audit-'          # Files with this prefix in
                                                        # edb_audit_directory are eligible
                                                        # for compression and/or expiration;
                                                        # Needs to align with edb_audit_filename.
#edb_audit_archiver_compress_time_limit = -1            # Time in seconds after which audit logs
                                                        # are eligible for compression; 0 = as
                                                        # soon as it's not the current file,
                                                        # -1 = never.
#edb_audit_archiver_compress_size_limit = -1            # Total size in megabytes after which
                                                        # audit logs are eligible for compression;
                                                        # 0 = as soon as it's not the current file,
                                                        # -1 = never.
#edb_audit_archiver_compress_command = 'gzip %p'        # Compression command for compressing
                                                        # the audit log files.
#edb_audit_archiver_compress_suffix = '.gz'             # Suffix for an already compressed log
                                                        # file; Needs to align with
                                                        # edb_audit_archiver_compress_command.
#edb_audit_archiver_expire_time_limit = -1              # Time in seconds after which audit logs
                                                        # are eligible for expiration; 0 = as
                                                        # soon as it's not the current file,
                                                        # -1 = never.
#edb_audit_archiver_expire_size_limit = -1              # Total size in megabytes after which
                                                        # audit logs are eligible for expiration;
                                                        # 0 = as soon as it's not the current file,
                                                        # -1 = never.
#edb_audit_archiver_expire_command = ''                 # Command to execute on an expired audit
                                                        # log before removing it.
#edb_audit_archiver_sort_file = 'mtime'                 # To identify the oldest file, the files
                                                        # will be sorted alphabetically or based
                                                        # on mtime. mtime = sort based on file
                                                        # modification time, alphabetic = sort
                                                        # alphabetically based on file name.

#------------------------------------------------------------------------------
# STATISTICS
#------------------------------------------------------------------------------

# - Query and Index Statistics Collector -

#track_activities = on
#track_activity_query_size = 1024       # (change requires restart)
#track_counts = on
#track_io_timing = off
#track_wal_io_timing = off
#track_functions = none                 # none, pl, all
#stats_temp_directory = 'pg_stat_tmp'


# - Monitoring -

#compute_query_id = auto
#log_statement_stats = off
#log_parser_stats = off
#log_planner_stats = off
#log_executor_stats = off


#------------------------------------------------------------------------------
# AUTOVACUUM
#------------------------------------------------------------------------------

#autovacuum = on                        # Enable autovacuum subprocess?  'on'
                                        # requires track_counts to also be on.
#autovacuum_max_workers = 3             # max number of autovacuum subprocesses
                                        # (change requires restart)
#autovacuum_naptime = 1min              # time between autovacuum runs
#autovacuum_vacuum_threshold = 50       # min number of row updates before
                                        # vacuum
#autovacuum_vacuum_insert_threshold = 1000      # min number of row inserts
                                        # before vacuum; -1 disables insert
                                        # vacuums
#autovacuum_analyze_threshold = 50      # min number of row updates before
                                        # analyze
#autovacuum_vacuum_scale_factor = 0.2   # fraction of table size before vacuum
#autovacuum_vacuum_insert_scale_factor = 0.2    # fraction of inserts over table
                                        # size before insert vacuum
#autovacuum_analyze_scale_factor = 0.1  # fraction of table size before analyze
#autovacuum_freeze_max_age = 200000000  # maximum XID age before forced vacuum
                                        # (change requires restart)
#autovacuum_multixact_freeze_max_age = 400000000        # maximum multixact age
                                        # before forced vacuum
                                        # (change requires restart)
#autovacuum_vacuum_cost_delay = 2ms     # default vacuum cost delay for
                                        # autovacuum, in milliseconds;
                                        # -1 means use vacuum_cost_delay
#autovacuum_vacuum_cost_limit = -1      # default vacuum cost limit for
                                        # autovacuum, -1 means use
                                        # vacuum_cost_limit


#------------------------------------------------------------------------------
# CLIENT CONNECTION DEFAULTS
#------------------------------------------------------------------------------

# - Statement Behavior -

#client_min_messages = notice           # values in order of decreasing detail:
                                        #   debug5
                                        #   debug4
                                        #   debug3
                                        #   debug2
                                        #   debug1
                                        #   log
                                        #   notice
                                        #   warning
                                        #   error
#search_path = '"\$user", public'        # schema names
#row_security = on
#default_table_access_method = 'heap'
#default_tablespace = ''                # a tablespace name, '' uses the default
#default_toast_compression = 'pglz'     # 'pglz' or 'lz4'
#temp_tablespaces = ''                  # a list of tablespace names, '' uses
                                        # only default tablespace
#check_function_bodies = on
#default_transaction_isolation = 'read committed'
#default_transaction_read_only = off
#default_transaction_deferrable = off
#session_replication_role = 'origin'
#statement_timeout = 0                  # in milliseconds, 0 is disabled
#lock_timeout = 0                       # in milliseconds, 0 is disabled
#idle_in_transaction_session_timeout = 0        # in milliseconds, 0 is disabled
#idle_session_timeout = 0               # in milliseconds, 0 is disabled
#vacuum_freeze_table_age = 150000000
#vacuum_freeze_min_age = 50000000
#vacuum_failsafe_age = 1600000000
#vacuum_multixact_freeze_table_age = 150000000
#vacuum_multixact_freeze_min_age = 5000000
#vacuum_multixact_failsafe_age = 1600000000
#bytea_output = 'hex'                   # hex, escape
#xmlbinary = 'base64'
#xmloption = 'content'
#gin_pending_list_limit = 4MB

# - Locale and Formatting -

#datestyle = 'iso, mdy'                 # PostgreSQL default for your locale
datestyle = 'redwood,show_time'
#intervalstyle = 'postgres'
timezone = 'UTC'
#timezone_abbreviations = 'Default'     # Select the set of available time zone
                                        # abbreviations.  Currently, there are
                                        #   Default
                                        #   Australia (historical usage)
                                        #   India
                                        # You can create your own file in
                                        # share/timezonesets/.
#extra_float_digits = 1                 # min -15, max 3; any value >0 actually
                                        # selects precise output mode
#client_encoding = sql_ascii            # actually, defaults to database
                                        # encoding

# These settings are initialized by initdb, but they can be changed.
lc_messages = 'en_US.UTF-8'                     # locale for system error message
                                        # strings
lc_monetary = 'en_US.UTF-8'                     # locale for monetary formatting
lc_numeric = 'en_US.UTF-8'                      # locale for number formatting
lc_time = 'en_US.UTF-8'                         # locale for time formatting

# default configuration for text search
default_text_search_config = 'pg_catalog.english'

# - Shared Library Preloading -

#local_preload_libraries = ''
#session_preload_libraries = ''
shared_preload_libraries = '\$libdir/dbms_pipe,\$libdir/edb_gen,\$libdir/dbms_aq'
                                        # (change requires restart)
#jit_provider = 'llvmjit'               # JIT library to use

# - Other Defaults -

#dynamic_library_path = '\$libdir'

#oracle_home =''        # path to the Oracle home directory;
                                        # only used by OCI Dblink; defaults
                                        # to ORACLE_HOME environment variable.
                                        # (change requires restart)
#gin_fuzzy_search_limit = 0


#------------------------------------------------------------------------------
# LOCK MANAGEMENT
#------------------------------------------------------------------------------

#deadlock_timeout = 1s
#max_locks_per_transaction = 64         # min 10
                                        # (change requires restart)
#max_pred_locks_per_transaction = 64    # min 10
                                        # (change requires restart)
#max_pred_locks_per_relation = -2       # negative values mean
                                        # (max_pred_locks_per_transaction
                                        #  / -max_pred_locks_per_relation) - 1
#max_pred_locks_per_page = 2            # min 0


#------------------------------------------------------------------------------
# VERSION AND PLATFORM COMPATIBILITY
#------------------------------------------------------------------------------

# - Previous PostgreSQL Versions -

#array_nulls = on
#backslash_quote = safe_encoding        # on, off, or safe_encoding
#escape_string_warning = on
#lo_compat_privileges = off
#quote_all_identifiers = off
#standard_conforming_strings = on
#synchronize_seqscans = on

# - Other Platforms and Clients -

#transform_null_equals = off

# - Oracle compatibility -

#default_with_rowids = off
edb_redwood_date = on                   # translate DATE to TIMESTAMP
edb_redwood_greatest_least = on # GREATEST/LEAST are strict
edb_redwood_strings = on                # treat NULL as an empty string in
                                        # string concatenation
#edb_redwood_raw_names = off    # don't uppercase/quote names in sys views
#edb_stmt_level_tx = off                # allow continuing on errors instead
                                        # rolling back
db_dialect = 'redwood'                  # Sets the precedence of built-in
                                        # namespaces.
                                        # 'redwood' means sys, pg_catalog
                                        # 'postgres' means pg_catalog, sys
#optimizer_mode = choose                # Oracle-style optimizer hints.
                                        # choose, all_rows, first_rows,
                                        # first_rows_10, first_rows_100 or
                                        # first_rows_1000
#edb_early_lock_release = off   # release locks for prepared statements
                                        # when the portal is closed
#edb_data_redaction = on                # enable data redaction

#------------------------------------------------------------------------------
# ERROR HANDLING
#------------------------------------------------------------------------------

#exit_on_error = off                    # terminate session on any error?
#restart_after_crash = on               # reinitialize after backend crash?
#data_sync_retry = off                  # retry or panic on failure to fsync
                                        # data?
                                        # (change requires restart)
#recovery_init_sync_method = fsync      # fsync, syncfs (Linux 5.8+)


#------------------------------------------------------------------------------
# CONFIG FILE INCLUDES
#------------------------------------------------------------------------------

# These options allow settings to be loaded from files other than the
# default postgresql.conf.  Note that these are directives, not variable
# assignments, so they can usefully be given more than once.

#include_dir = '...'                    # include files ending in '.conf' from
                                        # a directory, e.g., 'conf.d'
#include_if_exists = '...'              # include file only if it exists
#include = '...'                        # include file


#------------------------------------------------------------------------------
# CUSTOMIZED OPTIONS
#------------------------------------------------------------------------------

#dbms_pipe.total_message_buffer = 30kB  # default: 30KB, max: 256MB, min: 30KB
                                        # (change requires restart)
#dbms_alert.max_alerts = 100            # default 100, max: 500, min: 0
                                        # (change requires restart)

#---------------------------------------------------------------------------
# DYNA-TUNE
#---------------------------------------------------------------------------

edb_dynatune = 66                       # percentage of server resources
                                        # dedicated to database server,
                                        # defaults to 66
                                        # (change requires restart)
edb_dynatune_profile = oltp             # workload profile for tuning.
                                        # oltp, reporting or mixed
                                        # (change requires restart)

#---------------------------------------------------------------------------
# QREPLACE
#---------------------------------------------------------------------------

#qreplace_function = ''                 # function used by Query Replace.

#---------------------------------------------------------------------------
# RUNTIME INSTRUMENTATION AND TRACING
#---------------------------------------------------------------------------

timed_statistics = off                  # record wait timings, defaults to on

# Add settings for extensions here
listen_addresses = '*'
port = 5444
max_connections = 3000
shared_buffers = 10GB
temp_buffers = 1024
work_mem = 96MB
maintenance_work_mem = 1GB
effective_cache_size= 30GB
effective_io_concurrency = 500
max_parallel_maintenance_workers = 6
max_parallel_workers = 10
max_parallel_workers_per_gather = 6
max_worker_processes = 10
dynamic_shared_memory_type = posix
huge_pages = 'on'
idle_in_transaction_session_timeout = '30min'
max_stack_depth = '2MB'
shared_preload_libraries = '\$libdir/dbms_pipe,\$libdir/edb_gen,\$libdir/dbms_aq,pg_stat_statements'
pg_stat_statements.max = 10000
pg_stat_statements.track = all
jit = off
jit_above_cost = 50000
jit_inline_above_cost = 100000
jit_optimize_above_cost = 100000
bgwriter_delay = 50ms
bgwriter_lru_maxpages = 5000
bgwriter_lru_multiplier = 5
fsync = on
wal_buffers = 128MB
synchronous_commit = local
checkpoint_timeout = 15min
checkpoint_warning = 1min
#max_wal_size = 10GB
min_wal_size = 30GB
checkpoint_completion_target = 0.9
random_page_cost = 1.1
wal_sync_method = 'fsync'
archive_mode = on
archive_command = 'cp %p /var/lib/edb/as14/data/extra_wal/%f'
hot_standby = on
wal_level = replica
archive_timeout = 0
max_wal_senders = 7
wal_keep_size=20480MB
cpu_tuple_cost = 0.03
cpu_index_tuple_cost = 0.005
default_statistics_target = 30
from_collapse_limit = 8
join_collapse_limit = 8
log_destination = 'stderr'
logging_collector = on
log_directory = 'log'
log_rotation_size = 1GB
autovacuum=on
autovacuum_work_mem = 3GB
vacuum_cost_limit = 2000
autovacuum_max_workers = 20
autovacuum_naptime = 30s
autovacuum_vacuum_cost_delay = 10ms
autovacuum_vacuum_cost_limit = 10000
autovacuum_vacuum_threshold = 2000
autovacuum_analyze_threshold = 10000
autovacuum_vacuum_scale_factor = 0
autovacuum_analyze_scale_factor = 0.02
##datestyle = 'redwood,show_time'
edb_dynatune = 100
edb_dynatune_profile = mixed
timed_statistics = on
log_line_prefix = '%t [%p]: user=%u,db=%d,app=%a,client=%h'
log_checkpoints = on
log_connections = on
log_min_duration_statement = 10000

wal_recycle = off
wal_init_zero = off

EOF


systemctl status $service_name

# Starting the Database
systemctl start $service_name

systemctl enable $service_name

systemctl status $service_name


psqlrcFile="/var/lib/edb/.psqlrc"

if [[ ! -f $psqlrcFile ]]
then
  touch $psqlrcFile
  echo "\echo '' "                                                       >> $psqlrcFile
  echo "\echo '    __| _ \\ _ )   ' "                                    >> $psqlrcFile
  echo "\echo '    _|  |  |_ \\   EDB Postgres Advanced Server ' "       >> $psqlrcFile
  echo "\echo '   ___|___/___/    ' "                                    >> $psqlrcFile
  echo "\echo '' "                                                       >> $psqlrcFile
  echo " "                                                               >> $psqlrcFile
  echo "\set QUIET 1 "                                                   >> $psqlrcFile
  echo " "                                                               >> $psqlrcFile
  echo "\set PROMPT1 '%M:%[%033[1;31m%]%>%[%033[0m%] %n@%/%R%#%x ' "     >> $psqlrcFile
  echo " "                                                               >> $psqlrcFile
  echo "\set PROMPT2 '%M %n@%/%R %# ' "                                  >> $psqlrcFile
  echo " "                                                               >> $psqlrcFile
  echo "\pset null '[null]' "                                            >> $psqlrcFile
  echo " "                                                               >> $psqlrcFile
  echo "\set COMP_KEYWORD_CASE upper "                                   >> $psqlrcFile
  echo " "                                                               >> $psqlrcFile
  echo "\timing "                                                        >> $psqlrcFile
  echo " "                                                               >> $psqlrcFile
  echo "\set HISTSIZE 2000 "                                             >> $psqlrcFile
  echo "\set AUTOCOMMIT on "                                             >> $psqlrcFile
  echo "\setenv PAGER 'less -S' "                                        >> $psqlrcFile
  echo "\x auto "                                                        >> $psqlrcFile
  echo " "                                                               >> $psqlrcFile
  echo "\set VERBOSITY verbose "                                         >> $psqlrcFile
  echo " "                                                               >> $psqlrcFile
  echo "\set QUIET 0 "                                                   >> $psqlrcFile
  echo " "                                                               >> $psqlrcFile
  echo "\echo 'Type :version to see the PostgreSQL version. \n' "        >> $psqlrcFile
  echo "\echo 'Type :extensions to see the available extensions. \n' "   >> $psqlrcFile
  echo "\echo 'Type \\q to exit. \n' "                                   >> $psqlrcFile
  echo "\set version 'SELECT version();' "                               >> $psqlrcFile
  echo "\set extensions 'select * from pg_available_extensions;' "       >> $psqlrcFile
  chown enterprisedb:enterprisedb $psqlrcFile
fi


# Creating the database
echo "Creating the database "
echo "Give the name of the database and the schema to be created: "
read -p "database name: " database_name

psql -U enterprisedb -d postgres << EOF 
CREATE ROLE $database_name WITH LOGIN PASSWORD '$database_name' SUPERUSER CREATEROLE CREATEDB REPLICATION;
set role $database_name;
DROP DATABASE IF EXISTS $database_name;
CREATE DATABASE $database_name OWNER $database_name ENCODING 'UTF8' LC_COLLATE = 'en_US.UTF-8' LC_CTYPE = 'en_US.UTF-8' TEMPLATE template0;
\connect $database_name
CREATE SCHEMA $database_name AUTHORIZATION $database_name;
GRANT ALL PRIVILEGES ON SCHEMA $database_name TO $database_name WITH GRANT OPTION;
COMMIT;
\connect edb
\l
\q
EOF

# If last command succeeded, then show message
if [ $? -eq 0 ]; then
  echo ""
  echo ""
  echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
  echo -e "${GREEN}EDB Advanced Server has been installed and started successfully!!!!!!!${NC}"
  echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
  echo ""
  echo ""
fi




