#!/usr/bin/env perl


#----------------------------- Change Logs -------------------------------
#-----------------------------Intentional Line ---------------------------
#
#  2012-05-12 - Creation
#               List Rim to Hub attachment relationships
#  2012-05-17 - List OCR/CRSD Master
#               List OCR Local/Writer connections to local/remote ASM for Near ASM
#  2012-05-18 - List OCR Local/Writer connections to local/remote ASM for Big Cluster
#  2012-05-22 - List CRSD PE Master & CRSD PE Standby
#  2012-05-25 - Adapt to new 12c Name changes: cNodes, pNodes
#             - Make some changes due to logs like "NOTE: [ocrcheck.bin@slcc04db06.us.oracle.com (TNS V1-V3 58180] opening OCR file"
#             - List CTSS Master & UI Master & ONS Master if [-full] option is specified
#  2012-05-26 - Added: List all ASM instance and its clients per Yuanlin's requirement
#  2012-05-27 - Added [-master] option to list only Master/Standby info
#  2012-05-30 - Fixed some bugs:
#                 1. Unable to list the ASM clients, as no "xxx rows selected"
#                 2. Unable to list Rim-Hub-Relationship if all related logs are flushed out on Rim nodes
#  2012-05-31 - Fixed a bug:
#                 1. Get_ONS_Master used wrong log file
#  2012-06-14 - Added List_OCR_Rank to list latest OCR/PE related rank values from crsd.l*
#               Made CLUSTER_NODES more accurate by getting it from crsconfig_params
#  2012-06-19 - Fixed some bugs when a rim is converted to a hub
#  2012-06-20 - Modified Get_OCR_Connection function, it should use pid of crsd.bin to get OCR connection
#               Added a way to get OCR connection for rim nodes
#  2012-06-22 - Fixed some bugs for Get_OCR_Connection: wrong output if a node is dirty reset
#  2012-06-23 - Modified Get_PE_Standby: include logs like "CURRENT STANDBY SERVERS: rwsak09 rwsak10" into account
#  2012-07-01 - Modified Get_OCR_Master: include logs like "NEW OCR MASTER IS 2" into account
#  2012-07-02 - Added: List all IOS instance and its clients
#  2012-07-04 - Added: List_PE_Role_State to list latest CRSPE Role|State Update
#  2012-07-11 - Ported this script to 11.2 so Support can also use it
#  2012-07-12 - Added: List_DB_Detail to list DB's management type, db type, db home
#  2012-08-07 - Added: Get_Cluster_Mode & List_Cluster_Mode to list cluster's mode
#  2012-11-14 - Modified Get_ASM_APX_Instance to add APX instances-Node relationship
#               Added: Get_MGMTDB & List_MGMTDB to list MGMTDB is running on which node
#  2013-05-17 - Added: Get_CHM_Master & List_CHM_Master & Get_CHM_Replica & List_CHM_Replica to list CHM/IP-DOS Master & Replica
#  2013-05-31 - Added: Get_GNS & List_GNS ; Get_SCAN & List_SCAN ; Get_SCAN_listener & List_SCAN_Listener ; Get_Clustername & List_Clustername ; Get_OCR & List_OCR ; Get_VD & List_VD ; Get_ASM_DG_Disk & List_ASM_DG_Disk ; Get_ACFS_VOLUME & List_ACFS_VOLUME
#  2013-06-07 - Added: Get_Node_VIP & List_Node_VIP
#  2013-06-12 - Modified: Format Adapting so that the text output can be directly imported into a Windows Excel file
#  2013-10-21 - Modified: changed the log file names to make it works also in ADR env
#  2013-12-22 - Added: added GNS_VIP info
#  2014-06-18 - Added: added fstype info for all ORACLE_HOMEs and ORACLE_BASEs
#  03/31/2015 - For AFD label paths like AFD:XXX, appended the paths with the actual underneath disks
#  03/31/2015 - Added ONSNET Master since this master may differ from ONS Master
#  03/31/2015 - Get_OCR/Get_VD would fail on leaf nodes, correct this by ssh to hub nodes to execute these commands again
#  04/27/2015 - Added Get_MGMTLSNR & List_MGMTLSNR
#  05/11/2015 - Added NIC Subnet & NIC IP for all Public/Private/ASM NICs on all cluster nodes
#  05/12/2015 - Added Get_ASMNETLSNR & List_ASMNETLSNR
#  05/19/2015 - Added Get_Misscount & List_Misscount
#  05/28/2015 - Fixed the problem of Get_All_DB/List_DB_Detail not working on leaf nodes w/o DB_HOME
#  09/14/2015 - Fixed the problem of "oifcfg getif" outputs if "*" is used for private NIC
#
#
#  TODO       - 
#
#
#-------------------------------- End ------------------------------------




################ Documentation ################

# The SYNOPSIS section is printed out as usage when incorrect parameters are passed

=head1 NAME

  ols.pl - list Hub-Rim relationships 

=head1 SYNOPSIS

  ols.pl [-full] [-master] [-static] [-verbose] [-nocolor] [--version] [-help] 
  
  Options:

    -[full|f]            Print full info including CTSS/UI/ONS Master Nodes
    -[master|m]          Print only OCR Master, PE Master/Standby(12c only) info
    -[static|s]          Print only static info which doesn't change between GI stack restarts
    -[verbose|v]         Print verbose info including OCR/CRS Standby Rank(12c only), CRSPE Role|State Update info
    -[nocolor]           Print verbatim info, no color/bold font
    --[version]          Print current version of this script
    -[help|h|?]          Print this help info


=head1 DESCRIPTION

  This script is used to list Hub-Rim relationship, OCR Master, CRSD PE Master/Standby, CTSS/UI/ONS master, OCR connection and more.

=cut

################ End Documentation ################


use strict ;
use warnings ;
use Data::Dumper ;
use English ;
use Getopt::Long ;
use Pod::Usage ;
use POSIX qw(strftime) ;
use Sys::Hostname ;
use Term::ANSIColor qw(:constants) ;
use Time::Local ;



$ENV{'LC_ALL'}='en_US.UTF-8' ;  # set English locale forcely



our $VERSION = "2.0" ;
$| = 1 ; # flush perl's print buffer, equivalent to $OUTPUT_AUTOFLUSH = 1 ;


(getpwuid($<))[0] eq 'root' && die "ERROR: Please run the script as CRS Owner !\n" ;


# Hostname info
our $HOSTNAME = lc(hostname) ;
# If IP address, do not strip.
if ( $HOSTNAME !~ /(\d{1,3}\.){3}\d{1,3}/ )
{
  $HOSTNAME =~ s/^([^.]+)\..*/$1/ ; # strip domain name off hostname
}


# Platform info
our $PLATFORM = $^O ;


our ($AWK, $SED, $GREP, $EGREP, $ECHO, $ID, $WHOAMI, $EXPECT, $CAT, $CUT, $CP, $CHMOD, $CHOWN, $DATE, $DF, $STAT, $LS, $HEAD, $TAIL, $WC, $PSEF, $PSELF, $SSH, $SCP, $SORT, $RSH, $RCP, $RM, $SU, $SUDO, $DIFF, $UNZIP, $IFCONFIG, $NETSTAT, $TMPDIR) ;
our ($ORAINST, $OCR_LOC, $ORATAB) ;
#===================================================
# Unix Porting code here
#===================================================
if ( $PLATFORM eq "linux" ) {
  $AWK="/bin/awk" ;
  $SED="/bin/sed" ;
  $GREP="/bin/grep" ;
  $EGREP="/bin/egrep" ;
  $ECHO="/bin/echo";
  $ID="/usr/bin/id";
  $WHOAMI="/usr/bin/whoami";
  $EXPECT= "/usr/bin/expect";
  $CAT="/bin/cat";
  $CUT="/usr/bin/cut";
  $CP = "bin/cp";
  $CHMOD = "/bin/chmod";
  $CHOWN = "/bin/chown";
  $DATE="/bin/date";
  $DF = "/bin/df";
  $STAT = "/usr/bin/stat";
  $LS = "/bin/ls" ;
  $HEAD = "/usr/bin/head" ;
  $TAIL="/usr/bin/tail";
  $WC="/usr/bin/wc" ;
  $PSEF = "/bin/ps -ef" ;
  $PSELF = "/bin/ps -elf";
  $SSH = "/usr/bin/ssh";
  $SCP = "/usr/bin/scp";
  $SORT = "/bin/sort";
  $RSH = "/usr/bin/rsh";
  $RCP = "/usr/bin/rcp";
  $RM = "/bin/rm";
  $SU = "/bin/su";
  $SUDO = "/utilities/sudo/sudo";
  $DIFF = "/usr/bin/diff";
  $UNZIP = "/usr/bin/unzip";
  $IFCONFIG = "/sbin/ifconfig" ;
  $NETSTAT = "/bin/netstat" ;
  $TMPDIR = "/tmp";
  $ORAINST = "/etc/oraInst.loc";
  $OCR_LOC = "/etc/oracle/ocr.loc";
  $ORATAB = "/etc/oratab" ;
} elsif ( $PLATFORM eq "solaris" ) {
  if ( -e "/usr/xpg4/bin/awk" ) {
    $AWK="/usr/xpg4/bin/awk" ;
  } else {
    $AWK="/usr/bin/awk" ;
  }
  if ( -e "/usr/xpg4/bin/sed" ) {
    $SED="/usr/xpg4/bin/sed" ;
  } else {
    $SED="/usr/bin/sed" ;
  }
  if ( -e "/usr/xpg4/bin/grep" ) {
    $GREP="/usr/xpg4/bin/grep" ;
  } else {
    $GREP="/usr/bin/grep" ;
  }
  if ( -e "/usr/xpg4/bin/egrep" ) {
    $EGREP="/usr/xpg4/bin/egrep" ;
  } else {
    $EGREP="/usr/bin/egrep" ;
  }
  if ( -e "/usr/xpg4/bin/cat" ) {
    $CAT="/usr/xpg4/bin/cat";
  } else {
    $CAT="/usr/bin/cat";
  }
  if ( -e "/usr/xpg4/bin/cut" ) {
    $CUT="/usr/xpg4/bin/cut";
  } else {
    $CUT="/usr/bin/cut";
  }
  if ( -e "/usr/xpg4/bin/du" ) {
    $DF="/usr/xpg4/bin/df";
  } else {
    $DF="/usr/bin/df";
  }
  if ( -e "/usr/xpg4/bin/head" ) {
    $HEAD="/usr/xpg4/bin/head";
  } else {
    $HEAD="/usr/bin/head";
  }
  if ( -e "/usr/xpg4/bin/tail" ) {
    $TAIL="/usr/xpg4/bin/tail";
  } else {
    $TAIL="/usr/bin/tail";
  }
  $WC="/usr/bin/wc" ;
  $LS = "/usr/bin/ls" ;
  $CP = "/usr/bin/cp";
  $CHMOD = "/bin/chmod";
  $CHOWN = "/bin/chown";
  $DATE="/usr/bin/date";
  $ECHO="/usr/bin/echo";
  $ID="/usr/bin/id";
  $WHOAMI="/usr/ucb/whoami";
  $EXPECT= "/usr/local/bin/expect";
  $PSEF = "/usr/bin/ps -ef" ;
  $PSELF = "/usr/bin/ps -cafe";
  $STAT = "/usr/bin/stat";
  $SSH = "/usr/bin/ssh";
  $SCP = "/usr/bin/scp";
  $SORT = "/usr/bin/sort";
  $RSH = "/usr/bin/rsh";
  $RCP = "/usr/bin/rcp";
  $RM = "/usr/bin/rm";
  $SU = "/usr/bin/su";
  $SUDO = "/utilities/sudo/sudo";
  $DIFF = "/usr/bin/diff";
  $UNZIP = "/usr/bin/unzip";
  $IFCONFIG = "/sbin/ifconfig" ;
  $NETSTAT = "/usr/bin/netstat" ;
  $TMPDIR = "/tmp";
  $ORAINST = "/var/opt/oracle/oraInst.loc";
  $OCR_LOC = "/var/opt/oracle/ocr.loc";
  $ORATAB = "/var/opt/oracle/oratab" ;
} elsif ( $PLATFORM eq "aix" ) {
  $AWK="/bin/awk" ;
  $SED="/bin/sed" ;
  $GREP="/bin/grep" ;
  $EGREP="/bin/egrep" ;
  $ECHO="/bin/echo";
  $ID="/bin/id";
  $WHOAMI="/bin/whoami";
  $EXPECT= "/usr/bin/expect";
  $CAT="/bin/cat";
  $CUT="/bin/cut";
  $CP = "bin/cp";
  $CHMOD = "/bin/chmod";
  $CHOWN = "/bin/chown";
  $DATE = "/bin/date";
  $DF = "/usr/bin/df";
  $STAT = "/usr/bin/stat";
  $LS = "/usr/bin/ls" ;
  $HEAD = "/usr/bin/head" ;
  $TAIL="/usr/bin/tail";
  $WC="/usr/bin/wc" ;
  $PSEF = "/bin/ps -ef" ;
  $PSELF = "/bin/ps -elf";
  $SSH = "/bin/ssh";
  $SCP = "/bin/scp";
  $SORT = "/bin/sort";
  $RSH = "/bin/rsh";
  $RCP = "/bin/rcp";
  $RM = "/bin/rm";
  $SU = "/bin/su";
  $SUDO = "/utilities/sudo/sudo";
  $DIFF = "/bin/diff";
  $UNZIP = "/bin/unzip";
  $IFCONFIG = "/usr/sbin/ifconfig" ;
  $NETSTAT = "/usr/bin/netstat" ;
  $TMPDIR = "/tmp";
  $ORAINST = "/etc/oraInst.loc";
  $OCR_LOC = "/etc/oracle/ocr.loc";
  $ORATAB = "/etc/oratab" ;
} elsif ( $PLATFORM eq "hpux" ) {
  $AWK="/usr/bin/awk" ;
  $SED="/usr/bin/sed" ;
  $GREP="/usr/bin/grep" ;
  $EGREP="/usr/bin/egrep" ;
  $ECHO="/usr/bin/echo";
  $ID="/usr/bin/id";
  $WHOAMI="/usr/bin/whoami";
  $EXPECT= "/usr/local/bin/expect";
  $CAT="/usr/bin/cat";
  $CUT="/usr/bin/cut";
  $CP = "/usr/bin/cp";
  $CHMOD = "/bin/chmod";
  $CHOWN = "/bin/chown";
  $DATE="/bin/date";
  $DF = "/usr/bin/df";
  $STAT = "/usr/bin/stat";
  $LS = "/bin/ls" ;
  $HEAD = "/bin/head" ;
  $TAIL="/bin/tail";
  $WC="/bin/wc";
  $PSEF = "/usr/bin/ps -ef" ;
  $PSELF = "/usr/bin/ps -elf";
  $SSH = "/usr/bin/ssh";
  $SCP = "/usr/bin/scp";
  $SORT = "/usr/bin/sort";
  $RSH = "/usr/bin/remsh";
  $RCP = "/usr/bin/rcp";
  $RM = "/usr/bin/rm";
  $SU = "/usr/bin/su";
  $SUDO = "/utilities/sudo/sudo";
  $DIFF = "/usr/bin/diff";
  $UNZIP = "/usr/bin/unzip";
  $IFCONFIG = "/usr/sbin/ifconfig" ;
  $NETSTAT = "/bin/netstat" ;
  $TMPDIR = "/tmp";
  $ORAINST = "/var/opt/oracle/oraInst.loc";
  $OCR_LOC = "/var/opt/oracle/ocr.loc";
  $ORATAB = "/etc/oratab" ;
} else {
  die "Error: Unknown Operating System: $PLATFORM\n";
}



# Perl trim function to remove whitespace from the start and end of the string
sub trim
{
  my $string = shift ;
  $string =~ s/^\s+//;
  $string =~ s/\s+$//;
  return $string ;
}

# Left trim function to remove leading whitespace
sub ltrim
{
    my $string = shift ;
    $string =~ s/^\s+//;
    return $string ;
}

# Right trim function to remove trailing whitespace
sub rtrim
{
    my $string = shift ;
    $string =~ s/\s+$//;
    return $string ;
}



sub max
{
  my @tmp = sort { $b <=> $a } @_ ;
  return $tmp[0] ;
}



sub now
{
  print BOLD, BLUE, "Local Time Now :\t", RESET ;
  print strftime("%Y-%m-%d %H:%M:%S\n", localtime(time)), "\n" ;
}




# Get the file system type of a path
# ARGC: 1
# ARGV1: the file/dir path
# Return: the file system of this path on the node, "" if can't get
sub get_fs_type
{
  my ($path) = @_ ;
  my $filesystem_info = "" ;

  if ( -e $path ) {
    if ( $PLATFORM eq "linux" ) {
      chomp($filesystem_info = `$DF -T $path | $TAIL -1 | $AWK '{print \$(NF-5)}'`) ; # use this system command to get fstype, for more portable, it's best to change to use Perl functions later
    } elsif ( $PLATFORM eq "solaris" ) {
      chomp($filesystem_info = `$DF -g $path | $GREP fstype | $AWK '{print \$1}'`) ; # use this system command to get fstype, for more portable, it's best to change to use Perl functions later
    }

    if ( 0 == $? ) {
      return uc($filesystem_info) ;
    }
  }

  return "" ;
}






our ($full, $master, $static, $verbose, $nocolor, $debug, $opt_help) ;
sub ParseArgs
{
  Getopt::Long::Configure("auto_version") ;
  my $return = GetOptions( "full"       =>  \$full,
                           "master"     =>  \$master,
                           "static"     =>  \$static,
                           "verbose"    =>  \$verbose,
                           "nocolor"    =>  \$nocolor,
                           "debug"      =>  \$debug,
                           "help|?"     =>  \$opt_help,
                          );
  

  if ( $return ne 1 || defined $opt_help ) {
    print "\n" ;
    Usage() ;
    exit 0 ;
  }

  # defined $full && ( $verbose = "true" ) ; # [-full] option will also cover [-verbose] option

  defined $nocolor && ( $ENV{ANSI_COLORS_DISABLED} = 1 ) ; # If this environment variable is set, all of the functions defined by this module (color(), colored(), and all of the constants not previously used in the program) will not output any escape sequences and instead will just return the empty string or pass through the original text as appropriate. This is intended to support easy use of scripts using this module on platforms that don't support ANSI escape sequences. For it to have its proper effect, this environment variable must be set before any color constants are used in the program.

}


sub Usage
{
  pod2usage(1) ;
}



# Get CRS_HOME/ORACLE_HOME from orainst file
our ($ORA_INVENTORY, $CRS_HOME, $CRS_BASE, $CRS_OWNER, $CRS_GROUP, $CRS_SOFTWARE_VERSION, $CRS_ACTIVE_VERSION, $CRS_RELEASE_VERSION, $CLUSTER_NAME, @ORACLE_HOMES, @ORACLE_NODES, @ORACLE_BASES, @ORACLE_OWNERS, @ORACLE_GROUPS, @CLUSTER_NODES, @REMOTE_NODES) ;
my $ITEM_WID1 = 39 ;
our ($alert_logfile, $cssd_logfiles, $crsd_logfiles, $ctssd_logfiles, $crsd_oraagent_crsowner_logfiles) ;
sub Get_RAC_Environment
{
  if ( -f "$ORAINST" && -f "$ORATAB" ) {
    print "\n\n" ;

    chomp($ORA_INVENTORY = `$CAT $ORAINST | $GREP "inventory_loc=" | $CUT -d "=" -f2`) ;
    chomp($CRS_GROUP = `$CAT $ORAINST | $GREP "inst_group=" | $CUT -d "=" -f2`) ;
    if ( defined $ORA_INVENTORY ) {
      my $inventory_xml = "$ORA_INVENTORY/ContentsXML/inventory.xml" ;
      if ( -f "$inventory_xml" ) {
        chomp(my $tmp = `$GREP 'CRS="true"' $inventory_xml | wc -l`) ;
        if ( $tmp >= 1 ) {
          chomp($CRS_HOME=`$CAT $inventory_xml | $GREP 'CRS="true"' | $TAIL -1 | $CUT -d '"' -f4`) ;
        } else {
          chomp($CRS_HOME=`$CAT $inventory_xml | $GREP 'IDX="1"' | $EGREP 'NAME="OraGI|NAME="OraGrid|NAME="OraCrs|NAME="Ora11g_grid|NAME="Ora12c_grid' | $CUT -d '"' -f4`) ;
        }

        # Get Cluster nodes from inventory.xml (not from olsnodes so that the result is still correct even when the stack is down)
        chomp(@CLUSTER_NODES = `$CAT $inventory_xml | $AWK '/CRS=/,/<\\\/NODE_LIST/' | $GREP "<NODE " | $AWK -F '"' '{print \$2}' | tr '[A-Z]' '[a-z]'`);
        if ( -x "$CRS_HOME/bin/olsnodes" ) {
          chomp(my @tmp = `$CRS_HOME/bin/olsnodes`) ;
          ( 0 == $? ) && ( @CLUSTER_NODES = @tmp ) ;
        }
        @CLUSTER_NODES = unique(@CLUSTER_NODES) ;
        @REMOTE_NODES = grep !/^$HOSTNAME$/i, @CLUSTER_NODES ;

        print BOLD, BLUE, sprintf("%-${ITEM_WID1}s\t", "The Cluster Nodes are :"), RESET ;
        print join(", ", @CLUSTER_NODES) . "\n" ;
        print BOLD, BLUE, sprintf("%-${ITEM_WID1}s\t", "The Local Node is :"), RESET ;
        print "$HOSTNAME\n" ;
        print BOLD, BLUE, sprintf("%-${ITEM_WID1}s\t", "The Remote Nodes are :"), RESET ;
        print join(", ", @REMOTE_NODES) . "\n\n" ;
      
        if ( defined $CRS_HOME ) {
          if ( -d "$CRS_HOME" ) {
            Get_CRS_Software_Version() ;
            Get_CRS_Active_Version() ;
            Get_CRS_Release_Version() ;
            print "\n" ;

            print BOLD, BLUE, sprintf("%-${ITEM_WID1}s\t", "CRS_HOME is installed at :"), RESET ;
            print "$CRS_HOME\n" ;
            $ENV{'ORACLE_BASE'} = "" ; # unset ORACLE_BASE so it won't affect the correct result of orabase
            $ENV{'ORACLE_HOME'} = $CRS_HOME ;
            chomp($CRS_BASE = `[ -x "$CRS_HOME/bin/orabase" ] && $CRS_HOME/bin/orabase 2>/dev/null`) ;
            $CRS_BASE eq "" && chomp($CRS_BASE = `[ -f "$CRS_HOME/crs/install/crsconfig_params" ] && $CAT $CRS_HOME/crs/install/crsconfig_params | $GREP "ORACLE_BASE=" | $CUT -d "=" -f2`) ;
            print BOLD, BLUE, sprintf("%-${ITEM_WID1}s\t", "CRS_BASE is installed at :"), RESET ;
            print "$CRS_BASE\n" ;

            chomp($CRS_OWNER = `[ -f "$CRS_HOME/crs/install/crsconfig_params" ] && $CAT $CRS_HOME/crs/install/crsconfig_params | $GREP "ORACLE_OWNER=" | $CUT -d "=" -f2`) ;
            print BOLD, BLUE, sprintf("%-${ITEM_WID1}s\t", "CRS_OWNER is :"), RESET ;
            print "$CRS_OWNER\n" ;
            print BOLD, BLUE, sprintf("%-${ITEM_WID1}s\t", "CRS_GROUP is :"), RESET ;
            print "$CRS_GROUP\n\n" ;

            chomp($CLUSTER_NAME = `$CAT $CRS_HOME/crs/install/crsconfig_params | $EGREP "^CLUSTER_NAME=|^CRS_CLUSTER_NAME=" | $CUT -d '=' -f2`) ; 

            if( glob("$CRS_BASE/diag/crs/*/crs/trace/alert.log") ) { # if ADR is enabled
              $alert_logfile = "$CRS_BASE/diag/crs/*/crs/trace/alert.log" ;
              $cssd_logfiles = "$CRS_BASE/diag/crs/*/crs/trace/ocssd*.trc" ;
              $crsd_logfiles = "$CRS_BASE/diag/crs/*/crs/trace/crsd*.trc" ;
              $ctssd_logfiles = "$CRS_BASE/diag/crs/*/crs/trace/octssd*.trc" ;
              $crsd_oraagent_crsowner_logfiles="$CRS_BASE/diag/crs/*/crs/trace/crsd_oraagent_${CRS_OWNER}*.trc" ;
            } else {
              $alert_logfile = "$CRS_HOME/log/*/alert*.log" ;
              $cssd_logfiles = "$CRS_HOME/log/*/cssd/*cssd.l*" ;
              $crsd_logfiles = "$CRS_HOME/log/*/crsd/crsd.l*" ;
              $ctssd_logfiles = "$CRS_HOME/log/*/ctssd/octssd.l*" ;
              $crsd_oraagent_crsowner_logfiles="$CRS_HOME/log/*/agent/crsd/oraagent_${CRS_OWNER}/oraagent_${CRS_OWNER}.l*" ;
            }
          } else {
            MsgPrint("E", "Can not find CRS_HOME dir \"$CRS_HOME\" on current node, please check it manually.\n");
          }
        } else {
          MsgPrint("E", "Can not get CRS_HOME from $inventory_xml, please check the inventory file manually.\n");
        }
        
        chomp(@ORACLE_HOMES = `$CAT $inventory_xml | $GREP IDX | $GREP -v 'CRS=' | $EGREP -vi 'NAME="OraGI|NAME="OraGrid|NAME="OraCrs|NAME="Ora11g_grid|NAME="Ora12c_grid' | $GREP -vi 'REMOVED=' | $EGREP -i 'dbhome|NAME="OraDB' | $AWK '{print \$3}' | $AWK -F'"' '{print \$2}'`) ;
        for ( my $i = 0; $i < @ORACLE_HOMES; ++$i ) {
          if ( defined $ORACLE_HOMES[$i] ) {
            if ( -d "$ORACLE_HOMES[$i]" ) {
              print BOLD, BLUE, sprintf("%-${ITEM_WID1}s\t", "ORACLE_HOMES[$i] is installed at :"), RESET ;
              my $fstype = get_fs_type($ORACLE_HOMES[$i]) ;
              $fstype = ($fstype ne "" ? ($fstype eq "ACFS" ? " (on ACFS)"
                                                            : ($fstype eq "NFS" ? " (on NFS)" 
                                                                                : " (on Local FS)")) 
                                       : "") ;
              print "$ORACLE_HOMES[$i]$fstype\n" ;
              $ENV{'ORACLE_BASE'} = "" ; # unset ORACLE_BASE so it won't affect the correct result of orabase
              $ENV{'ORACLE_HOME'} = $ORACLE_HOMES[$i] ;
              chomp($ORACLE_BASES[$i] = `if [ -x "$ORACLE_HOMES[$i]/bin/orabase" ]; then $ORACLE_HOMES[$i]/bin/orabase ; else $ECHO "" ; fi`) ;
              $ORACLE_BASES[$i] eq "" && chomp($ORACLE_BASES[$i] = `if [ -d "$ORACLE_HOMES[$i]" ]; then
                  if [ -f "$ORACLE_HOMES[$i]/install/envVars.properties" ]; then
                    $CAT $ORACLE_HOMES[$i]/install/envVars.properties | $GREP "ORACLE_BASE=" | $CUT -d "=" -f2 ; 
                  elif [ -f "$ORACLE_HOMES[$i]/inventory/ContentsXML/oraclehomeproperties.xml" ]; then
                    $CAT $ORACLE_HOMES[$i]/inventory/ContentsXML/oraclehomeproperties.xml | $GREP "<PROPERTY NAME=\"ORACLE_BASE\"" | $AWK '{print \$5}' | $AWK '{print \$2}';
                  fi;
                fi`) ;
              print BOLD, BLUE, sprintf("%-${ITEM_WID1}s\t", "ORACLE_BASES[$i] is installed at :"), RESET ;
              $fstype = get_fs_type($ORACLE_BASES[$i]) ;
              $fstype = ($fstype ne "" ? ($fstype eq "ACFS" ? " (on ACFS)"
                                                            : ($fstype eq "NFS" ? " (on NFS)" 
                                                                                : " (on Local FS)")) 
                                       : "") ;
              print "$ORACLE_BASES[$i]$fstype\n" ;

              chomp($ORACLE_OWNERS[$i] = `if [ -f "$ORACLE_HOMES[$i]/install/utl/rootmacro.sh" ]; then $CAT $ORACLE_HOMES[$i]/install/utl/rootmacro.sh | $GREP "ORACLE_OWNER=" | $CUT -d "=" -f2 ; elif [ -d "$ORACLE_HOMES[$i]" ]; then $LS -ld $ORACLE_HOMES[$i] | $AWK '{print \$3}' ; fi`) ;
              chomp($ORACLE_GROUPS[$i] = `if [ -d "$ORACLE_HOMES[$i]" ]; then $LS -ld $ORACLE_HOMES[$i] | $AWK '{print \$4}' ; fi`) ;
              print BOLD, BLUE, sprintf("%-${ITEM_WID1}s\t", "ORACLE_OWNERS[$i] is :"), RESET ;
              print "$ORACLE_OWNERS[$i]\n" ;
              print BOLD, BLUE, sprintf("%-${ITEM_WID1}s\t", "ORACLE_GROUPS[$i] is :"), RESET ;
              print "$ORACLE_GROUPS[$i]\n\n" ;

              (my $tmp = $ORACLE_HOMES[$i] ) =~ s/\//\\\//g ;
              chomp(my @tmp=`$CAT $inventory_xml | $AWK '/LOC=\"$tmp\"/,/<\\\/NODE_LIST/' | $GREP "<NODE " | $AWK -F '"' '{print \$2}'`);
              $ORACLE_NODES[$i] = [ @tmp ] ;
            } else {
              MsgPrint("W", "Can not find dir $ORACLE_HOMES[$i] on current node, please check it manually.\n");
            }
          } else {
            MsgPrint("W", "Can not get ORACLE_HOMES[$i] from $inventory_xml, please check the inventory file manually.\n");
          }
        }
        
        print "\n\n" ;
        
      } else {
        MsgPrint("E", "Can not find file $inventory_xml under $ORA_INVENTORY/ContentsXML, please check it manually!\n");
      }      
     
    } else {
      MsgPrint("E", "Broken oraInst.loc file: the contents of the file $ORAINST is broken, please check it manually!\n");
    }
    
  } else {
    MsgPrint("E", "Can not find CRS Inventory File $ORAINST on your system, please make sure you have already installed CRS correctly!\n");
  }

}



sub Get_CRS_Software_Version
{
  chomp(my $result = `$CRS_HOME/bin/crsctl query crs softwareversion | $CUT -d "[" -f3 | $CUT -d "]" -f1`) ;
  if ( 0 == $? && $result =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)\.(\d)+$/ ) {
    $CRS_SOFTWARE_VERSION = $result ;
    print BOLD, BLUE, sprintf("%-${ITEM_WID1}s\t", "Major Clusterware Software Version is :"), RESET ;
    print "$CRS_SOFTWARE_VERSION\n" ;
  } else {
    MsgPrint("E", "Can't get Oracle Clusterware Software version: $result\n$?\n");
  }
}


sub Get_CRS_Active_Version
{
  chomp(my $result = `$CRS_HOME/bin/crsctl query crs activeversion | $CUT -d "[" -f2 | $CUT -d "]" -f1`) ;
  if ( 0 == $? && $result =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)\.(\d)+$/ ) {
    $CRS_ACTIVE_VERSION = $result ;
    print BOLD, BLUE, sprintf("%-${ITEM_WID1}s\t", "Major Clusterware Active Version is :"), RESET ;
    print "$CRS_ACTIVE_VERSION\n" ;
  } else {
    MsgPrint("E", "Can't get Oracle Clusterware Active Version: $result\n$?\n");
  }
}


sub Get_CRS_Release_Version
{
  chomp(my $result = `$CRS_HOME/bin/crsctl query crs releaseversion | $CUT -d "[" -f2 | $CUT -d "]" -f1`) ;
  if ( 0 == $? && $result =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)\.(\d)+$/ ) {
    $CRS_RELEASE_VERSION = $result ;
    print BOLD, BLUE, sprintf("%-${ITEM_WID1}s\t", "Major Clusterware Release Version is :"), RESET ;
    print "$CRS_RELEASE_VERSION\n" ;
  } else {
    MsgPrint("E", "Can't get Oracle Clusterware Release Version: $result\n$?\n");
  }
}






# Compare software versions of format: xx.xx.xx.xx.xx or xx or xx.xx or xx.xx.xx or like else
# Input: two version string of the format: xx.xx.xx.xx.xx or xx or xx.xx or xx.xx.xx or like else
# Return: >0  -  ver1 > ver2
#         =0  -  ver1 = ver2
#         <0  -  ver1 < ver2
sub Version_Cmp
{
  my ($ver1, $ver2) = @_ ;
  $ver1 =~ /^\d+(\.\d+)*$/ or die "Wrong version format: $ver1\n" ;
  $ver2 =~ /^\d+(\.\d+)*$/ or die "Wrong version format: $ver2\n" ;
  
  my @ver1 = split(/\./, $ver1) ;
  my @ver2 = split(/\./, $ver2) ;
  
  my $count = ( scalar @ver1 > scalar @ver2 ? scalar @ver1 : scalar @ver2 ) ;
  
  my $sum1 = 0 ;
  for ( my $i = 0; $i < $count; ++$i ) {
    $sum1 = $sum1 * 10 + ( defined $ver1[$i] ? $ver1[$i] : 0 ) ;
  }
  
  my $sum2 = 0 ;
  for ( my $i = 0; $i < $count; ++$i ) {
    $sum2 = $sum2 * 10 + ( defined $ver2[$i] ? $ver2[$i] : 0 ) ;
  }
  
  return ($sum1 - $sum2) ;
}





our (@HUBS, @RIMS, @ACTIVE_NODES, @INACTIVE_NODES, %NODE_ID, %ID_NAME, %NODE_STATE, %NODE_ROLE) ;
sub Olsnodes {
  my $head_wid1 = 20 ;
  my $head_wid2 = 7 ;
  my $head_wid3 = 10 ;
  my $head_wid4 = 9 ;

  if ( Version_Cmp($CRS_SOFTWARE_VERSION, "12.1") >= 0 ) {

    my @result = `$CRS_HOME/bin/olsnodes -n -a -s` ;
    MsgPrint("D", "the output from \"olsnodes -n -a -s\" is: " . join("", @result) . "\n", __LINE__) ;

    if ( $? != 0 ) {
      MsgPrint("E", "\n" . join("", @result) . "\n") ;
    } else {
      print BOLD, BLUE, sprintf("%-${head_wid1}s\t", "NODE_NAME"), sprintf("%-${head_wid2}s\t", "NODE_ID"), sprintf("%-${head_wid3}s\t", "NODE_STATE"), rtrim(sprintf("%-${head_wid4}s", "NODE_ROLE")), "\n", RESET ;
      print BOLD, BLUE, sprintf("%-${head_wid1}s\t", "========="), sprintf("%-${head_wid2}s\t", "======="), sprintf("%-${head_wid3}s\t", "=========="), rtrim(sprintf("%-${head_wid4}s", "=========")), "\n", RESET ;

      chomp(@result) ;
      foreach my $line (@result) {

        $line =~ /^(\S+)\s+(\d+)\s+(\S+)\s+(\S+)$/ ;
        print BOLD, sprintf("%-${head_wid1}s\t", "$1"), sprintf("%-${head_wid2}s\t", "$2"), sprintf("%-${head_wid3}s\t", "$3"), rtrim(sprintf("%-${head_wid4}s", "$4")), "\n", RESET ;

        if ( $line =~ /^(\S+)\s+([1-9]\d*)\s+Active\s+Hub$/ ) {
          push(@HUBS, $1) ;
          push(@ACTIVE_NODES, $1) ;
          $NODE_ID{$1} = $2 ;
          $ID_NAME{$2} = $1 ;
          $NODE_STATE{$1}  = "Active" ;
          $NODE_ROLE{$1} = "Hub" ;
        } elsif ( $line =~ /^(\S+)\s+([1-9]\d*)\s+Active\s+Leaf$/) {
          push(@RIMS, $1) ;
          push(@ACTIVE_NODES, $1) ;
          $NODE_ID{$1} = $2 ;
          $ID_NAME{$2} = $1 ;
          $NODE_STATE{$1}  = "Active" ;
          $NODE_ROLE{$1} = "Leaf" ;
        } elsif ( $line =~ /^(\S+)\s+([1-9]\d*)\s+Inactive\s+None$/ ) {
          if ( $2 > 0 && $2 < 100 ) {
            push(@HUBS, $1) ;
            push(@INACTIVE_NODES, $1) ;
            $NODE_ID{$1} = $2 ;
            $ID_NAME{$2} = $1 ;
            $NODE_STATE{$1}  = "Inactive" ;
            $NODE_ROLE{$1} = "Hub" ;
          } elsif ( $2 >= 100 ) {
            push(@RIMS, $1) ;
            push(@INACTIVE_NODES, $1) ;
            $NODE_ID{$1} = $2 ;
            $ID_NAME{$2} = $1 ;
            $NODE_STATE{$1}  = "Inactive" ;
            $NODE_ROLE{$1} = "Leaf" ;
          } else {
            MsgPrint("E", __LINE__ . ": You shouldn't have arrived here: Wrong olsnodes output format: $line\n") ;
          }
        } else {
          MsgPrint("E", __LINE__ . ": Wrong olsnodes output format: $line\n") ;
        }
      }
    }

  } elsif ( Version_Cmp($CRS_SOFTWARE_VERSION, "11.2") >= 0 ) {

    my @result = `$CRS_HOME/bin/olsnodes -n -s` ;
    MsgPrint("D", "the output from \"olsnodes -n -s\" is: " . join("", @result) . "\n", __LINE__) ;

    if ( $? != 0 ) {
      MsgPrint("E", "\n" . join("", @result) . "\n") ;
    } else {
      print BOLD, BLUE, sprintf("%-${head_wid1}s\t", "NODE_NAME"), sprintf("%-${head_wid2}s\t", "NODE_ID"), rtrim(sprintf("%-${head_wid3}s\t", "NODE_STATE")), "\n", RESET ;
      print BOLD, BLUE, sprintf("%-${head_wid1}s\t", "========="), sprintf("%-${head_wid2}s\t", "======="), rtrim(sprintf("%-${head_wid3}s\t", "==========")), "\n", RESET ;

      chomp(@result) ;
      foreach my $line (@result) {

        $line =~ /^(\S+)\s+(\d+)\s+(\S+)$/ ;
        print BOLD, sprintf("%-${head_wid1}s\t", "$1"), sprintf("%-${head_wid2}s\t", "$2"), rtrim(sprintf("%-${head_wid3}s\t", "$3")), "\n", RESET ;

        if ( $line =~ /^(\S+)\s+([1-9]\d*)\s+Active$/ ) {
          push(@HUBS, $1) ;
          push(@ACTIVE_NODES, $1) ;
          $NODE_ID{$1} = $2 ;
          $ID_NAME{$2} = $1 ;
          $NODE_STATE{$1}  = "Active" ;
          $NODE_ROLE{$1} = "Hub" ;
        } elsif ( $line =~ /^(\S+)\s+([1-9]\d*)\s+Inactive$/ ) {
          push(@HUBS, $1) ;
          push(@INACTIVE_NODES, $1) ;
          $NODE_ID{$1} = $2 ;
          $ID_NAME{$2} = $1 ;
          $NODE_STATE{$1}  = "Inactive" ;
          $NODE_ROLE{$1} = "Hub" ;
        } else {
          MsgPrint("E", __LINE__ . ": Wrong olsnodes output format: $line\n") ;
        }
      }
    }
  
  } else {
    MsgPrint("E", "Unsupported Clusterware version: $CRS_SOFTWARE_VERSION\n") ;
  }

  # remove duplicates
  @ACTIVE_NODES = unique(@ACTIVE_NODES) ;
  @INACTIVE_NODES = unique(@INACTIVE_NODES) ;
  
  MsgPrint("D", "All Hub Nodes: " . join(", ", @HUBS) . "\n", __LINE__) ;
  MsgPrint("D", "All Leaf Nodes: " . join(", ", @RIMS) . "\n", __LINE__) ;
  MsgPrint("D", "All Active Nodes: " . join(", ", @ACTIVE_NODES) . "\n", __LINE__) ;
  MsgPrint("D", "All Inactive Nodes: " . join(", ", @INACTIVE_NODES) . "\n", __LINE__) ;
  MsgPrint("D", "Node's Name-ID: \%NODE_ID\n" . Dumper(\%NODE_ID) . "\n", __LINE__) ;
  MsgPrint("D", "Node's ID-Name: \%ID_NAME\n" . Dumper(\%ID_NAME) . "\n", __LINE__) ;
  MsgPrint("D", "Node's State: \%NODE_STATE\n" . Dumper(\%NODE_STATE) . "\n", __LINE__) ;
  MsgPrint("D", "Node's Role: \%NODE_ROLE\n" . Dumper(\%NODE_ROLE) . "\n", __LINE__) ;
  
  print "\n\n\n" ;
}






my $ITEM_WID2 = 23 ;

# Get all databases on this cluster
our (@DB, %DB_Details, %Instance_Running_On_Node) ;
sub Get_All_DB
{
  my @result = `$CRS_HOME/bin/srvctl config database -v` ;
  MsgPrint("D", "the output from \"srvctl config database -v\" is: " . join("", @result) . "\n", __LINE__) ;
  chomp(@result) ;

  if ( 0 == $? ) {
    foreach my $line ( @result ) {
      if ( $line =~ /^(\S+)\s+(\S+)\s+(\d+\.\d+\.\d+\.\d+\.\d)$/ ) {
        push(@DB, $1) ;
        $DB_Details{$1}{"Oracle home"} = $2 ;
        $DB_Details{$1}{"Version"} = $3 ;
      } elsif ( $line =~ /No databases are configured/ ) {
        @DB = () ;
      } else {
        MsgPrint("E", __LINE__ . ": Wrong srvctl output format: $line\n") ;
      }
    }
  } else {
    @DB = () ;
  }


  my @all_nodes = (@CLUSTER_NODES, @ACTIVE_NODES, @INACTIVE_NODES) ; # on a Leaf node, @CLUSTER_NODES only has itself, so we need to join these arrays together to get all possible nodes
  MsgPrint("D", "all possible nodes before uniquing: " . join(",", @all_nodes) . "\n", __LINE__) ;
  @all_nodes = unique(@all_nodes) ;
  MsgPrint("D", "all possible nodes after uniquing: " . join(",", @all_nodes) . "\n", __LINE__) ;
  my $succeed_flag = "N" ;
  foreach my $node (@all_nodes) {
    if ( Test_SSH($node) == 0 ) {
      foreach my $db (@DB) {
        $ENV{"ORACLE_HOME"} = $DB_Details{$db}{"Oracle home"} ;
        chomp(my @result = `$SSH $node "[ -x $ENV{'ORACLE_HOME'}/bin/srvctl ] && export ORACLE_HOME=$ENV{'ORACLE_HOME'} && $ENV{'ORACLE_HOME'}/bin/srvctl status database -d $db"`) ;
        MsgPrint("D", "the output from \"srvctl status database -d $db\" on node <$node> is:\n" . join("\n", @result) . "\n", __LINE__) ;
        if ( 0 == $? ) {
          $succeed_flag = "Y" ;
          foreach my $line (@result) {
            if ( $line =~ /^Instance (.+) is running on node (.+)$/ ) {     
              $DB_Details{$db}{$1} = $2 ;  # instance $1 is running on node $2
              $Instance_Running_On_Node{$1} = $2 ;
            }
          }
        } else {
          #
        }
      }
      last if $succeed_flag eq "Y" ;
    }
  }


  print BOLD, BLUE, sprintf("%-${ITEM_WID2}s\t","All databases created :"), RESET ;
  print join(", ", @DB) . "\n" ;
}


#
sub List_DB_Detail
{
  if ( @DB ) {
    my $head_wid1 = 12 ;
    my $head_wid2 = 12 ;
    my $head_wid3 = 12 ;
    my $head_wid4 = 12 ;
    my $head_wid5 = 42 ;
    my $head_wid6 = 15 ;
    
    print "\n" ;
    print BOLD, BLUE, sprintf("%-${head_wid1}s\t", "DB_NAME"), 
                      sprintf("%-${head_wid2}s\t", "MANAGEMENT"),
                      sprintf("%-${head_wid3}s\t", "DB_TYPE"),
                      sprintf("%-${head_wid4}s\t", "DB_VERSION"),
                      sprintf("%-${head_wid5}s\t", "DB_HOME"), 
                      rtrim(sprintf("%-${head_wid6}s", "DG/FS USED")), "\n", RESET ;
    print BOLD, BLUE, sprintf("%-${head_wid1}s\t", "======="), 
                      sprintf("%-${head_wid2}s\t", "=========="),
                      sprintf("%-${head_wid3}s\t", "======="),
                      sprintf("%-${head_wid4}s\t", "=========="),
                      sprintf("%-${head_wid5}s\t", "======="), 
                      rtrim(sprintf("%-${head_wid6}s", "==========")), "\n", RESET ;

    my @all_nodes = (@CLUSTER_NODES, @ACTIVE_NODES, @INACTIVE_NODES) ; # on a Leaf node, @CLUSTER_NODES only has itself, so we need to join these arrays together to get all possible nodes
    MsgPrint("D", "all possible nodes before uniquing: " . join(",", @all_nodes) . "\n", __LINE__) ;
    @all_nodes = unique(@all_nodes) ;
    MsgPrint("D", "all possible nodes after uniquing: " . join(",", @all_nodes) . "\n", __LINE__) ;
    my $succeed_flag = "N" ;
    foreach my $node (@all_nodes) {
      if ( Test_SSH($node) == 0 ) {
        foreach my $db ( @DB ) {
          $ENV{"ORACLE_HOME"} = $DB_Details{$db}{"Oracle home"} ;
          chomp(my @result = `$SSH $node "[ -x $ENV{'ORACLE_HOME'}/bin/srvctl ] && export ORACLE_HOME=$ENV{'ORACLE_HOME'} && $ENV{'ORACLE_HOME'}/bin/srvctl config database -d $db -a"`) ;
          MsgPrint("D", "the output from \"srvctl config database -d $db -a\" on node <$node> is:\n" . join("\n", @result) . "\n", __LINE__) ;

          if ( 0 == $? ) {
            $succeed_flag = "Y" ;
            my @db_dgs = () ;
            foreach my $line ( @result ) {
              if ( $line =~ /^Spfile: (.+)$/i ) {
                $DB_Details{$db}{"Spfile"} = $1 ;
                $1 =~ /^\+(.+?)\// && ! grep(/^\+$1$/i, @db_dgs) && push(@db_dgs, "+$1") ;
              } elsif ( $line =~ /^Password file: (.+)$/i ) {
                $DB_Details{$db}{"Password file"} = $1 ;
                $1 =~ /^\+(.+?)\// && ! grep(/^\+$1$/i, @db_dgs) && push(@db_dgs, "+$1") ;
              } elsif ( $line =~ /^Disk Groups: (.+)$/ ) {
                foreach (split(/,| /,$1)) {
                  ! grep(/^\+$_$/i, @db_dgs) && push(@db_dgs, "+$_") ;
                }
              } elsif ( $line =~ /^Mount point paths: (.+)$/ ) {
                $DB_Details{$db}{"Mount point paths"} = $1 ;
              } elsif ( $line =~ /^Type: (.+)$/i ) {
                $DB_Details{$db}{"Type"} = $1 ;
              } elsif ( $line =~ /^Online relocation timeout: (.+)/i ) {
                $DB_Details{$db}{"Relocation timeout"} = $1 ;
              } elsif ( $line =~ /^Database is (.+) managed$/ ) {
                $DB_Details{$db}{"Management"} = $1 ;
              } elsif ( $line =~ /POLICY:/i  ) { # this is for 10.2 version dbs
                $DB_Details{$db}{"Type"} = "RAC" ;
                $DB_Details{$db}{"Management"} = "policy" ;
              } else {
                #
              }
            }

            $DB_Details{$db}{"Disk Groups"} = ( defined $DB_Details{$db}{"Mount point paths"} ? 
                                                join(",", (@db_dgs, $DB_Details{$db}{"Mount point paths"})) :
                                                join(",", (@db_dgs)) ) ;

            print BOLD, sprintf("%-${head_wid1}s\t", "$db"), 
                        sprintf("%-${head_wid2}s\t", "$DB_Details{$db}{'Management'}") ,
                        sprintf("%-${head_wid3}s\t", "$DB_Details{$db}{'Type'}") ,
                        sprintf("%-${head_wid4}s\t", "$DB_Details{$db}{'Version'}") ,
                        sprintf("%-${head_wid5}s\t", "$DB_Details{$db}{'Oracle home'}") ,
                        rtrim(sprintf("%-${head_wid6}s", "'" . "$DB_Details{$db}{'Disk Groups'}" . "'")), "\n" , RESET ;
          } else {
            MsgPrint("W", "Error occurred during running \"$CRS_HOME/bin/srvctl config database -d $db -a\" :\n" . join("\n",@result) . "\n$?\n") ;
          }
        }
        last if $succeed_flag eq "Y" ;
      }
    }
  }

  print "\n\n\n" ;
}





our (%ASM_INST, %APX_INST) ;
sub Get_ASM_APX_Instance
{
  my @all_nodes = (@CLUSTER_NODES, @ACTIVE_NODES, @INACTIVE_NODES) ; # on a Leaf node, @CLUSTER_NODES only has itself, so we need to join these arrays together to get all possible nodes
  MsgPrint("D", "all possible nodes before uniquing: " . join(",", @all_nodes) . "\n", __LINE__) ;
  @all_nodes = unique(@all_nodes) ;
  MsgPrint("D", "all possible nodes after uniquing: " . join(",", @all_nodes) . "\n", __LINE__) ;
  foreach my $node (@all_nodes) {
    if ( Test_SSH($node) == 0 ) {
      # get ASM instances
      chomp(my $result = `$SSH $node "$CAT $ORATAB | $GREP '+ASM' | $TAIL -1 | $CUT -d':' -f1"`) ;
      MsgPrint("D", "\$result : $result\n", __LINE__) ;
      if ( $result eq "" ) {
        chomp($result = `$SSH $node "$PSEF | $GREP asm_pmon | $GREP -v grep | $TAIL -1"` ) ;
        MsgPrint("D", "\$result : $result\n", __LINE__) ;
        ( $result =~ /asm_pmon_\+ASM(\d+)$/ ) ? ( $result = "+ASM$1" ) : ( $result = "" ) ;
      }
      MsgPrint("D", "ASM instance on $node: $result\n", __LINE__) ;
      $ASM_INST{lc($node)} = $result ;
      $Instance_Running_On_Node{$result} = $node ;


      # get APX instances
      chomp($result = `$SSH $node "$CAT $ORATAB | $GREP '+APX' | $TAIL -1 | $CUT -d':' -f1"`) ;
      MsgPrint("D", "\$result : $result\n", __LINE__) ;
      if ( $result eq "" ) {
        chomp($result = `$SSH $node "$PSEF | $GREP apx_pmon | $GREP -v grep | $TAIL -1"` ) ;
        MsgPrint("D", "\$result : $result\n", __LINE__) ;
        ( $result =~ /apx_pmon_\+APX(\d+)$/ ) ? ( $result = "+APX$1" ) : ( $result = "" ) ;
      }
      MsgPrint("D", "APX instance on $node: $result\n", __LINE__) ;
      $APX_INST{lc($node)} = $result ;
      $Instance_Running_On_Node{$result} = $node ;
    }
  }
  MsgPrint("D", "%%ASM_INST, %%APX_INST, %%Instance_Running_On_Node :\n" . Dumper(\%ASM_INST, \%APX_INST, \%Instance_Running_On_Node) . "\n", __LINE__) ;
}




our (%MGMTDB_Details) ;
sub Get_MGMTDB
{
  chomp(my @result = `$CRS_HOME/bin/srvctl status mgmtdb`) ;
  MsgPrint("D", "the output from \"srvctl status mgmtdb\" is: " . join("\n", @result) . "\n", __LINE__) ;
  
  $MGMTDB_Details{"Enabled"} = "N" ;

  if ( 0 == $? ) {
    foreach my $line ( @result ) {
      if ( $line =~ /^Database is enabled$/ ) {
        $MGMTDB_Details{"Enabled"} = "Y" ;
      } elsif ( $line =~ /^Instance -MGMTDB is running on node (.+)$/ ) {
        $MGMTDB_Details{"Running On"} = ( defined $MGMTDB_Details{"Running On"} ? "$MGMTDB_Details{'Running On'},$1" : $1 ) ;
        $Instance_Running_On_Node{"-MGMTDB"} = $MGMTDB_Details{"Running On"} ;
      }
    }
  } else {
    MsgPrint("W", "Error occurred during running \"$CRS_HOME/bin/srvctl status mgmtdb\" :\n" . join("\n",@result) . "\n$?\n") ;
  }


  @result = `$CRS_HOME/bin/srvctl config mgmtdb` ;
  MsgPrint("D", "the output from \"srvctl config mgmtdb\" is: " . join("", @result) . "\n", __LINE__) ;
  chomp(@result) ;

  if ( 0 == $? ) {
    foreach my $line ( @result ) {
      if ( $line =~ /^Oracle home: (.*)$/ ) {
        $MGMTDB_Details{"Home"} = $1 ;
      } elsif ( $line =~ /^Spfile: (.*)$/ ) {
        $MGMTDB_Details{"Spfile"} = $1 ;
      } elsif ( $line =~ /^Database instance: (.*)$/ ) {
        $MGMTDB_Details{"Instance"} = $1 ;
      }
    }
  } else {
    MsgPrint("W", "Error occurred during running \"$CRS_HOME/bin/srvctl config mgmtdb\" :\n" . join("\n",@result) . "\n$?\n") ;
  }
}




sub List_MGMTDB
{
  print BOLD, BLUE, sprintf("%-${ITEM_WID2}s\t", "MGMTDB Status :"), RESET ;
  print ($MGMTDB_Details{"Enabled"} eq "Y" ? "enabled" : "disabled") ;
  defined $MGMTDB_Details{"Running On"} ? print " and is running on $MGMTDB_Details{'Running On'}\n" : print " and isn't running now\n" ;
  print BOLD, BLUE, sprintf("%-${ITEM_WID2}s\t", "MGMTDB HOME :"), RESET ;
  defined $MGMTDB_Details{"Home"} ? print "$MGMTDB_Details{'Home'}\n" : print "N/A\n" ;
  print BOLD, BLUE, sprintf("%-${ITEM_WID2}s\t", "MGMTDB Spfile :"), RESET ;
  defined $MGMTDB_Details{"Spfile"} ? print "'" . $MGMTDB_Details{"Spfile"} . "'\n" : print "N/A\n" ;
  print BOLD, BLUE, sprintf("%-${ITEM_WID2}s\t", "MGMTDB Instance :"), RESET ;
  defined $MGMTDB_Details{"Instance"} ? print "'" . $MGMTDB_Details{"Instance"} . "'\n" : print "N/A\n" ;
  print "\n" ;
}





our (%MGMTLSNR_Details) ;
sub Get_MGMTLSNR
{
  chomp(my @result = `$CRS_HOME/bin/srvctl status mgmtlsnr -v`) ;
  MsgPrint("D", "the output from \"srvctl status mgmtlsnr -v\" is: " . join("\n", @result) . "\n", __LINE__) ;

  $MGMTLSNR_Details{"Enabled"} = "N" ;

  if ( 0 == $? ) {
    foreach my $line ( @result ) {
      if ( $line =~ /^Listener MGMTLSNR is enabled$/ ) {
        $MGMTLSNR_Details{"Enabled"} = "Y" ;
      } elsif ( $line =~ /^Listener MGMTLSNR is running on node\(s\): (.+)$/ ) {
        $MGMTLSNR_Details{"Running On"} = ( defined $MGMTLSNR_Details{"Running On"} ? "$MGMTLSNR_Details{'Running On'},$1" : $1 ) ;
      } elsif ( $line =~ /^Detailed state on node .*?: (.+)$/ ) {
        $MGMTLSNR_Details{"Detailed state"} = ( defined $MGMTLSNR_Details{"Detailed state"} ? "$MGMTLSNR_Details{'Detailed state'} $1" : $1 ) ;
      }
    }
  } else {
    MsgPrint("W", "Error occurred during running \"$CRS_HOME/bin/srvctl status mgmtlsnr -v\" :\n" . join("\n",@result) . "\n$?\n") ;
  }


  @result = `$CRS_HOME/bin/srvctl config mgmtlsnr` ;
  MsgPrint("D", "the output from \"srvctl config mgmtlsnr\" is: " . join("", @result) . "\n", __LINE__) ;
  chomp(@result) ;

  if ( 0 == $? ) {
    foreach my $line ( @result ) {
      if ( $line =~ /^Home: (.*)$/ ) {
        $MGMTLSNR_Details{"Home"} = $1 ;
      } elsif ( $line =~ /^End points: (.*)$/ ) {
        $MGMTLSNR_Details{"Port"} = $1 ;
      }
    }
  } else {
    MsgPrint("W", "Error occurred during running \"$CRS_HOME/bin/srvctl config mgmtlsnr\" :\n" . join("\n",@result) . "\n$?\n") ;
  }
}




sub List_MGMTLSNR
{
  print BOLD, BLUE, sprintf("%-${ITEM_WID2}s\t", "MGMTLSNR Status :"), RESET ;
  print ($MGMTLSNR_Details{"Enabled"} eq "Y" ? "enabled" : "disabled") ;
  defined $MGMTLSNR_Details{"Running On"} ? print " and is running on $MGMTLSNR_Details{'Running On'}\n" : print " and isn't running now\n" ;
  print BOLD, BLUE, sprintf("%-${ITEM_WID2}s\t", "MGMTLSNR HOME :"), RESET ;
  defined $MGMTLSNR_Details{"Home"} ? print "$MGMTLSNR_Details{'Home'}\n" : print "N/A\n" ;
  print BOLD, BLUE, sprintf("%-${ITEM_WID2}s\t", "MGMTLSNR Port :"), RESET ;
  defined $MGMTLSNR_Details{"Port"} ? print "$MGMTLSNR_Details{'Port'}\n" : print "N/A\n" ;
  print BOLD, BLUE, sprintf("%-${ITEM_WID2}s\t", "Detailed state :"), RESET ;
  defined $MGMTLSNR_Details{"Detailed state"} ? print "$MGMTLSNR_Details{'Detailed state'}\n" : print "N/A\n" ;
  print "\n\n\n" ;
}






our (%ASMNETLSNR_Details, @ASMNETLSNR_Name, @ASMNETLSNR_Subnet, @ASMNETLSNR_Endpoint, @ASMNETLSNR_Owner, @ASMNETLSNR_Home, @ASMNETLSNR_Status) ;
sub Get_ASMNETLSNR
{
  chomp(my @result = `$CRS_HOME/bin/srvctl config listener -asmlistener -all`) ;
  MsgPrint("D", "the output from \"srvctl config listener -asmlistener -all\" is: " . join("\n", @result) . "\n", __LINE__) ;

  if ( 0 == $? ) {
    @ASMNETLSNR_Name     = grep(/^Name:/, @result) ;
    @ASMNETLSNR_Subnet   = grep(/^Subnet:/, @result) ;
    @ASMNETLSNR_Endpoint = grep(/^End points:/, @result) ;
    @ASMNETLSNR_Owner    = grep(/^Owner:/, @result) ;
    @ASMNETLSNR_Home     = grep(/^Home:/, @result) ;
    @ASMNETLSNR_Status   = grep(/^Listener is \S+.$/, @result) ;

    if ( @ASMNETLSNR_Name != @ASMNETLSNR_Subnet || @ASMNETLSNR_Name != @ASMNETLSNR_Endpoint || @ASMNETLSNR_Name != @ASMNETLSNR_Owner || @ASMNETLSNR_Name != @ASMNETLSNR_Home || @ASMNETLSNR_Name != @ASMNETLSNR_Status ) {
      MsgPrint("W", "Invalid output format from \"$CRS_HOME/bin/srvctl config listener -asmlistener -all\" :\n" . join("\n",@result) . "\n$?\n") ;
    } else {
      map { ($_ =~ /^Name: (.*)$/) && ($_ = $1) ; }        @ASMNETLSNR_Name ;
      map { ($_ =~ /^Subnet: (.*)$/) && ($_ = $1) ; }      @ASMNETLSNR_Subnet ;
      map { ($_ =~ /^End points: (.*)$/) && ($_ = $1) ; }  @ASMNETLSNR_Endpoint ;
      map { ($_ =~ /^Owner: (.*)$/) && ($_ = $1) ; }       @ASMNETLSNR_Owner ;
      map { ($_ =~ /^Home: (.*)$/) && ($_ = $1) ; }        @ASMNETLSNR_Home ;
      map { ($_ =~ /^Listener is (.*).$/) && ($_ = $1) ; } @ASMNETLSNR_Status ;
    }
  } else {
    MsgPrint("W", "Error occurred during running \"$CRS_HOME/bin/srvctl config listener -asmlistener -all\" :\n" . join("\n",@result) . "\n$?\n") ;
  }
}




sub List_ASMNETLSNR
{
  my $tmp_item_width = 15 ;
  print BOLD, BLUE, sprintf("%-${ITEM_WID2}s\t", ""), (map { sprintf("%-${tmp_item_width}s\t", $_) } @ASMNETLSNR_Name), "\n", RESET ;
  print BOLD, BLUE, sprintf("%-${ITEM_WID2}s\t", ""), (map { sprintf("%-${tmp_item_width}s\t", '=' x length($_)) } @ASMNETLSNR_Name), "\n", RESET ;

  print BOLD, BLUE, sprintf("%-${ITEM_WID2}s\t", "Subnet :"), RESET ;
  map { print sprintf("%-${tmp_item_width}s\t", $_) } @ASMNETLSNR_Subnet ; print "\n" ;

  print BOLD, BLUE, sprintf("%-${ITEM_WID2}s\t", "End points :"), RESET ;
  map { print sprintf("%-${tmp_item_width}s\t", $_) } @ASMNETLSNR_Endpoint ; print "\n" ;

  print BOLD, BLUE, sprintf("%-${ITEM_WID2}s\t", "Owner :"), RESET ;
  map { print sprintf("%-${tmp_item_width}s\t", $_) } @ASMNETLSNR_Owner ; print "\n" ;

  print BOLD, BLUE, sprintf("%-${ITEM_WID2}s\t", "Home :"), RESET ;
  map { print sprintf("%-${tmp_item_width}s\t", $_) } @ASMNETLSNR_Home ; print "\n" ;

  print BOLD, BLUE, sprintf("%-${ITEM_WID2}s\t", "Status :"), RESET ;
  map { print sprintf("%-${tmp_item_width}s\t", $_) } @ASMNETLSNR_Status ; print "\n" ;

  print "\n\n\n" ;
}






#==============================================================================
# NAME:
#   Get_CSS_Master - get CSS master
# PARAMETERS:
#   None
#RETURNS:
#   None
#==============================================================================
our ($CSS_Master) ;
sub Get_CSS_Master
{
  my $css_master_key1 = "clssgmCMReconfig: reconfiguration successful" ;
  my $css_master_key2 = "incarnation" ;
  
  my (%css_master);
  foreach my $node ( @ACTIVE_NODES ) {
    if ( Test_SSH($node) == 0 ) {
      my $cmd = "$SSH $node \"$GREP -h '$css_master_key1' $cssd_logfiles | $SORT | $TAIL -1\"" ;
      chomp(my $result = `$cmd`) ;
      MsgPrint("D", "$node: $result\n", __LINE__) ;
      $css_master{$node} = $result ;
    } else {
      $css_master{$node} = -1 ;
    }
  }
  
  my $max = -1 ;
  foreach my $node ( @ACTIVE_NODES ) {
    if ( $css_master{$node} =~ /(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})\.(\d{3}).*$css_master_key1.*$css_master_key2\s+.*master node (.*),.*/ ) {
      my $tmp = "$1$2$3$4$5$6$7" ;
      MsgPrint("D", "\$tmp is: $tmp\n", __LINE__) ;
      if ( $max < $tmp ) {
        $max = $tmp ;
        $CSS_Master = "$8";
        MsgPrint("D", "$node: $tmp: CSS Master is $CSS_Master\n", __LINE__) ;
      }
    }
  }

  defined $CSS_Master ? 1 : ($CSS_Master = "N/A") ;
}


my $ITEM_WID3 = 17 ;

#
sub List_CSS_Master
{
  &Get_CSS_Master ;
  print BOLD, BLUE, sprintf("%-${ITEM_WID3}s\t", "CSS Master :"), RESET ;
  print "$CSS_Master\n\n\n\n" ;
}





#==============================================================================
# NAME:
#   Get_OCR_Master - get OCR master
# PARAMETERS:
#   None
#RETURNS:
#   None
#==============================================================================
our ($OCR_MASTER) ;
sub Get_OCR_Master
{
  my $crs_key = "I AM THE NEW OCR MASTER at incar|NEW OCR MASTER IS" ;

  my (%ocr_master);
  foreach my $node ( @ACTIVE_NODES ) {
    if ( Test_SSH($node) == 0 ) {
      my $cmd = "$SSH $node \"$EGREP -h \\\"$crs_key\\\" $crsd_logfiles | $SORT | $TAIL -1\"" ;
      chomp(my $result = `$cmd`) ;
      MsgPrint("D", "$node: $result\n", __LINE__) ;
      $ocr_master{$node} = $result ;
    } else {
      $ocr_master{$node} = -1 ;
    }
  }
  
  my $max = 0;
  foreach my $node ( @ACTIVE_NODES ) {
    if ( $ocr_master{$node} =~ /(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})\.(\d{3}).*($crs_key)/ ) {
      my $tmp = "$1$2$3$4$5$6$7" ;
      MsgPrint("D", "\$tmp is: $tmp\n", __LINE__) ;
      if ( $max < $tmp ) {
        $max = $tmp ;
        if ( $ocr_master{$node} =~ /I AM THE NEW OCR MASTER at incar/ ) {
          $OCR_MASTER = $node ;
        } elsif ( $ocr_master{$node} =~ /NEW OCR MASTER IS (\d+)$/ ) {
          $OCR_MASTER = $ID_NAME{$1} ;
        } else {
          MsgPrint("E", __LINE__ . ": Wrong OCR master log format: $ocr_master{$node}\n") ;
        }
        MsgPrint("D", "$node: $tmp: OCR/CRSD Master is $OCR_MASTER\n", __LINE__) ;
      }
    }
  }

  defined $OCR_MASTER ? 1 : ($OCR_MASTER = "N/A") ;
}




#
sub List_OCR_Master
{
  &Get_OCR_Master ;
  print BOLD, BLUE, sprintf("%-${ITEM_WID3}s\t", "OCR/CRSD Master :"), RESET ;
  print "$OCR_MASTER\n\n\n\n" ;
}




#==============================================================================
# NAME:
#   Get_PE_Master - get PE master
# PARAMETERS:
#   None
#RETURNS:
#   None
#==============================================================================
our ($PE_Master) ;
sub Get_PE_Master
{
  my $pe_master_key = "CRSPE.*PE MASTER NAME" ;
  
  my (%pe_master);
  foreach my $node ( @ACTIVE_NODES ) {
    if ( Test_SSH($node) == 0 ) {
      my $cmd = "$SSH $node \"$GREP -h \\\"$pe_master_key\\\" $crsd_logfiles | $SORT | $TAIL -1\"" ;
      chomp(my $result = `$cmd`) ;
      MsgPrint("D", "$node: $result\n", __LINE__) ;
      $pe_master{$node} = $result ;
    } else {
      $pe_master{$node} = -1 ;
    }
  }
  
  my $max = -1 ;
  foreach my $node ( @ACTIVE_NODES ) {
    if ( $pe_master{$node} =~ /(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})\.(\d{3}).*$pe_master_key:\s+(.*)/ ) {
      my $tmp = "$1$2$3$4$5$6$7" ;
      MsgPrint("D", "\$tmp is: $tmp\n", __LINE__) ;
      if ( $max < $tmp ) {
        $max = $tmp ;
        $PE_Master = "$8";
        MsgPrint("D", "$node: $tmp: CRSD PE Master is $PE_Master\n", __LINE__) ;
      }
    }
  }

  defined $PE_Master ? 1 : ($PE_Master = "N/A") ;
}



#
sub List_PE_Master
{
  &Get_PE_Master ;
  print BOLD, BLUE, sprintf("%-${ITEM_WID3}s\t", "CRSD PE Master :"), RESET ;
  print "$PE_Master\n\n\n\n" ;
}




#==============================================================================
# NAME:
#   Get_PE_Standby - get PE standby
# PARAMETERS:
#   None
#RETURNS:
#   None
#==============================================================================
our ($PE_STANDBY) ;
sub Get_PE_Standby
{
  my $pe_standby_key = "I AM A STANDBY MASTER|CURRENT STANDBY SERVERS:" ;
  
  my (%pe_standby);
  foreach my $node ( @ACTIVE_NODES ) {
    if ( Test_SSH($node) == 0 ) {
      my $cmd = "$SSH $node \"$EGREP -h \\\"$pe_standby_key\\\" $crsd_logfiles | $SORT | $TAIL -1\"" ;
      chomp(my $result = `$cmd`) ;
      MsgPrint("D", "$node: $result\n", __LINE__) ;
      $pe_standby{$node} = $result ;
    } else {
      $pe_standby{$node} = "" ;
    }
  }
  
  
  my $max = -1 ;
  foreach my $node ( @ACTIVE_NODES ) {
    if ( $pe_standby{$node} =~ /(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})\.(\d{3}).*($pe_standby_key)/ ) {
      my $tmp = "$1$2$3$4$5$6$7" ;
      MsgPrint("D", "\$tmp is: $tmp\n", __LINE__) ;
      if ( $max < $tmp ) {
        $max = $tmp ;
        if ( $pe_standby{$node} =~ /I AM A STANDBY MASTER\./ ) {
          $PE_STANDBY = $node ;
        } elsif ( $pe_standby{$node} =~ /CURRENT STANDBY SERVERS: (.*)$/ ) {
          $PE_STANDBY = $1 ;
        } else {
          MsgPrint("E", __LINE__ . ": Wrong crsd PE standby log format: $pe_standby{$node}\n") ;
        }
        MsgPrint("D", "$node: $tmp: CRSD PE Standby is $PE_STANDBY\n", __LINE__) ;
      }
    }
  }

  defined $PE_STANDBY ? 1 : ($PE_STANDBY = "N/A") ;
}



#
sub List_PE_Standby
{
  &Get_PE_Standby ;
  print BOLD, BLUE, sprintf("%-${ITEM_WID3}s\t", "CRSD PE Standby :"), RESET ;
  print "$PE_STANDBY\n\n\n\n" ;
}




#
sub List_OCR_Rank
{
  my $ocr_rank_key = "My Rank" ;
  
  foreach my $node ( @ACTIVE_NODES ) {
    if ( Test_SSH($node) == 0 ) {
      my $cmd = "$SSH $node \"$GREP -h \\\"$ocr_rank_key\\\" $crsd_logfiles | $SORT | $TAIL -1\"" ;
      chomp(my $result = `$cmd`) ;
      MsgPrint("D", "$node: $result\n", __LINE__) ;
      if ( $result =~ /^\d{4}-(.+):.*OCRMAS.*: Rank of OCR:\[(\d+)\]. Rank of ASM Instance:\[(\d+)\]. Rank of CRS Standby:\[(\d+)\]. OCR on ASM:\[(\d+)\]. ASM mode:\[(\d+)\]. My Rank:\[(\d+)\]. Min Rank:\[(\d+)\].$/ ) {
        print BOLD, BLUE, "<$node> ", RESET ;
        print "$1 " ;
        $7 >= $8 ? print BOLD, YELLOW, "My R:$7 " . ( $7 > $8 ? ">" : "=" ) . " Min R:$8", RESET :
                   print BOLD, RED, "My R:$7 < Min R:$8", RESET ;
        print "   R of OCR:" ;
        print BOLD, YELLOW, "$2", RESET ;
        $4 >= 1 ? print BOLD, YELLOW, "   R of CRS Standby:$4", RESET : 
                  print BOLD, RED, "   R of CRS Standby:$4", RESET ;
        $3 > 0 ? print BOLD, YELLOW, "   R of ASM Inst:$3", RESET :
                 print BOLD, RED, "   R of ASM Inst:$3", RESET ;
        $5 > 0 ? print BOLD, YELLOW, "   OCR on ASM:", RESET : print "   OCR on ASM:" ;
        print BOLD, YELLOW, "$5", RESET ;
        print "   ASM mode:" ;
        print BOLD, YELLOW, "$6\n", RESET ;
      } elsif ( $result eq "" ) {
        print BOLD, BLUE, "<$node> ", RESET ;
        print "Ranks: N/A\n" ;
      } else {
        MsgPrint("E", __LINE__ . ": Wrong crsd log format1: $result\n") ;
      }
    } else {
      # ;
    }
  }
  
  print "\n\n\n" ;
}






#
sub List_PE_Role_State
{
  my $pe_role_key = "PE Role" ;
  
  foreach my $node ( @ACTIVE_NODES ) {
    if ( Test_SSH($node) == 0 ) {
      my $cmd = "$SSH $node \"$GREP -h \\\"$pe_role_key\\\" $crsd_logfiles | $SORT | $TAIL -1\"" ;
      chomp(my $result = `$cmd`) ;
      MsgPrint("D", "$node: $result\n", __LINE__) ;
      if ( $result =~ /^\d{4}-(.+)\s*:.*CRSPE.+PE Role\|State Update: old role \[(.+)\] new \[(.+)\]; old state \[(.+)\] new \[(.+)\]$/ ) {
        print BOLD, BLUE, "<$node> ", RESET ;
        print "$1 PE Role|State Update: old role [" ;
        print BOLD, GREEN, "$2", RESET ;
        print "] new [" ;
        print BOLD, YELLOW, "$3", RESET ;
        print "]; old state [" ;
        print BOLD, GREEN, "$4", RESET ;
        print "] new [" ;
        print BOLD, YELLOW, "$5", RESET ;
        print "]\n" ;
      } elsif ( $result eq "" ) {
        print BOLD, BLUE, "<$node> ", RESET ;
        print "PE Role|State: N/A\n" ;
      } else {
        MsgPrint("E", __LINE__ . ": Wrong crsd log format1: $result\n") ;
      }
    } else {
      # ;
    }
  }
  
  print "\n\n\n" ;
}









#==============================================================================
# NAME:
#   Get_CTSS_Master - get CTSS master
# PARAMETERS:
#   None
#RETURNS:
#   None
#==============================================================================
our ($CTSS_Master) ;
sub Get_CTSS_Master
{
  my $ctss_master_key = "is the CTSS master" ;
  
  my (%ctss_master);
  foreach my $node ( @ACTIVE_NODES ) {
    if ( Test_SSH($node) == 0 ) {
      my $cmd = "$SSH $node \"$GREP -h \\\"$ctss_master_key\\\" $ctssd_logfiles | $SORT | $TAIL -1\"" ;
      chomp(my $result = `$cmd`) ;
      MsgPrint("D", "$node: $result\n", __LINE__) ;
      $ctss_master{$node} = $result ;
    } else {
      $ctss_master{$node} = -1 ;
    }
  }
  
  my $max = -1 ;
  foreach my $node ( @ACTIVE_NODES ) {
    if ( $ctss_master{$node} =~ /(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})\.(\d{3}).*ctsselect_msccb\d: (.*) $ctss_master_key$/ ) {
      my $tmp = "$1$2$3$4$5$6$7" ;
      MsgPrint("D", "\$tmp is: $tmp\n", __LINE__) ;
      if ( $max < $tmp ) {
        $max = $tmp ;
        if ( $8 =~ /The local node/ ) {
          $CTSS_Master = $node ;
        } elsif ( $8 =~ /Host \[(.*)\] Node num \[(.*)\]/ ) {
          $CTSS_Master = $ID_NAME{$2} ;
        } else { 
          MsgPrint("E", __LINE__ . ": Wrong octssd log format: $ctss_master{$node}\n") ;
        }
        MsgPrint("D", "$node: $tmp: CTSS Master is $CTSS_Master\n", __LINE__) ;
      }
    }
  }

  defined $CTSS_Master ? 1 : ($CTSS_Master = "N/A") ;
}


#
sub List_CTSS_Master
{
  &Get_CTSS_Master ;
  print BOLD, BLUE, sprintf("%-${ITEM_WID3}s\t", "CTSS Master :"), RESET ;
  print "$CTSS_Master\n\n\n\n" ;
}





#==============================================================================
# NAME:
#   Get_UI_Master - get UI master
# PARAMETERS:
#   None
#RETURNS:
#   None
#==============================================================================
our ($UI_Master) ;
sub Get_UI_Master
{
  my $ui_master_key = "Master change notification has received. New master:" ;
  
  my (%ui_master);
  foreach my $node ( @ACTIVE_NODES ) {
    if ( Test_SSH($node) == 0 ) {
      my $cmd = "$SSH $node \"$GREP -h \\\"$ui_master_key\\\" $crsd_logfiles | $SORT | $TAIL -1\"" ;
      chomp(my $result = `$cmd`) ;
      MsgPrint("D", "$node: $result\n", __LINE__) ;
      $ui_master{$node} = $result ;
    } else {
      $ui_master{$node} = -1 ;
    }
  }
  
  my $max = -1 ;
  foreach my $node ( @ACTIVE_NODES ) {
    if ( $ui_master{$node} =~ /(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})\.(\d{3}).*$ui_master_key (\d*)$/ ) {
      my $tmp = "$1$2$3$4$5$6$7" ;
      MsgPrint("D", "\$tmp is: $tmp\n", __LINE__) ;
      if ( $max < $tmp ) {
        $max = $tmp ;
        $UI_Master = $ID_NAME{$8} ;
        MsgPrint("D", "$node: $tmp: UI Master is $UI_Master\n", __LINE__) ;
      }
    }
  }

  defined $UI_Master ? 1 : ($UI_Master = "N/A") ;
}


#
sub List_UI_Master
{
  &Get_UI_Master ;
  print BOLD, BLUE, sprintf("%-${ITEM_WID3}s\t", "UI Master :"), RESET ;
  print "$UI_Master\n\n\n\n" ;
}





#==============================================================================
# NAME:
#   Get_ONS_Master - get ONS master
# PARAMETERS:
#   None
#RETURNS:
#   None
#==============================================================================
our ($ONS_Master) ;
sub Get_ONS_Master
{
  my $ons_master_key = "ONSPROC CssSemMM::tryMaster I am the master" ;
  
  my (%ons_master);
  foreach my $node ( @ACTIVE_NODES ) {
    if ( Test_SSH($node) == 0 ) {
      my $cmd = "$SSH $node \"$GREP -h \\\"$ons_master_key\\\" $crsd_oraagent_crsowner_logfiles | $SORT | $TAIL -1\"" ;
      chomp(my $result = `$cmd`) ;
      MsgPrint("D", "$node: $result\n", __LINE__) ;
      $ons_master{$node} = $result ;
    } else {
      $ons_master{$node} = -1 ;
    }
  }
  
  my $max = -1 ;
  foreach my $node (@ACTIVE_NODES) {
    if ( $ons_master{$node} =~ /(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})\.(\d{3}).*$ons_master_key$/ ) {
      my $tmp = "$1$2$3$4$5$6$7" ;
      MsgPrint("D", "\$tmp is: $tmp\n", __LINE__) ;
      if ( $max < $tmp ) {
        $max = $tmp ;
        $ONS_Master = $node ;
        MsgPrint("D", "$node: $tmp: ONS Master is $ONS_Master\n", __LINE__) ;
      }
    }
  }

  defined $ONS_Master ? 1 : ($ONS_Master = "N/A") ;
}


#
sub List_ONS_Master
{
  &Get_ONS_Master ;
  print BOLD, BLUE, sprintf("%-${ITEM_WID3}s\t", "ONS Master :"), RESET ;
  print "$ONS_Master\n\n\n\n" ;
}




#==============================================================================
# NAME:
#   Get_ONSNET_Master - get ONSNET master
# PARAMETERS:
#   None
#RETURNS:
#   None
#==============================================================================
our ($ONSNET_Master) ;
sub Get_ONSNET_Master
{
  my $onsnet_master_key = "ONSNETPROC CssSemMM::tryMaster I am the master" ;
  
  my (%onsnet_master);
  foreach my $node ( @ACTIVE_NODES ) {
    if ( Test_SSH($node) == 0 ) {
      my $cmd = "$SSH $node \"$GREP -h \\\"$onsnet_master_key\\\" $crsd_oraagent_crsowner_logfiles | $SORT | $TAIL -1\"" ;
      chomp(my $result = `$cmd`) ;
      MsgPrint("D", "$node: $result\n", __LINE__) ;
      $onsnet_master{$node} = $result ;
    } else {
      $onsnet_master{$node} = -1 ;
    }
  }
  
  my $max = -1 ;
  foreach my $node (@ACTIVE_NODES) {
    if ( $onsnet_master{$node} =~ /(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})\.(\d{3}).*$onsnet_master_key$/ ) {
      my $tmp = "$1$2$3$4$5$6$7" ;
      MsgPrint("D", "\$tmp is: $tmp\n", __LINE__) ;
      if ( $max < $tmp ) {
        $max = $tmp ;
        $ONSNET_Master = $node ;
        MsgPrint("D", "$node: $tmp: ONSNET Master is $ONSNET_Master\n", __LINE__) ;
      }
    }
  }

  defined $ONSNET_Master ? 1 : ($ONSNET_Master = "N/A") ;
}


#
sub List_ONSNET_Master
{
  &Get_ONSNET_Master ;
  print BOLD, BLUE, sprintf("%-${ITEM_WID3}s\t", "ONSNET Master :"), RESET ;
  print "$ONSNET_Master\n\n\n\n" ;
}




#==============================================================================
# NAME:
#   Get_CHM_Master - get CHM master
# PARAMETERS:
#   None
#RETURNS:
#   None
#==============================================================================
our ($CHM_Master) ;
sub Get_CHM_Master
{
  foreach my $node ( @ACTIVE_NODES ) {
    if ( Test_SSH($node) == 0 ) {
      my $cmd = "$SSH $node \"$CRS_HOME/bin/oclumon manage -get MASTER 2>/dev/null\"" ;
      chomp(my $result = `$cmd`) ;
      MsgPrint("D", "$node: $result\n", __LINE__) ;
      if ( $? == 0 ) {
        chomp($CHM_Master = `$ECHO "$result" | $GREP '^Master' | $CUT -d'=' -f2-`) ;
        $CHM_Master = trim($CHM_Master) ;
        last ;
      }
    }
  }

  defined $CHM_Master ? 1 : ($CHM_Master = "N/A") ;
}


#
sub List_CHM_Master
{
  &Get_CHM_Master ;
  print BOLD, BLUE, sprintf("%-${ITEM_WID3}s\t", "CHM Master :"), RESET ;
  print "$CHM_Master\n\n\n\n" ;
}


#==============================================================================
# NAME:
#   Get_CHM_Replica - get CHM master
# PARAMETERS:
#   None
#RETURNS:
#   None
#==============================================================================
our ($CHM_Replica) ;
sub Get_CHM_Replica
{
  Version_Cmp($CRS_SOFTWARE_VERSION, "12.1") >= 0 && ( $CHM_Replica = "REPLICA has been deprecated from 12c" ) && return ;

  foreach my $node ( @ACTIVE_NODES ) {
    if ( Test_SSH($node) == 0 ) {
      my $cmd = "$SSH $node \"$CRS_HOME/bin/oclumon manage -get REPLICA 2>/dev/null\"" ;
      chomp(my $result = `$cmd`) ;
      MsgPrint("D", "$node: $result\n", __LINE__) ;
      if ( $? == 0 ) {
        chomp($CHM_Replica = `$ECHO "$result" | $GREP '^Replica' | $CUT -d'=' -f2-`) ;
        $CHM_Replica = trim($CHM_Replica) ;
        last ;
      }
    }
  }

  defined $CHM_Replica ? 1 : ($CHM_Replica = "N/A") ;
}


#
sub List_CHM_Replica
{
  &Get_CHM_Replica ;
  print BOLD, BLUE, sprintf("%-${ITEM_WID3}s\t", "CHM Replica :"), RESET ;
  print "$CHM_Replica\n\n\n\n" ;
}






our %MISSCOUNTS ;
sub Get_Misscount
{
  foreach ("diagwait", "disktimeout", "misscount", "leafmisscount", "reboottime") {
    chomp(my $result = `$CRS_HOME/bin/crsctl get css $_`) ;
    MsgPrint("D", "the output from \"$CRS_HOME/bin/crsctl get css $_\" is: $result\n", __LINE__) ;
    if ( 0 == $? ) {
      if ( $result =~ /^CRS-4678: Successful get $_ (\d+) for Cluster Synchronization Services.$/ ) {
        $MISSCOUNTS{$_} = $1 ;
      } else {
        MsgPrint("W", "Invalid output format from \"$CRS_HOME/bin/crsctl get css $_\" :\n$result\n$?\n") ;
      }
    } else {
      MsgPrint("W", "Error occurred during running \"$CRS_HOME/bin/crsctl get css $_\" :\n$result\n$?\n") ;
    }
  }
}


my $ITEM_WID4 = 20 ;

#
sub List_Misscount
{
  print BOLD, BLUE, sprintf("%-${ITEM_WID4}s\t", "CSS Diagwait      : "), RESET ;
  print sprintf("%3s", $MISSCOUNTS{"diagwait"}), " s\n" ;
  print BOLD, BLUE, sprintf("%-${ITEM_WID4}s\t", "CSS Disktimeout   : "), RESET ;
  print sprintf("%3s", $MISSCOUNTS{"disktimeout"}), " s\n" ;
  print BOLD, BLUE, sprintf("%-${ITEM_WID4}s\t", "CSS Misscount     : "), RESET ;
  print sprintf("%3s", $MISSCOUNTS{"misscount"}), " s\n" ;
  print BOLD, BLUE, sprintf("%-${ITEM_WID4}s\t", "CSS Leafmisscount : "), RESET ;
  print sprintf("%3s", $MISSCOUNTS{"leafmisscount"}), " s\n" ;
  print BOLD, BLUE, sprintf("%-${ITEM_WID4}s\t", "CSS Reboottime    : "), RESET ;
  print sprintf("%3s", $MISSCOUNTS{"reboottime"}), " s\n" ;
  print "\n\n\n" ;
}






# I - INFO: for normal information, always print to STDOUT
# E - ERROR: for error messages, always print to STDOUT, also the program will exit from this error
# W - WARNING: for warning messages, always print to STDOUT
# S - SUCCESS: for success messages, always print to STDOUT
# D - Debug: for debug only, print to STDOUT only when $debug flag is set
# V - Verbose: for verbose information, print to STDOUT only when $verbose or $debug flag is set
# Note: all kinds of output will also be copied to the log file
sub MsgPrint
{
  my ($type, $msg, $linenum) = @_;
  $linenum = "" unless defined $linenum ;
  
  if ( $type =~ /I/ ) {
    print BOLD, BLUE, "INFO: ", RESET ;
  } elsif ( $type =~ /E/ ) {
    print BOLD, RED, "ERROR: ", RESET ;
  } elsif ( $type =~ /W/ ) {
    print BOLD, MAGENTA, "WARNING: ", RESET ;
  } elsif ( $type =~ /S/ ) {
    print BOLD, GREEN, "SUCCESS: ", RESET ;
  } elsif ( $type =~ /D/ ) {
    print BOLD, YELLOW, sprintf("+[Debug][%8d]: \n", $linenum), RESET if (defined $debug) ;
  } else {
    #print FH "" ;
  }
  
  print "$msg" if ( defined $debug || (defined $verbose && $type =~ /V/) || ($type !~ /D|V/) ) ;
  DieTrap("Exiting...\n") if ($type =~ /E/) ;
}



# All die will come to here, so we can safely remove the lockfile in this routine
sub DieTrap
{
  my ($msg) = @_ ;
  die("$msg") ;
}




# check whether password-less SSH has already existed on some node for $me
# return: TRUE  - password-less SSH has already been set up
#         FALSE - password-less SSH has not been set up yet
sub Test_SSH
{
  my ($node) = @_ ;
  system("$SSH -o FallBackToRsh=no -o PasswordAuthentication=no -o StrictHostKeyChecking=yes -o NumberOfPasswordPrompts=0 $node $DATE >/dev/null 2>&1") ;
  return $? ;
}




# unique a non-unique array, remove duplicate elements
sub unique
{
  my @non_unique_array = @_ ;
  my %seen ;
  my @uniq = grep { ! $seen{$_}++ } @non_unique_array ;
  return @uniq ;
}





# get epoch seconds value for a timestamp string
sub get_epoch_second
{
  my ($timestr) = @_ ; # should be like "Jun 20 23:35:03 2012"
  my %months ; 
  @months{ qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec) } = ( 0..11 ); 
  $timestr =~ /^(\w{3})\s+(\d\d)\s+(\d\d):(\d\d):(\d\d)\s+(\d{4})$/ or MsgPrint("D", "\"$timestr\" is not a valid date\n", __LINE__) ; 
  my $mday = $2; 
  my $mon = exists($months{$1}) ? $months{$1} : MsgPrint("D", "\"$1\" is a bad month\n", __LINE__) ; 
  my $year = $6 - 1900; 
  my ($hh, $mm, $ss) = ($3, $4, $5); 
  return timelocal($ss, $mm, $hh, $mday, $mon, $year) ;
}




our ($CLSUTER_MODE) ;
sub Get_Cluster_Mode
{
  if ( Version_Cmp($CRS_SOFTWARE_VERSION, "12.1") >= 0 ) {
    my $cmd = "$CRS_HOME/bin/crsctl get cluster mode status" ;
    chomp(my $result = `$cmd`) ;
    if ( $result =~ /flex/ ) {
      $CLSUTER_MODE = "Flex Cluster" ;
    } elsif ( $result =~ /standard/ ) {
      $cmd = "$CRS_HOME/bin/srvctl config asm | $GREP '^Cluster ASM listener:'" ;
      chomp($result = `$cmd`) ;
      if ( $result =~ /^Cluster ASM listener:/ ) {
        $CLSUTER_MODE = "Standard Cluster with Flex ASM" ;
      } else {
        $CLSUTER_MODE = "Standard Cluster with Standard ASM" ;
      }
    }
  } else {
    $CLSUTER_MODE = "Standard Cluster" ;
  }
}


#
sub List_Cluster_Mode
{
  print BOLD, BLUE, sprintf("%-${ITEM_WID2}s\t", "Cluster Mode :"), RESET ;
  print "$CLSUTER_MODE\n\n" ;
}





sub Get_Clustername
{
  if ( Version_Cmp($CRS_SOFTWARE_VERSION, "12.1") >= 0 ) {
    my $result = "" ;
    chomp($result = `$CRS_HOME/bin/srvctl config gns -clustername`) ;
    if ( 0 == $? ) {
      $result =~ /^Name of the cluster where GNS is running: (.+)$/ && ($CLUSTER_NAME = $1) ;
    } elsif ( $result =~ /PRKF-1110/ ) {
      1 ;
    } else {
      MsgPrint("W", "Error occurred during running \"$CRS_HOME/bin/srvctl config gns -clustername\" :\n$result\n$?\n") ;
    }
  }
}

#
sub List_Clustername
{
  print BOLD, BLUE, sprintf("%-${ITEM_WID2}s\t","Cluster Name :"), RESET ;
  print "$CLUSTER_NAME\n" ;
}




our ($SCAN_NAME) ;
sub Get_SCAN
{
  my @result = `$CRS_HOME/bin/srvctl config scan` ;
  MsgPrint("D", "the output from \"$CRS_HOME/bin/srvctl config scan\" is: " . join("", @result) . "\n", __LINE__) ;
  chomp(@result) ;

  if ( 0 == $? ) {
    foreach my $line ( @result ) {
      if ( $line =~ /^SCAN name: (\S+), Network: (.+)$/i ) {
        $SCAN_NAME = $1 ;
        last ;
      }
    }
  } else {
    MsgPrint("W", "Error occurred during running \"$CRS_HOME/bin/srvctl config scan\" :\n" . join("\n",@result) . "\n$?\n") ;
  }
}


#
sub List_SCAN
{
  print BOLD, BLUE, sprintf("%-${ITEM_WID2}s\t", "SCAN Name :"), RESET ;
  print "$SCAN_NAME\n" ;
}



our (%SCAN_LISTENERS) ;
sub Get_SCAN_Listener
{
  my @result = `$CRS_HOME/bin/srvctl config scan_listener` ;
  MsgPrint("D", "the output from \"$CRS_HOME/bin/srvctl config scan_listener\" is: " . join("", @result) . "\n", __LINE__) ;
  chomp(@result) ;

  if ( 0 == $? ) {
    foreach my $line ( @result ) {
      if ( $line =~ /^SCAN Listener (.+) exists. Port: (.+)$/i ) {
        $SCAN_LISTENERS{$1} = $2 ;
      }
    }
  } else {
    MsgPrint("W", "Error occurred during running \"$CRS_HOME/bin/srvctl config scan_listener\" :\n" . join("\n",@result) . "\n$?\n") ;
  }
}


#
sub List_SCAN_Listener
{
  print BOLD, BLUE, sprintf("%-${ITEM_WID2}s\t","SCAN Listeners :"), RESET ;
  my @keys = sort keys %SCAN_LISTENERS ;
  my $i = 0 ;
  foreach my $key ( @keys ) {
    if ( 0 == $i ) {
      print "$key (Port: $SCAN_LISTENERS{$key})\n" ;
    } else {
      print sprintf("%-${ITEM_WID2}s\t", ""), "$key (Port: $SCAN_LISTENERS{$key})", "\n" ;
    }
    ++$i ;
  }
}




our ($GNS_CONFIGURED, $GNS_ENABLED, $GNS_RUNNING_NODE, $GNS_VIP, $GNS_VERSION, $GNS_SUBDOMAIN, $GNS_PORT, $GNS_MULTICASTPORT) ;
sub Get_GNS
{ 
  my $result = "" ;
  chomp($result = `$CRS_HOME/bin/srvctl config gns`) ;
  if ( 0 == $? ) {
    $GNS_CONFIGURED = "Y" ;
    $result =~ /enabled/ ? ( $GNS_ENABLED = "Y" ) : ( $GNS_ENABLED = "N" ) ;
    my $result2 = "" ;
    chomp($result2 = `$CRS_HOME/bin/srvctl status gns`) ;
    if ( 0 == $? ) {
      $result2 =~ /^GNS is running on node (.+?)\./ ? ( $GNS_RUNNING_NODE = $1 ) : ( $GNS_RUNNING_NODE = "N/A" ) ;
    } else {
      $GNS_RUNNING_NODE = "N/A" ;
    }
    chomp($GNS_VIP = `$CRS_HOME/bin/crsctl stat res ora.gns.vip -p | $GREP '^USR_ORA_VIP=' | $CUT -d "=" -f2`) ;
    chomp($GNS_VERSION = `$CRS_HOME/bin/srvctl config gns -V | $AWK '{print \$3}'`) ;
    chomp($GNS_SUBDOMAIN = `$CRS_HOME/bin/srvctl config gns -d | $AWK '{print \$5}'`) ;
    chomp($result = `$CRS_HOME/bin/srvctl config gns -p`) ;
    $result =~ /GNS is listening for DNS server requests on port (\d+)/ && ($GNS_PORT = $1) ;
    chomp($result = `$CRS_HOME/bin/srvctl config gns -m`) ;
    $result =~ /GNS is using port (.+) to connect to mDNS/ && ($GNS_MULTICASTPORT = $1) ;
  } else {
    $GNS_CONFIGURED = "N" ;
  }
}


#
sub List_GNS
{
  print BOLD, BLUE, sprintf("%-${ITEM_WID2}s\t","GNS Status :"), RESET ;
  print ($GNS_CONFIGURED eq "Y" ? "configured " . ($GNS_ENABLED eq "Y" ? "and enabled\n" : "but disabled\n") : "not configured\n") ;
  if ( $GNS_CONFIGURED eq "Y" ) {
    print BOLD, BLUE, sprintf("%-${ITEM_WID2}s\t","GNS Running Node :"), RESET ; print "$GNS_RUNNING_NODE\n" ;
    print BOLD, BLUE, sprintf("%-${ITEM_WID2}s\t","GNS Version :"), RESET ; print "$GNS_VERSION\n" ;
    print BOLD, BLUE, sprintf("%-${ITEM_WID2}s\t","GNS VIP :"), RESET ; print "$GNS_VIP\n" ;
    print BOLD, BLUE, sprintf("%-${ITEM_WID2}s\t","GNS Subdomain :"), RESET ; print "$GNS_SUBDOMAIN\n" ;
    print BOLD, BLUE, sprintf("%-${ITEM_WID2}s\t","GNS-to-DNS  Port :"), RESET ; print "$GNS_PORT\n" ;
    print BOLD, BLUE, sprintf("%-${ITEM_WID2}s\t","GNS-to-mDNS Port :"), RESET ; print "$GNS_MULTICASTPORT\n" ;
  }
  print "\n\n\n" ;
}



our (@NODE_VIP_NAMES, @NODE_VIP_ADDRS, @NODE_VIP_VERS) ;
sub Get_Node_VIP
{
  my @result = `$CRS_HOME/bin/crsctl stat res -w "TYPE = ora.cluster_vip_net1.type" -p` ;
  MsgPrint("D", "the output from \"$CRS_HOME/bin/crsctl stat res -w \\\"TYPE = ora.cluster_vip_net1.type\\\" -p\" is: " . join("", @result) . "\n", __LINE__) ;
  chomp(@result) ;

  if ( 0 == $? ) {
    my $i = 0 ;
    foreach my $line ( @result ) {
      if ( $line =~ /^NAME=(.*)$/i ) {
        $NODE_VIP_NAMES[$i] = $1 ;
      } elsif ( $line =~ /^USR_ORA_VIP=(.*)$/i ) {
        $NODE_VIP_ADDRS[$i] = $1 ;
      } elsif ( $line =~ /^VERSION=(.*)$/i ) {
        $NODE_VIP_VERS[$i] = $1 ;
      } elsif ( $line eq "" ) {
        ++$i ;
      }
    }
    MsgPrint("D", "All Node VIP Names: " . join(", ", @NODE_VIP_NAMES) . "\n", __LINE__) ;
    MsgPrint("D", "All Node VIP Addresses: " . join(", ", @NODE_VIP_ADDRS) . "\n", __LINE__) ;
    MsgPrint("D", "All Node VIP Versions: " . join(", ", @NODE_VIP_VERS) . "\n", __LINE__) ;
  } else {
    MsgPrint("W", "Error occurred during running \"$CRS_HOME/bin/crsctl stat res -w \\\"TYPE = ora.cluster_vip_net1.type\\\" -p\" :\n" . join("\n",@result) . "\n$?\n") ;
  }
}


#
sub List_Node_VIP
{
  if ( @NODE_VIP_NAMES ) {
    print BOLD, BLUE, sprintf("%-${ITEM_WID2}s\t","Node VIP Version :"), RESET ;
    defined $NODE_VIP_VERS[0] ? print "$NODE_VIP_VERS[0]\n" : print "$CRS_SOFTWARE_VERSION\n" ;
    print BOLD, BLUE, sprintf("%-${ITEM_WID2}s\t","Local Node VIPs :"), RESET ;

    my @node_vip_addr_length = sort { length($b) <=> length($a) } @NODE_VIP_ADDRS ;
    scalar @node_vip_addr_length && ( my $indent = length( $node_vip_addr_length[0] ) ) ;

    for (my $i=0 ; $i < @NODE_VIP_NAMES ; ++$i) {
      my $text = "$NODE_VIP_NAMES[$i]\t" . sprintf("%-${indent}s\t","$NODE_VIP_ADDRS[$i]") . ($NODE_VIP_ADDRS[$i] =~ /^\d+(\.\d+){3}$/i ? "(dynamic DHCP)" : "(static)") ;
      0 == $i ? print "$text\n" : print sprintf("%-${ITEM_WID2}s\t",""), "$text", "\n" ;
    }

    print "\n\n\n" ;
  }
}




our (@NICS, %NIC_IP, %NIC_SUBNET, %NIC_NETMASK, %NIC_TYPE1, %NIC_TYPE2) ;
sub Get_Interface
{
  my @result = `$CRS_HOME/bin/oifcfg getif` ;
  MsgPrint("D", "the output from \"$CRS_HOME/bin/oifcfg getif\" is: " . join("", @result) . "\n", __LINE__) ;
  chomp(@result) ;

  if ( 0 == $? ) {
    foreach my $line ( @result ) {
      if ( $line =~ /^(\S+)\s+(\S+)\s+(\S+)\s+(\S+)$/ ) {
        push(@NICS, $1) ;
        $NIC_SUBNET{$1} = $2 ;
        $NIC_TYPE1{$1}  = $3 ;
        $NIC_TYPE2{$1}  = $4 ;
        if ( $1 eq '*' ) { $NIC_NETMASK{$1} = "" ; }
      } elsif ( $line =~ /^Only in OCR:|^PRIF-29:/ ) {
        next ;
      } else {
        MsgPrint("W", "Invalid format from \"$CRS_HOME/bin/oifcfg getif\" :\n$line\n") ;
      }
    }
  } else {
    MsgPrint("W", "Error occurred during running \"$CRS_HOME/bin/oifcfg getif\" :\n" . join("\n",@result) . "\n$?\n") ;
  }


  @result = `$CRS_HOME/bin/oifcfg iflist -n` ;
  MsgPrint("D", "the output from \"$CRS_HOME/bin/oifcfg iflist -n\" is: " . join("", @result) . "\n", __LINE__) ;
  chomp(@result) ;

  if ( 0 == $? ) {
    foreach my $line ( @result ) {
      if ( $line =~ /^(\S+)\s+(\S+)\s+(\S+)$/ ) {
        if ( defined $NIC_SUBNET{$1} && $NIC_SUBNET{$1} eq $2 ) {
          $NIC_NETMASK{$1} = $3 ;
        }
      } else {
        MsgPrint("W", "Invalid format from \"$CRS_HOME/bin/oifcfg iflist -n\" :\n$line\n") ;
      }
    }
  } else {
    MsgPrint("W", "Error occurred during running \"$CRS_HOME/bin/oifcfg iflist -n\" :\n" . join("\n",@result) . "\n$?\n") ;
  }


  # get the NIC IP for all kinds of Public/Private/ASM NICs
  foreach my $node ( @CLUSTER_NODES ) {
    if ( Test_SSH($node) == 0 ) {
      foreach my $nic ( @NICS ) {
        chomp( $NIC_IP{$node}{$nic} = 
`case $PLATFORM in
  linux)
    $SSH $node "$IFCONFIG $nic 2>/dev/null | $GREP 'inet addr:' | $CUT -d':' -f2 | $CUT -d' ' -f1" ;;
  solaris)
    $SSH $node "$IFCONFIG $nic 2>/dev/null | $GREP 'inet ' | $CUT -d' ' -f2" ;;
  aix)
    $SSH $node "$IFCONFIG $nic 2>/dev/null | $GREP 'inet ' | $CUT -d' ' -f2" ;;
  hpux)
    $SSH $node "$NETSTAT -in | $GREP -w $nic | $CUT -d' ' -f4" ;;
esac` ) ;
      }
    }
  }
}




sub List_Interface
{
  my $tmp_item_width1 = 3 ;
  map { $tmp_item_width1 = max(length($_), $tmp_item_width1) } @NICS ;
  my $tmp_item_width2 = 15 ;
  print BOLD, BLUE, sprintf("%-${ITEM_WID2}s\t", ""), sprintf("%-${tmp_item_width1}s\t", "NIC"), sprintf("%-${tmp_item_width2}s\t", "Subnet"), sprintf("%-${tmp_item_width2}s\t", "Netmask"), "Type\n", RESET ;
  print BOLD, BLUE, sprintf("%-${ITEM_WID2}s\t", ""), sprintf("%-${tmp_item_width1}s\t", "==="), sprintf("%-${tmp_item_width2}s\t", "======"), sprintf("%-${tmp_item_width2}s\t", "======="), "====\n", RESET ;
  print BOLD, BLUE, sprintf("%-${ITEM_WID2}s\t", "Oracle Interfaces :"), RESET ;
  for (my $i = 0 ; $i < @NICS ; ++$i) {
    $i > 0 && print sprintf("%-${ITEM_WID2}s\t", "") ;
    print sprintf("%-${tmp_item_width1}s\t", "$NICS[$i]"), sprintf("%-${tmp_item_width2}s\t", $NIC_SUBNET{$NICS[$i]}), sprintf("%-${tmp_item_width2}s\t", $NIC_NETMASK{$NICS[$i]}), "$NIC_TYPE1{$NICS[$i]}\t$NIC_TYPE2{$NICS[$i]}\n" ;
  }

  print "\n" ;
  print BOLD, BLUE, sprintf("%-${ITEM_WID2}s\t", ""), (map { sprintf("%-${tmp_item_width2}s\t", $_) } @NICS), "\n", RESET ;
  print BOLD, BLUE, sprintf("%-${ITEM_WID2}s\t", ""), (map { sprintf("%-${tmp_item_width2}s\t", '=' x length($_)) } @NICS), "\n", RESET ;
  foreach ( sort keys %NIC_IP ) {
    print BOLD, BLUE, sprintf("%-${ITEM_WID2}s\t", "$_ :"), RESET ;
    my $tmp_str = "" ;
    foreach my $nic (@NICS) {
      print sprintf("%-${tmp_item_width2}s\t", $NIC_IP{$_}{$nic}) ;
    }
    print "\n" ;
  }
  print "\n\n\n" ;
}





our (@OCR) ;
sub Get_OCR
{
  my @result = `$CRS_HOME/bin/ocrcheck -config` ;
  MsgPrint("D", "the output from \"$CRS_HOME/bin/ocrcheck -config\" is: " . join("", @result) . "\n", __LINE__) ;
  chomp(@result) ;

  if ( 0 == $? ) {
    foreach my $line ( @result ) {
      $line =~ /^\s+Device\/File Name\s+:\s+(\S+)$/ && push(@OCR, $1) ;
    }
  } elsif ( $result[0] =~ /^PROT-605/ ) {
    foreach my $hub ( @HUBS ) {
      if ( Test_SSH($hub) == 0 ) {
        @result = `$SSH $hub "$CRS_HOME/bin/ocrcheck -config"` ;
        MsgPrint("D", "the output from \"$CRS_HOME/bin/ocrcheck -config\" on HUB node <$hub> is: " . join("", @result) . "\n", __LINE__) ;
        chomp(@result) ;
        if ( 0 == $? ) {
          foreach my $line ( @result ) {
            $line =~ /^\s+Device\/File Name\s+:\s+(\S+)$/ && push(@OCR, $1) ;
          }
          last ;
        } else {
          MsgPrint("W", "Error occurred during running \"$CRS_HOME/bin/ocrcheck -config\" on HUB node <$hub> :\n" . join("\n",@result) . "\n$?\n") ;
        }
      }
    }
  } else {
    MsgPrint("W", "Error occurred during running \"$CRS_HOME/bin/ocrcheck -config\" on current node <$HOSTNAME> :\n" . join("\n",@result) . "\n$?\n") ;
  }
}



#
sub List_OCR
{
  print BOLD, BLUE, sprintf("%-${ITEM_WID2}s\t", "OCR Location :"), RESET ;
  for (my $i = 0 ; $i < @OCR ; ++$i) {
    if ( 0 == $i ) {
      print "'$OCR[0]'\n" ;
    } else {
      print sprintf("%-${ITEM_WID2}s\t", ""), "'$OCR[$i]'", "\n" ;
    }
  }
  print "\n\n\n" ;
}




our (@VD) ;
sub Get_VD
{
  my @result = `$CRS_HOME/bin/crsctl query css votedisk` ;
  MsgPrint("D", "the output from \"$CRS_HOME/bin/crsctl query css votedisk\" is: " . join("", @result) . "\n", __LINE__) ;
  chomp(@result) ;

  if ( 0 == $? ) {
    foreach my $line ( @result ) {
      if ( $line =~ /^\s*\d+.*\((.+)\)\s+\[(.+)\]$/ ) {
        ! grep(/^\+$2$/, @VD) && push(@VD, "+$2") ;
      } elsif ( $line =~ /^\s*\d+.*\((.+)\)\s+\[\]$/ ) {
        push(@VD, $1) ;
      }
    }
  } elsif ( $result[0] =~ /^CRS-1668/ ) {
    foreach my $hub ( @HUBS ) {
      if ( Test_SSH($hub) == 0 ) {
        @result = `$SSH $hub "$CRS_HOME/bin/crsctl query css votedisk"` ;
        MsgPrint("D", "the output from \"$CRS_HOME/bin/crsctl query css votedisk\" on HUB node <$hub> is: " . join("", @result) . "\n", __LINE__) ;
        chomp(@result) ;
        if ( 0 == $? ) {
          foreach my $line ( @result ) {
            if ( $line =~ /^\s*\d+.*\((.+)\)\s+\[(.+)\]$/ ) {
              ! grep(/^\+$2$/, @VD) && push(@VD, "+$2") ;
            } elsif ( $line =~ /^\s*\d+.*\((.+)\)\s+\[\]$/ ) {
              push(@VD, $1) ;
            }
          }
          last ;
        } else {
          MsgPrint("W", "Error occurred during running \"$CRS_HOME/bin/crsctl query css votedisk\" on HUB node <$hub> :\n" . join("\n",@result) . "\n$?\n") ;
        }
      }
    }
  } else {
    MsgPrint("W", "Error occurred during running \"$CRS_HOME/bin/crsctl query css votedisk\" on current node <$HOSTNAME> :\n" . join("\n",@result) . "\n$?\n") ;
  }
}


#
sub List_VD
{
  print BOLD, BLUE, sprintf("%-${ITEM_WID2}s\t", "Voting Disk Location :"), RESET ;
  for (my $i = 0 ; $i < @VD ; ++$i) {
    if ( 0 == $i ) {
      print "'$VD[0]'\n" ;
    } else {
      print sprintf("%-${ITEM_WID2}s\t", ""), "'$VD[$i]'", "\n" ;
    }
  }
  print "\n\n\n" ;
}





our (%RIM_HUB_RELATION) ;
sub Get_Rim_Hub_Relation 
{
  foreach my $rim ( @RIMS ) {

    if ( Test_SSH($rim) == 0 ) {

      my $cmd = "$SSH $rim \"$GREP -h 'clssbnmc_PeriodicPing_CB: Sending a ping msg to host ' $cssd_logfiles | $SORT | $TAIL -1\"" ;
      chomp(my $result = `$cmd`) ;
      MsgPrint("D", "$rim: $result\n", __LINE__) ;

      if ( $result =~ /clssbnmc_PeriodicPing_CB: Sending a ping msg to host (\S+), number (\d+), using handle/ ) {
        $RIM_HUB_RELATION{$rim} = $1 ;
        MsgPrint("D", "$rim: $1\n", __LINE__) ;

      } elsif ( $result eq "" ) {
        $cmd = "$SSH $rim \"$GREP -h 'clssscPipeConnect: Successfully connected to node with connection string gipcha' $cssd_logfiles | $SORT | $TAIL -1\"" ;
        chomp(my $result = `$cmd`) ;
        MsgPrint("D", "$rim: $result\n", __LINE__) ;

        if ( $result =~ /clssscPipeConnect: Successfully connected to node with connection string gipcha:\/\/(\S+):/ ) {
          $RIM_HUB_RELATION{$rim} = $1 ;
          MsgPrint("D", "$rim: $1\n", __LINE__) ;
        } elsif ( $result eq "" ) { # if "clssscPipeConnect: Successfully" has already been flushed out in all *cssd.* logs
        
          $cmd = "$SSH $rim \"$GREP -h 'clssscPipeConnect: Initiated connect to node with connection string gipcha://.*:bcm_' $cssd_logfiles | $SORT | $TAIL -1\"" ;
          chomp($result = `$cmd`) ;
          MsgPrint("D", "$rim: $result\n", __LINE__) ;

          if ( $result =~ /clssscPipeConnect: Initiated connect to node with connection string gipcha:\/\/(\S+):bcm_/ ) {
            $RIM_HUB_RELATION{$rim} = $1 ;
            MsgPrint("D", "$rim: $1\n", __LINE__) ;
          } elsif ( $result eq "" ) {

            $cmd = "$SSH $rim \"$GREP -h 'clssgmSendEventsToClients: Group haip.rim.cluster_interconnect.' $cssd_logfiles | $SORT | $TAIL -1\"" ;
            chomp($result = `$cmd`) ;
            MsgPrint("D", "$rim: $result\n", __LINE__) ;

            if ( $result =~ /clssgmSendEventsToClients: Group haip.rim.cluster_interconnect.(\S+), member count/ ) {
              $RIM_HUB_RELATION{$rim} = $1 ;
              MsgPrint("D", "$rim: $1\n", __LINE__) ;
            } elsif ( $result eq "" ) { # if all above logs have been flushed out, find logs like 'clssgmGetMemberAttr:grock #CSS_BCNG memnum 100 attrtype 8 len 4 value (1/1/0x1)' on all active nodes

              foreach my $node ( @ACTIVE_NODES ) {
                $cmd = "$SSH $node \"$GREP -h 'clssgmGetMemberAttr:grock #CSS_BCNG memnum $NODE_ID{$rim} attrtype' $cssd_logfiles | $SORT | $TAIL -1\"" ;
                chomp($result = `$cmd`) ;
                MsgPrint("D", "$rim: $node: $result\n", __LINE__) ;
                if ( $result =~ /clssgmGetMemberAttr:grock #CSS_BCNG memnum $NODE_ID{$rim} attrtype \d+ len \d+ value \((\d+)\// ) {
                  $RIM_HUB_RELATION{$rim} = $ID_NAME{$1} ;
                  MsgPrint("D", "$rim --> $1($ID_NAME{$1})\n", __LINE__) ;
                  last ;
                }
              }
            } else {
              MsgPrint("E", __LINE__ . ": Wrong ocssd log format4: $result\n") ;
            }

          } else {
            MsgPrint("E", __LINE__ . ": Wrong ocssd log format3: $result\n") ;
          }
          
        } else {
          MsgPrint("E", __LINE__ . ": Wrong ocssd log format2: $result\n") ;
        }

      } else {
        MsgPrint("E", __LINE__ . ": Wrong ocssd log format1: $result\n") ;
      }

    } # end of if ( Test_SSH($rim) == 0 )

  } # end of foreach my $rim ( @RIMS ) {
}



#
sub List_Rim_Hub_Relation 
{
  print BOLD, BLUE, sprintf("%-35s\t", "Hub Node"), sprintf("%-27s\t", "connects"), rtrim(sprintf("%-20s\t", "Leaf Node")), "\n", RESET;
  print BOLD, BLUE, sprintf("%-35s\t", "========"), sprintf("%-27s\t", "========"), rtrim(sprintf("%-20s\t", "=========")), "\n", RESET ;

  foreach my $hub ( @HUBS ) {
    my @my_rims = () ;
    foreach (keys %RIM_HUB_RELATION) {
      if ( $RIM_HUB_RELATION{$_} eq $hub ) {
        push(@my_rims, "$_($NODE_ID{$_},$NODE_STATE{$_})") ;
      }
    }
    my $my_rims = scalar @my_rims > 0 ? join(",", @my_rims) : "None" ;
    print BOLD, sprintf("%-35s\t", "$hub($NODE_ID{$hub},$NODE_STATE{$hub})") . sprintf("%-27s\t", "<---") . rtrim(sprintf("%-20s\t", "$my_rims")) . "\n", RESET ;
  }


  # preventive programming here: for any hub node which appears in %RIM_HUB_RELATION but does appear in @HUBS
  foreach my $tmp (values %RIM_HUB_RELATION) {
    if ( ! grep(/^$tmp$/, @HUBS) ) {
      my @my_rims = () ;
      foreach (keys %RIM_HUB_RELATION) {
        if ( $RIM_HUB_RELATION{$_} eq $tmp ) {
          push(@my_rims, "$_($NODE_ID{$_},$NODE_STATE{$_})") ;
        }
      }
      print RED, sprintf("%-35s\t", "$tmp($NODE_ID{$tmp},$NODE_STATE{$tmp})") . sprintf("%-27s\t", "<---") . rtrim(sprintf("%-20s\t", join(",", @my_rims))) . "\n", RESET ;
    }
  }

  
  # preventive programming here: for any rim node not listed in %RIM_HUB_RELATION
  foreach my $tmp (@RIMS) {
    if ( ! grep(/^$tmp$/, keys %RIM_HUB_RELATION) ) {
      print RED, sprintf("%-35s\t", "N/A") . sprintf("%-27s\t", "<---") . rtrim(sprintf("%-20s\t", "$tmp($NODE_ID{$tmp},$NODE_STATE{$tmp})")) . "\n", RESET ;
    }
  }
  
  print "\n\n\n" ;
}





our (@DG_DETAILS) ;
sub Get_ASM_DG_Disk
{
  foreach my $hub ( @HUBS ) { # only Hub node could have an ASM instance running
    if ( defined $ASM_INST{$hub} && Test_SSH($hub) == 0 ) {
      my $cmd = "$SSH $hub \"export ORACLE_SID=$ASM_INST{$hub} ; export ORACLE_HOME=$CRS_HOME ; $CRS_HOME/bin/sqlplus -S '/ as sysasm' <<_EOF
col Diskgroup for a14 justify left ;
col Redundancy for a10 justify left ;
col AU for a4 justify left ;
col compatibility for a13 justify left ;
col db_compatibility for a16 justify left ;
col Size_MB justify right ;
col Free_MB justify right ;
col Usable_MB justify right ;
col Path for a40 justify left ;
set linesize 9999 ;
set pagesize 9999 ;
select dg.name as Diskgroup, dg.type as Redundancy, allocation_unit_size/1024/1024||'MB' as AU, compatibility, database_compatibility as db_compatibility, round(dg.TOTAL_MB) as Size_MB, round(dg.FREE_MB) as Free_MB, round(dg.USABLE_FILE_MB) as Usable_MB, disk.path as Path from v\\\\\\\$asm_disk disk, v\\\\\\\$asm_diskgroup dg where dg.state='MOUNTED' and dg.group_number=disk.group_number order by dg.name ;
_EOF
\"" ;
      chomp(my @result = `$cmd`) ;
      MsgPrint("D", "Result from ASM SQL: " . join("\n", @result) . "\n", __LINE__) ;
      if ( 0 == $? ) {
        if ( $result[-2] =~ /\d+ rows selected/i || $result[1] =~ /^\s*DISKGROUP\s+REDUNDANCY\s+AU\s+/i ) { # if the SQL is executed successfully
          $result[0] eq "" && shift(@result) ;
          if ( $result[-2] =~ /\d+ rows selected/i ) { pop(@result) ; pop(@result) }
          my $num = 0 ;
          foreach my $line ( @result ) {
            MsgPrint("D", "A line from ASM SQL is: $line\n", __LINE__) ;
            if ( $line =~ /^(\S+)\s+(\S+)\s+(\d+MB)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)$/ ) {
              $DG_DETAILS[$num][0] = $1 ;
              $DG_DETAILS[$num][1] = $2 ;
              $DG_DETAILS[$num][2] = $3 ;
              $DG_DETAILS[$num][3] = $4 ;
              $DG_DETAILS[$num][4] = $5 ;
              $DG_DETAILS[$num][5] = $6 ;
              $DG_DETAILS[$num][6] = $7 ;
              $DG_DETAILS[$num][7] = $8 ;
              $DG_DETAILS[$num][8] = $9 ;
              # append AFD label paths like AFD:XXX with the actual underneath disks
              if ( $DG_DETAILS[$num][8] =~ /^AFD:(.*)$/ ) {
                chomp(my $afd_labeled_disk = `$CRS_HOME/bin/afdtool -getdevlist -nohdr | $GREP "^$1 " | $AWK '{print \$2}'`) ;
                $DG_DETAILS[$num][8] .= " -> $afd_labeled_disk" ;
              }
              ++$num ;
            }
          }
          last ;
        }
      } else {
        MsgPrint("W", "ASM SQL failed on node <$hub> : $?\n", __LINE__) ;
      }
    }
  }
}


#
sub List_ASM_DG_Disk
{
  if ( @DG_DETAILS ) {
    my $COL_WID0 = 9 ;
    my $COL_WID1 = 10 ;
    my $COL_WID2 = 4 ;
    my $COL_WID3 = 13 ;
    my $COL_WID4 = 16 ;
    my $COL_WID5 = 7 ;
    my $COL_WID6 = 7 ;
    my $COL_WID7 = 9 ;
    my $COL_WID8 = 4 ;
  
    print BOLD, BLUE, sprintf("%-${COL_WID0}s\t", "DISKGROUP"), 
                      sprintf("%-${COL_WID1}s\t", "REDUNDANCY"), 
                      sprintf("%-${COL_WID2}s\t", "AU"), 
                      sprintf("%-${COL_WID3}s\t", "COMPATIBILITY"),
                      sprintf("%-${COL_WID4}s\t", "DB_COMPATIBILITY"),
                      sprintf("%-${COL_WID5}s\t", "SIZE_MB"),
                      sprintf("%-${COL_WID6}s\t", "FREE_MB"),
                      sprintf("%-${COL_WID7}s\t", "USABLE_MB"), 
                      rtrim(sprintf("%-${COL_WID8}s\t", "PATH")), "\n", RESET ;
    print BOLD, BLUE, sprintf("%-${COL_WID0}s\t","========="),
                      sprintf("%-${COL_WID1}s\t", "=========="),
                      sprintf("%-${COL_WID2}s\t", "===="),
                      sprintf("%-${COL_WID3}s\t", "============="),
                      sprintf("%-${COL_WID4}s\t", "================"),
                      sprintf("%-${COL_WID5}s\t", "======="),
                      sprintf("%-${COL_WID6}s\t", "======="),
                      sprintf("%-${COL_WID7}s\t", "========="),
                      rtrim(sprintf("%-${COL_WID8}s\t", "====")), "\n", RESET ;

    for( my $i=0 ; $i<@DG_DETAILS ; $i++ ) {
      if ( $i >= 1 && $DG_DETAILS[$i][0] eq $DG_DETAILS[$i-1][0] ) {
        my $head_wid0 = max($COL_WID0, length($DG_DETAILS[$i][0])) ;
        my $head_wid1 = max($COL_WID1, length($DG_DETAILS[$i][1])) ;
        my $head_wid2 = max($COL_WID2, length($DG_DETAILS[$i][2])) ;
        my $head_wid3 = max($COL_WID3, length($DG_DETAILS[$i][3])) ;
        my $head_wid4 = max($COL_WID4, length($DG_DETAILS[$i][4])) ;
        my $head_wid5 = max($COL_WID5, length($DG_DETAILS[$i][5])) ;
        my $head_wid6 = max($COL_WID6, length($DG_DETAILS[$i][6])) ;
        my $head_wid7 = max($COL_WID7, length($DG_DETAILS[$i][7])) ;

        print BOLD, sprintf("%-${head_wid0}s\t", ""),
                    sprintf("%-${head_wid1}s\t", ""),
                    sprintf("%-${head_wid2}s\t", ""),
                    sprintf("%-${head_wid3}s\t", ""),
                    sprintf("%-${head_wid4}s\t", ""),
                    sprintf("%-${head_wid5}s\t", ""),
                    sprintf("%-${head_wid6}s\t", ""),
                    sprintf("%-${head_wid7}s\t", "") ;
      } else {
        print BOLD, sprintf("%-${COL_WID0}s\t", "$DG_DETAILS[$i][0]"),
                    sprintf("%-${COL_WID1}s\t", "$DG_DETAILS[$i][1]"),
                    sprintf("%-${COL_WID2}s\t", "$DG_DETAILS[$i][2]"),
                    sprintf("%-${COL_WID3}s\t", "$DG_DETAILS[$i][3]"),
                    sprintf("%-${COL_WID4}s\t", "$DG_DETAILS[$i][4]"),
                    sprintf("%-${COL_WID5}s\t", "$DG_DETAILS[$i][5]"),
                    sprintf("%-${COL_WID6}s\t", "$DG_DETAILS[$i][6]"),
                    sprintf("%-${COL_WID7}s\t", "$DG_DETAILS[$i][7]") ;
      }
      print rtrim(sprintf("%-${COL_WID8}s\t", "$DG_DETAILS[$i][8]")), "\n", RESET ;
    }

    print "\n\n\n" ;
  }
}






our (@VOLUME_DETAILS) ;
sub Get_ACFS_VOLUME
{
  foreach my $hub ( @HUBS ) { # only Hub node could have an ASM instance running
    if ( defined $ASM_INST{$hub} && Test_SSH($hub) == 0 ) {
      my $cmd = "$SSH $hub \"export ORACLE_SID=$ASM_INST{$hub} ; export ORACLE_HOME=$CRS_HOME ; $CRS_HOME/bin/sqlplus -S '/ as sysasm' <<_EOF
col Volume_Name for a14 justify left ;
col VOlume_Device for a32 justify left ;
col DG_Name for a12 justify left ;
col Usage for a12 justify left ;
col Mountpoint for a20 justify left ;
col Vol_Size_MB justify right ;
set linesize 9999 ;
set pagesize 9999 ;
select unique vol.VOLUME_NAME, vol.VOLUME_DEVICE, dg.NAME as DG_Name, nvl(vol.MOUNTPATH, 'USMCA_NULL') as Mountpoint, nvl(vol.USAGE, 'USMCA_NULL') as Usage, round(nvl(vol.SIZE_MB,0)) as Vol_Size_MB from gv\\\\\\\$asm_volume vol, gv\\\\\\\$asm_diskgroup dg where vol.GROUP_NUMBER = dg.GROUP_NUMBER order by dg.NAME ;
_EOF
\"" ;
      chomp(my @result = `$cmd`) ;
      MsgPrint("D", "Result from ASM SQL: " . join("\n", @result) . "\n", __LINE__) ;
      if ( 0 == $? ) {
        if ( $result[-2] eq "no rows selected" || $result[-2] =~ /\d+ rows selected/i || $result[1] =~ /^\s*VOLUME_NAME\s+VOLUME_DEVICE\s+DG_NAME\s+/i ) { # if the SQL is executed successfully
          $result[0] eq "" && shift(@result) ;
          if ( $result[-2] =~ /\d+ rows selected/i ) { pop(@result) ; pop(@result) }
          my $num = 0 ;
          foreach my $line ( @result ) {
            MsgPrint("D", "A line from ASM SQL is: $line\n", __LINE__) ;
            if ( $line =~ /^(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\d+)$/ ) {
              $VOLUME_DETAILS[$num][0] = $1 ;
              $VOLUME_DETAILS[$num][1] = $2 ;
              $VOLUME_DETAILS[$num][2] = $3 ;
              $VOLUME_DETAILS[$num][3] = $4 ;
              $VOLUME_DETAILS[$num][4] = $5 ;
              $VOLUME_DETAILS[$num][5] = $6 ;
              ++$num ;
            }
          }
          last ;
        }
      } else {
        MsgPrint("W", "ASM SQL failed on node <$hub> : $?\n", __LINE__) ;
      }
    }
  }
}



#
sub List_ACFS_VOLUME
{
  if ( @VOLUME_DETAILS ) {
    my $COL_WID1 = 12 ;
    my $COL_WID2 = 25 ;
    my $COL_WID3 = 12 ;
    my $COL_WID4 = 20 ;
    my $COL_WID5 = 15 ;
    my $COL_WID6 = 12 ;
  
    print BOLD, BLUE, sprintf("%-${COL_WID1}s\t", "VOLUME_NAME"),
                      sprintf("%-${COL_WID2}s\t", "VOLUME_DEVICE"),
                      sprintf("%-${COL_WID3}s\t", "DG_NAME"),
                      sprintf("%-${COL_WID4}s\t", "MOUNTPOINT"),
                      sprintf("%-${COL_WID5}s\t", "USAGE"),
                      rtrim(sprintf("%-${COL_WID6}s\t", "VOL_SIZE_MB")), "\n", RESET ;
    print BOLD, BLUE, sprintf("%-${COL_WID1}s\t","==========="),
                      sprintf("%-${COL_WID2}s\t", "============="),
                      sprintf("%-${COL_WID3}s\t", "======="),
                      sprintf("%-${COL_WID4}s\t", "=========="),
                      sprintf("%-${COL_WID5}s\t", "====="),
                      rtrim(sprintf("%-${COL_WID6}s\t", "===========")), "\n", RESET ;

    for( my $i=0 ; $i<@VOLUME_DETAILS ; $i++ ) {
      print BOLD, sprintf("%-${COL_WID1}s\t", "$VOLUME_DETAILS[$i][0]"),
                  sprintf("%-${COL_WID2}s\t", "$VOLUME_DETAILS[$i][1]"),
                  sprintf("%-${COL_WID3}s\t", "$VOLUME_DETAILS[$i][2]"),
                  sprintf("%-${COL_WID4}s\t", "$VOLUME_DETAILS[$i][3]"),
                  sprintf("%-${COL_WID5}s\t", "$VOLUME_DETAILS[$i][4]"),
                  rtrim(sprintf("%-${COL_WID6}s\t", "$VOLUME_DETAILS[$i][5]")), "\n", RESET ;
    }

    print "\n\n\n" ;
  }
}







#
our (@ASM_CLIENT) ;
sub Get_ASM_Client
{
  foreach my $hub ( @HUBS ) { # only Hub node could have an ASM instance running
    if ( defined $ASM_INST{$hub} && Test_SSH($hub) == 0 ) {
      my $cmd = "$SSH $hub \"export ORACLE_SID=$ASM_INST{$hub} ; export ORACLE_HOME=$CRS_HOME ; $CRS_HOME/bin/sqlplus -S '/ as sysasm' <<_EOF
rem col host_name for a30 ;
rem col instance_name for a30 ;
rem col db_name for a30 ;
set linesize 9999 ;
set pagesize 9999 ;
select distinct i.host_name,i.instance_name,i.instance_number,i.status,a.instance_name,a.db_name,a.status from gv\\\\\\\$instance i left join gv\\\\\\\$asm_client a on i.instance_number=a.inst_id order by i.host_name,a.instance_name ;
_EOF
\"" ;
      chomp(my @result = `$cmd`) ;
      MsgPrint("D", "Result from ASM SQL: " . join("\n", @result) . "\n", __LINE__) ;
      if ( 0 == $? ) {
        if ( $result[-2] =~ /\d+ rows selected/i || $result[1] =~ /^HOST_NAME\s+INSTANCE_NAME\s+INSTANCE_NUMBER\s+STATUS\s+INSTANCE_NAME/i ) { # if the SQL is executed successfully
          my $num = 0 ;
          foreach my $line ( @result ) {
            MsgPrint("D", "A line from ASM SQL is: $line\n", __LINE__) ;
            if ( $line =~ /^(\S+)\s+(\S+)\s+(\d+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)$/ ) {
              $ASM_CLIENT[$num][0] = $1 ;
              $ASM_CLIENT[$num][1] = $2 ;
              $ASM_CLIENT[$num][2] = $3 ;
              $ASM_CLIENT[$num][3] = $4 ;
              $ASM_CLIENT[$num][4] = $5 ;
              $ASM_CLIENT[$num][5] = $6 ;
              $ASM_CLIENT[$num][6] = $7 ;
              ++$num ;
            } elsif ( $line =~ /^(\S+)\s+(\S+)\s+(\d+)\s+(\S+)$/ ) {
              $ASM_CLIENT[$num][0] = $1 ;
              $ASM_CLIENT[$num][1] = $2 ;
              $ASM_CLIENT[$num][2] = $3 ;
              $ASM_CLIENT[$num][3] = $4 ;
              $ASM_CLIENT[$num][4] = "None" ;
              $ASM_CLIENT[$num][5] = "None" ;
              $ASM_CLIENT[$num][6] = "None" ;
              ++$num ;
            }
          }
          last ;
        }
      } else {
        MsgPrint("W", "ASM SQL failed on node <$hub> : $?\n", __LINE__) ;
      }
    }
  }
}





#
sub List_ASM_Client
{
  print BOLD, BLUE, sprintf("%-35s\t","ASM Host"), sprintf("%-27s\t", "connects"), rtrim(sprintf("%-20s\t", "Client")), "\n", RESET;
  print BOLD, BLUE, sprintf("%-35s\t","========"), sprintf("%-27s\t", "========"), rtrim(sprintf("%-20s\t", "======")), "\n", RESET ;
  
  my $new_node ;
  for ( my $i = 0 ; $i < @ASM_CLIENT ; ++$i ) {
    print "\n" if ( defined $new_node && lc($new_node) ne lc($ASM_CLIENT[$i][0]) ) ;
    $new_node = $ASM_CLIENT[$i][0] ;

    print BOLD, sprintf("%-35s\t", "$ASM_CLIENT[$i][0]($ASM_CLIENT[$i][1])") . sprintf("%-27s\t", "<---") ;
    if ( defined $Instance_Running_On_Node{$ASM_CLIENT[$i][4]} ) {
      print rtrim(sprintf("%-20s\t", "'$ASM_CLIENT[$i][4]($Instance_Running_On_Node{$ASM_CLIENT[$i][4]})'")) . "\n", RESET ;
    } else {
      print rtrim(sprintf("%-20s\t", "'$ASM_CLIENT[$i][4]'")) . "\n", RESET ;
    }
  }
  
  print "\n\n\n" ;
}





#
sub Get_OCR_Connection
{
  my ($node) = @_ ;
  my $ocr_connect_to ;
  
  if ( Test_SSH($node) == 0 ) {
    
    if ( $NODE_ROLE{$node} eq "Hub" ) {
    
      # Firstly, get the pid of crsd.bin on $node
      my $cmd = "$SSH $node \"$PSEF | $GREP crsd.bin | $GREP -v grep | $AWK '{print \\\$2}'\"" ;
      chomp(my $crsd_pid = `$cmd`) ;
      MsgPrint("D", "$node: $crsd_pid\n", __LINE__) ;
      if ( 0 == $? && $crsd_pid =~ /^\d+$/ ) {

        MsgPrint("D", "pid of crsd.bin on $node: $crsd_pid\n", __LINE__) ;
        
        # Secondly, visit ASM alert log on all HUB nodes one by one to find OCR connection
        my $max = -1 ;
        foreach my $remote_node ( @HUBS ) {
          if ( $remote_node eq $node || ( $remote_node ne $node && Test_SSH($remote_node) == 0 ) ) {
            $cmd = "$SSH $remote_node \"[ -d $CRS_BASE/diag/asm/+asm/ ] && $SED -n -e 'N;/crsd.bin.*TNS V1-V3.*$crsd_pid\] opening OCR file/P;D' -e 'N;/NOTE: client exited .$crsd_pid\]/P;D' $CRS_BASE/diag/asm/+asm/+ASM*/trace/alert_*.log\"" ;
            MsgPrint("D", "\$cmd to run on $remote_node is: $cmd\n", __LINE__) ;
            chomp(my @result = `$cmd`) ;
            MsgPrint("D", "$remote_node: \n" . join("\n", @result) . "\n", __LINE__) ;
            if ( defined $result[-1] && $result[-1] =~ /^NOTE: \[crsd\.bin\@$node.*\(TNS V1-V3.*$crsd_pid\] opening OCR file/i ) {
            
              if ( defined $result[-2] && $result[-2] =~ /^\S+ (\S+ \d\d \d\d:\d\d:\d\d \d{4})$/ ) {
                my $timestr = $1 ;
                MsgPrint("D", "\$timestr is: $timestr\n", __LINE__) ;
                my $epoch_seconds = get_epoch_second($timestr) ;
                MsgPrint("D", "\$epoch_seconds is: $epoch_seconds\n", __LINE__) ;
                if ( $epoch_seconds > $max ) {
                  $max = $epoch_seconds ;
                  $ocr_connect_to = $remote_node ;
                  MsgPrint("D", "OCR on $node connects to $ocr_connect_to\n", __LINE__) ;
                } elsif ( $epoch_seconds == $max ) {
                  defined $ocr_connect_to ? ( $ocr_connect_to .= ",$remote_node" ) : ( $ocr_connect_to = $remote_node ) ;
                  MsgPrint("D", "OCR on $node connects to $ocr_connect_to\n", __LINE__) ;                  
                }
              } else {
                MsgPrint("D", __LINE__ . ": Wrong ASM alert log format: $result[-2]\n") ;
                $ocr_connect_to = $remote_node ;
                MsgPrint("D", "OCR on $node connects to $ocr_connect_to\n", __LINE__) ;
              }
            
            }
          } else { # password-less SSH not available
            # do nothing
          }
        }

      } else { # can't get the crsd.bin pid
        MsgPrint("W", "cann't get crsd.bin pid on $node: $crsd_pid\n") ;
      }
      
      defined $ocr_connect_to ? 1 : ($ocr_connect_to = "N/A") ;

    } elsif ( $NODE_ROLE{$node} eq "Leaf" ) {

      my $cmd = "$SSH $node \"$GREP -h '.*OCRMAS.*th_rim_elect_new_anchor:.*SUCCESSFULLY CONNECTED TO THE OCR ANCHOR' $crsd_logfiles | $TAIL -1\"" ;
      chomp(my $result = `$cmd`) ;
      MsgPrint("D", "$node: $result\n", __LINE__) ;
      if ( $result =~ /.*OCRMAS.*th_rim_elect_new_anchor:\d+: SUCCESSFULLY CONNECTED TO THE OCR ANCHOR \[(\d+)\]/ ) {
        defined $ocr_connect_to ? $ocr_connect_to .= ",$ID_NAME{$1}" : $ocr_connect_to = $ID_NAME{$1} ;
        MsgPrint("D", "OCR on $node connects to $ocr_connect_to\n", __LINE__) ;
      } else {
        MsgPrint("D", "Wrong crsd log format2: $result\n", __LINE__) ;
        $ocr_connect_to = "N/A" ;
      }
      
    } else { # preventive programming here
      MsgPrint("E", __LINE__ . ": you shouldn't have arrived here, please contact the script author.\n") ;   
    }

  } else { # password-less SSH not available
    $ocr_connect_to = "N/A" ;
  }

  return $ocr_connect_to ;
}




#
sub List_OCR_Connection
{
  print BOLD, BLUE, sprintf("%-35s\t","OCR Local/Writer"), sprintf("%-27s\t", "connects"), rtrim(sprintf("%-20s\t", "ASM Instance")), "\n", RESET;
  print BOLD, BLUE, sprintf("%-35s\t","================"), sprintf("%-27s\t", "========"), rtrim(sprintf("%-20s\t", "============")), "\n", RESET ;


  foreach my $node ( @HUBS ) {
    if ( $NODE_STATE{$node} eq "Active" ) {
      # Get the OCR connection for $node
      my $ocr_connect_to = Get_OCR_Connection($node) ;

      my $ocr_role = ( $node =~ /^$OCR_MASTER$/i ? "OCR Writer" : "OCR Local" ) ;
      MsgPrint("D", "ocr_role on $node is : $ocr_role\n", __LINE__) ;
      if ( $ocr_connect_to !~ /,|N\/A/ ) {
        print BOLD, sprintf("%-35s\t", ( Version_Cmp($CRS_SOFTWARE_VERSION, "12.1") >= 0 ? "$node(Hub,$ocr_role)" : "$node($ocr_role)")) . sprintf("%-27s\t", "--->") . rtrim(sprintf("%-20s\t", "$ocr_connect_to($ASM_INST{$ocr_connect_to})")) . "\n", RESET ;
      } else {
        print RED, sprintf("%-35s\t", ( Version_Cmp($CRS_SOFTWARE_VERSION, "12.1") >= 0 ? "$node(Hub,$ocr_role)" : "$node($ocr_role)")) . sprintf("%-27s\t", "--->") . rtrim(sprintf("%-20s\t", "$ocr_connect_to")) . "\n", RESET ;
      }
    }
  }


  foreach my $node ( @RIMS ) {
    if ( $NODE_STATE{$node} eq "Active" ) {
      # Get the OCR connection for $node
      my $ocr_connect_to = Get_OCR_Connection($node) ;
      if ( $ocr_connect_to !~ /,|N\/A/ ) {
        print BOLD, sprintf("%-35s\t", "$node(Leaf,OCR Local)") . sprintf("%-27s\t", "--->") . rtrim(sprintf("%-20s\t", "$ocr_connect_to($ASM_INST{$ocr_connect_to})")) . "\n", RESET ;
      } else {
        print RED, sprintf("%-35s\t", "$node(Leaf,OCR Local)") . sprintf("%-27s\t", "--->") . rtrim(sprintf("%-20s\t", "$ocr_connect_to")) . "\n", RESET ;
      }
    }
  }
  
  print "\n\n\n" ;
}







MAIN: {

  &ParseArgs ;

  &now ;

  &Get_RAC_Environment ;
  &Get_All_DB ;
  &List_DB_Detail ;

  (getpwuid($<))[0] eq $CRS_OWNER or die "ERROR: Please run the script as CRS Owner <$CRS_OWNER> !\n" ;

  &Olsnodes ;

  &Get_ASM_APX_Instance ;


  unless ( defined $master ) {  
    &Get_Clustername ; &List_Clustername ;

    &Get_SCAN ; &List_SCAN ;

    &Get_SCAN_Listener ; &List_SCAN_Listener ;

    &Get_GNS ; &List_GNS ;

    &Get_Node_VIP ; &List_Node_VIP ;

    &Get_Interface ; &List_Interface ;

    &Get_OCR ; &List_OCR ;

    &Get_VD ; &List_VD ;

    if ( Version_Cmp($CRS_SOFTWARE_VERSION, "12.1") >= 0 ) {
      &Get_Cluster_Mode ; &List_Cluster_Mode ;

      if ( ! defined $static || defined $full ) { &Get_Rim_Hub_Relation ; &List_Rim_Hub_Relation ; }

      &Get_MGMTDB ; &List_MGMTDB ;
      &Get_MGMTLSNR ; &List_MGMTLSNR ;

      &Get_ASMNETLSNR ; &List_ASMNETLSNR ;
    }
    
    &Get_ASM_DG_Disk ; &List_ASM_DG_Disk ;

    &Get_ACFS_VOLUME ; &List_ACFS_VOLUME ;

    if ( ! defined $static || defined $full ) { &Get_ASM_Client ; &List_ASM_Client ; }
  }


  if ( defined $master || ! defined $static || defined $full ) {
    &List_CSS_Master ;

    &List_OCR_Master ;

    &List_PE_Master ;

    Version_Cmp($CRS_SOFTWARE_VERSION, "12.1") >= 0 && &List_PE_Standby ;

    if ( defined $verbose ) {
      Version_Cmp($CRS_SOFTWARE_VERSION, "12.1") >= 0 && &List_OCR_Rank ;
      &List_PE_Role_State ;
    }

    &List_CTSS_Master ;
    &List_UI_Master ;
    &List_ONS_Master ;
    &List_ONSNET_Master ;
    &List_CHM_Master ;
    &List_CHM_Replica ;

    if ( defined $verbose ) {
      &Get_Misscount ; &List_Misscount ;
    }
  }


  unless ( defined $master ) {
    ( ! defined $static || defined $full ) && &List_OCR_Connection ;
  }

}





1;
__END__


