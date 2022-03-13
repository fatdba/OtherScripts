#!/usr/local/bin/perl
#
# $Header: exadataDiscoveryPreCheck.pl /main/1 2012/01/06 12:14:53 dyue Exp $
#
# exadataDiscoveryPreCheck.pl
#
# Copyright (c) 2002, 2012, Oracle and/or its affiliates. All rights reserved.
#
#    NAME
#      exadataDiscoveryCommon.pl - <one-line expansion of the name>
#
#    DESCRIPTION
#      <short description of component this file declares/defines>
#
#    NOTES
#      <other useful comments, qualifications, etc.>
#
#    MODIFIED   (MM/DD/YY)
#     proldan    03/05/13 - Extend cipher, ipmitool and consistency checks
#

use strict;
#use warnings;
#use diagnostics;
use Cwd;
use File::Basename;
use Getopt::Long;
use IO::File;
use IPC::Open2;
use Net::Domain qw(hostdomain);
use Time::localtime;

=head1 SCRIPT NAME

exadataDiscoveryPreCheck.pl

=head1 DESCRIPTION

The script is used to verify Exadata configuration.
It will run required pre-checks prior to running discovery.

The following methods are available:

=cut

my $debug;
my $interactive;
my $oh;
my $ot;
my $sc;
my $sch;
my $typ;
my %opt;

=head2 S<parseOptions($options)>

This subroutine parses command line options passed to the script.
Argument indicates whether to show command line options or not.

=cut

sub parseOptions
{ my ($options) = @_;
  &GetOptions (\%opt, "aid=s","cePass=s","coPass=s",
                      "d","h","i=s","ibPass=s","log=s",
                      "oh=s","ot=s","q","sc=i","typ=i");
  if ($opt{'h'})
  { print <<"EOF";

Usage: exadataDiscoveryPreCheck.pl [-d] [-h] [-q] [-aid dir] [-cePass password]
                                   [-coPass password] [-i file]
                                   [-ibPass password] [-log file] [-oh dir]
                                   [-ot file] [-sc integer] [-typ integer]

        -aid dir          Agent installation directory
        -cePass password  Generic cell node password
        -coPass password  Generic compute node password
        -d                Set debug mode
        -h                Help
        -i file           Input file
        -ibPass password  Generic infiniband switch password
        -log file         Log file
        -oh dir           ORACLE_HOME directory
        -ot file          Oratab file
        -q                Set quiet mode (non interactive)
        -sc               Skip cipher check (0->Force or 1->Skip cipher check)
        -typ integer      Schematic file type (1->catalog or 2->databasemachine)

EOF
    exit(0);
  }
  if ($opt{'d'})
  { $debug = 1;
  }
  else
  { $debug = 0;
  }
  if (defined($opt{'typ'}) && $opt{'typ'} == 2)
  { $sch = "/opt/oracle.SupportTools/onecommand/databasemachine.xml";
    $typ = 2;
  }
  else
  { $sch = "/opt/oracle.SupportTools/onecommand/catalog.xml";
    $typ = 1;
  }
  if ($opt{'q'})
  { $interactive = 0;
  }
  else
  { $interactive = 1;
  }
  if ($options && $debug)
  { print("\nCommand line options passed to the script\n-------------------".
     "----------------------\n");
    print(" aid=".$opt{"aid"}."\n");
    print(" aid=".$opt{"a"}."\n");
    if ($opt{'cePass'})
    { print(" cePass=*******\n");
    }
    else
    { print(" cePass=\n");
    }
    if ($opt{'coPass'})
    { print(" coPass=*******\n");
    }
    else
    { print(" coPass=\n");
    }
    print(" d=".$opt{"d"}."\n");
    print(" h=".$opt{"h"}."\n");
    print(" i=".$opt{"i"}."\n");
    if ($opt{'ibPass'})
    { print(" ibPass=*******\n");
    }
    else
    { print(" ibPass=\n");
    }
    print(" log=".$opt{"log"}."\n");
    print(" log=".$opt{"l"}."\n");
    print(" oh=".$opt{"oh"}."\n");
    print(" ot=".$opt{"ot"}."\n");
    print(" q=".$opt{"q"});
    print("undef") if ! defined($opt{'q'});
    if (defined ($opt{'q'}) && $opt{'q'} == 1)
    { print(" (non-interactive mode).\n");
    }
    else
    { print(" (interactive mode).\n");
    }
    print(" sc=".$opt{"sc"});
    print("undef") if ! defined($opt{'sc'});
    if (defined ($opt{'sc'}) && $opt{'sc'} == 0)
    { print(" (force cipher check).\n");
    }
    elsif (defined ($opt{'sc'}) && $opt{'sc'} == 1)
    { print(" (skip cipher check).\n");
    }
    else
    { print(" (value will be ignored. Expected values are 0,1).\n");
    }
    print(" typ=".$opt{'typ'});
    print("undef") if ! defined($opt{'typ'});
    print(" -> using ".$typ) if !($opt{'typ'} == 1 || $opt{'typ'} == 2);
    if ($typ == 1)
    { print(" (catalog.xml schematic file).\n");
    }
    else
    { print(" (databasemachine.xml schematic file).\n");
    }
  }
}

BEGIN {
   my ($llp,$params) = (undef,undef);
   my @params = @ARGV;

   # Obtain information from previously processed execution
   if ( defined($ENV{PRE_DISC_ORACLE_HOME}) )
   { &parseOptions(0);
     $llp = $ENV{LD_LIBRARY_PATH};
     $oh = $ENV{ORACLE_HOME};
   }
   else
   { &parseOptions(1);

     # Process input file
     if ( defined($opt{'i'}) && defined(open(IN, "< $opt{'i'}")) )
     { my @buf = <IN>;
       close(IN);
       foreach my $lin (grep (!/^#/, @buf))
       { $params = $lin
       }
       if (defined($params))
       { @params = split(/\s+/, $params);
         exec { $^X } $^X, $0, @params;
       }
       else
       { print("\nCould not find any information in the input file.\n");
         if ($interactive)
         {print("All required information will be prompted.\n");
         }
         else
         { print("Please make sure input file contains the right ".
            "information.\n");
           exit(1);
         }
       }
     }
     elsif ( defined($opt{'i'}) )
     { print("\nCould not read input file ".$opt{'i'}."\n");
       if ($interactive)
       {print("All required information will be prompted.\n");
       }
       else
       {print("Please make sure input file exists and is readable.\n");
        exit(1);
       }
     }

     # Obtain ORACLE_HOME and oratab default locations
     if ( defined($opt{'oh'}) && $opt{'oh'} != 1 && -d $opt{'oh'})
     { $oh = $opt{'oh'};
     }
     elsif ( defined($ENV{ORACLE_HOME}) && -d $ENV{ORACLE_HOME} )
     { $oh = $ENV{ORACLE_HOME};
     }
     if ( defined($opt{'ot'}) && $opt{'ot'} != 1 && -r $opt{'ot'})
     { $ot = $opt{'ot'};
     }
     elsif ( -r "/etc/oratab" )
     { $ot = "/etc/oratab";
     }
     elsif ( -r "/var/opt/oracle/oratab" )
     { $ot = "/var/opt/oracle/oratab";
     }
   }

   # Process oratab file only if necessary
   if ( !defined($oh) && defined(open(IN, "< $ot")) )
   { my @buf = <IN>;
     close(IN);
     foreach my $lin (grep (!/^#|^\s*$|^.*ASM.*\:|^\*/, @buf))
     { last if defined($oh);
       if (!defined($ENV{ORACLE_HOME}) && $lin =~ /^.*\:(.*)\:/ )
       { $oh = $1 if ( -d $1 );
       }
       elsif ( defined($ENV{ORACLE_HOME}) &&
               $lin =~ /^.*\:($ENV{ORACLE_HOME})\:/ )
       { $oh = $1 if ( -d $1 );
       }
     }
   }

   # Verify that obtained ORACLE_HOME is a valid directory
   $oh = undef if (defined($oh) && (! -d $oh));

   if ( !defined($oh) )
   { print("\nCould not find ORACLE_HOME location.\nThis script needs to ".
      "use an ORACLE_HOME location.\n");
     if ($interactive)
     { do
       { print("\nPlease enter the ORACLE_HOME full path location:\n");
         $oh =  <STDIN>;
         chomp ($oh);
         if ( ! -d $oh )
         { print("$oh does not exist or is not a directory.\n");
         }
         elsif ( ! -x "$oh/perl/bin/perl" )
         { print("Could not find perl binary in $oh/perl/bin directory.\n");
         }
         elsif ( ! -d "$oh/lib" )
         { print("Could not find lib directory under $oh\n");
         }
       } while (! -d $oh or ! -x "$oh/perl/bin/perl" or ! -d "$oh/lib");
     }
     else
     { print("\nPlease use one of the following approaches to run the ".
        "script:\n- Make sure /etc/oratab or /var/opt/oracle/oratab files ".
        "contain a valid\n  ORACLE_HOME setup.\n- Set ORACLE_HOME environment ".
        "variable prior to running the script.\n- Use '-oh' command line ".
        "option to indicate the ORACLE_HOME location.\n- Use '-ot' command ".
        "line option to indicate an alternative oratab file\n  location.\n\n");
       exit(1);
     }
   }

   # Make sure that the necessary environment is sourced
   if ( defined($oh) )
   { if ( ! -x "$oh/perl/bin/perl" )
     { if ($interactive)
       { print("\nCould not find perl binary in $oh/perl/bin directory.\n");
         do
         { print("\nPlease enter the ORACLE_HOME full path location:\n");
           $oh =  <STDIN>;
           chomp ($oh);
           if ( ! -d $oh )
           { print("$oh does not exist or is not a directory.\n");
           }
           elsif ( ! -x "$oh/perl/bin/perl" )
           { print("Could not find perl binary in $oh/perl/bin directory.\n");
           }
           elsif ( ! -d "$oh/lib" )
           { print("Could not find lib directory under $oh\n");
           }
         } while (! -d $oh or ! -x "$oh/perl/bin/perl" or ! -d "$oh/lib");
       }
       else
       { print("\nUsing ORACLE_HOME $oh\n\n".
          "Could not find perl binary in $oh/perl/bin directory.\n".
          "Please make sure ORACLE_HOME points to a valid location and try to ".
          "run the\nscript again.\n\n");
         exit(1);
       }
     }
     elsif ( ! -d "$oh/lib" )
     { if ($interactive)
       { print("\nCould not find lib directory under $oh\n");
         do
         { print("\nPlease enter the ORACLE_HOME full path location:\n");
           $oh =  <STDIN>;
           chomp ($oh);
           if ( ! -d $oh )
           { print("$oh does not exist or is not a directory.\n");
           }
           elsif ( ! -x "$oh/perl/bin/perl" )
           { print("Could not find perl binary in $oh/perl/bin directory.\n");
           }
           elsif ( ! -d "$oh/lib" )
           { print("Could not find lib directory under $oh\n");
           }
         } while (! -d $oh or ! -x "$oh/perl/bin/perl" or ! -d "$oh/lib");
       }
       else
       { print("\nUsing ORACLE_HOME $oh\n\n".
          "Could not find lib directory under $oh\n".
          "Please make sure ORACLE_HOME points to a valid location and try to ".
          "run the\nscript again.\n\n");
         exit(1);
       }
     }
   }
   # Set pattern to look for in LD_LIBRARY_PATH environment variable
   $llp = "$oh/lib" if defined($oh);
   if ( defined($oh) && not $ENV{LD_LIBRARY_PATH} =~
                 /^$llp$|^$llp\:.*$|^.*\:$llp\:.*$|^.*\:$llp$/ )
   { $ENV{ORACLE_HOME}     = $oh;
     $ENV{LD_LIBRARY_PATH} = $llp;
     $ENV{PRE_DISC_ORACLE_HOME} = $oh;
     exec { $^X } $^X, $0, @params;
   }
}

use XML::Parser;

# Define the global public variables
my $adm = 0;
my $aid = undef;
my $cli = 0;
my $curAdminDomain = undef;
my $curAdminIp = undef;
my $curAdminName = undef;
my $curClientDomain = undef;
my $curClientIp = undef;
my $curClientName = undef;
my $curComp = undef;
my $curHostName = undef;
my $curId = undef;
my $curType = undef;
my $domainName = hostdomain();
my $emp = "/opt/oracle.SupportTools/onecommand/em.param";
my $genericCellPasswd = undef;
my $genericComputePasswd = undef;
my $genericIbPasswd = undef;
my $log = "/tmp/exadataDiscoveryPreCheck_".&timestamp().".log";
my $logError = undef;
my $tgt = "";
my $ver = undef;
my $verSch = undef;
my $xmlElem;
my @comp = ();
my @elem = ();
my @emCel = ();
my @emIb = ();
my @emKvm = ();
my @emPdu = ();
my @expectedCiphers = ("aes128-cbc","aes192-cbc","aes256-cbc","3des-cbc",
                       "blowfish-cbc");
my @nmb = ("nmb","nmhs","nmo");
my @out = ();
my @schCel = ();
my @schContent = ();
my @schIb = ();
my @schKvm = ();
my @schPdu = ();

# Define required environment
$ENV{PATH}="/opt/ipmitool/sbin:/opt/ipmitool/bin:/usr/sbin:/usr/bin:$ENV{PATH}";

# Main code
&showHeader();

# Get necessary setup data
&getLogFile();
&showLogHeader();
&getAgentInstallDir();
&getEMParamFile();
&getOracleHome();
&getSchematicFile();
&getGenericPasswds();
&showCollectedSetupData();

# Parse setup files
&showProgress(1/10) if (! $interactive and ! $debug);
&parseEmParamFile();
&showProgress(2/10) if (! $interactive and ! $debug);
&parseSchematicFile();

# Perform checks
&showProgress(3/10) if (! $interactive and ! $debug);
&checkSetupFilesConsistency();
&checkDomainnameSetup();
&showProgress(4/10) if (! $interactive and ! $debug);
&checkComponentVersions();
&showProgress(5/10) if (! $interactive and ! $debug);
&checkKfodPermissions();
&showProgress(6/10) if (! $interactive and ! $debug);
&checkSchematicFileContent();
&showProgress(7/10) if (! $interactive and ! $debug);
&checkPingStatus();
&showProgress(8/10) if (! $interactive and ! $debug);
&checkRootShExecution();
&showProgress(9/10) if (! $interactive and ! $debug);
&checkSshCiphers();
&showProgress(10/10) if (! $interactive and ! $debug);
print("\n") if (! $interactive and ! $debug);

&doPrint($log,2,"\nPlease review log file $log\n\n");
print("\nPlease review log file $log\n\n") if (! $interactive and ! $debug);
exit(0);

=head2 S<checkComponentVersions()>

This subroutine performs version checks for Exadata Storage Server,
ILOM ipmitool and Infiniband switch on all the necessary nodes. It also
displays instructions indicating how to manually check PDU Firmware and
KVM Application versions.

Displays warning messages in case any component version is below the required
ones.

=cut

sub checkComponentVersions
{ &doPrint($log,2,"\nVerifying component versions...\n".
   "-------------------------------\n");

  # Check Exadata Storage Server Software version
  &doPrint($log,2,"\n Verifying Exadata Storage Server Software version...\n".
   " ----------------------------------------------------\n");
  $tgt = "11.2.2.3";
  if ( ! $interactive and ! defined($genericCellPasswd) )
  { &doPrint($log,2,"  Skipping as we are running in non interactive".
     " mode and no generic\n  cell node password was provided.\n");
  }
  else
  { if ( (scalar @emCel) <= 0 )
    { &doPrint($log,2,"  Skipping as no cell nodes were found in em.param".
       " file\n");
    }
    else
    { foreach my $hst (@emCel)
      { &doPrint($log,2,"\n  Verifying version for $hst cell node...\n");
        my $cmd = "cellcli -e 'list cell detail'";
        my $pwd = $genericCellPasswd;
        $pwd = &promptPassword("Enter root\@$hst user password:",
                               0,"   ") if !defined($pwd);
        $ver = undef;
        @out = ();
        if ( &runSshCommand($hst, "root", $pwd, $cmd) )
        { foreach my $lin (@out)
          { if ( $lin =~ /releaseVersion:\s*(.*)$/ )
            { $ver = &trim($1);
            }
          }
          if (defined ($ver))
          { &doPrint($log,2,"   Exadata Storage Server Software version is".
             " $ver");
            if ( &validVersion($ver,$tgt) )
            { &doPrint($log,2," ===> Ok\n");
            }
            else
            { &doPrint($log,2," ===> Not ok\n\n   * Please make sure Exadata".
               " Storage Server version is $tgt or later.\n");
            }
          }
          else
          { &doPrint($log,2,"   Could not find Exadata Storage Server Software".
             " version ===> Not ok\n\n   * Please make sure that the execution".
             " of command: \n".
             "     $cmd on node $hst\n     shows the release version.\n");
          }
        }
        else
        { &doPrint($log,2,"   Could not invoke command $cmd using SSH ===>".
           " Not ok\n\n   * Please check the password and host status.\n     ".
           "Additionally please check that SSH is not blocked by a firewall.".
           "\n");
        }
      }
    }
  }
  &doAckPause(" ");

  # Check ILOM ipmitool version
  &doPrint($log,2,"\n Verifying ILOM ipmitool version...\n");
  &doPrint($log,2," ----------------------------------\n");
  $tgt = "1.8.10.3";
  $tgt = "1.8.10.4" if ( $^O eq "solaris" );
  $ver = `ipmitool -V`;
  if ($ver =~ /ipmitool version (.*)$/)
  { $ver = &trim($1);
  }
  else
  { $ver = undef;
  }
  if ( defined($ver) )
  { &doPrint($log,2,"  ILOM ipmitool version is $ver");
    if ( &validVersion($ver,$tgt) )
    { &doPrint($log,2," ===> Ok\n");
    }
    else
    { &doPrint($log,2," ===> Not ok\n\n".
       "  * Please make sure ILOM ipmitool version is $tgt or later.\n");
    }
  }
  else
  { &doPrint($log,2,"  Could not find ILOM ipmitool version information.\n\n".
     "  * Please make sure that file ipmitool exists and is  executable.\n");
  }
  &doAckPause(" ");

  # Check Infiniband Switch version
  &doPrint($log,2,"\n Verifying Infiniband Switch version...\n");
  &doPrint($log,2," --------------------------------------\n");
  $tgt = "1.1.3-2";
  if ( ! $interactive and ! defined($genericIbPasswd) )
  { &doPrint($log,2,"  Skipping as we are running in non interactive".
     " mode and no generic\n  infiniband switch password was provided.\n");
  }
  else
  { if ( (scalar @emIb) <= 0 )
    { &doPrint($log,2,"  Skipping as no infiniband switches were found in".
       " em.param file\n");
    }
    else
    { foreach my $hst (@emIb)
      { &doPrint($log,2,"\n  Verifying version for $hst infiniband switch...".
         "\n");
        my $cmd = "version";
        my $pwd = $genericIbPasswd;
        $pwd = &promptPassword("Enter nm2user\@$hst user password:",
                               0,"   ") if !defined($pwd);
        $ver = undef;
        @out = ();
        if ( &runSshCommand($hst, "nm2user", $pwd, $cmd) )
        { foreach my $lin (@out)
          { if ( $lin =~ /SUN.*version:\s*(.*)$/ )
            { $ver = &trim($1);
            }
          }
          if (defined ($ver))
          { &doPrint($log,2,"   Infiniband Switch version is $ver");
            if ( &validVersion($ver,$tgt) )
            { &doPrint($log,2," ===> Ok\n");
            }
            else
            { &doPrint($log,2," ===> Not ok\n\n   * Please make sure".
               " Infiniband Switch version is $tgt or later.\n");
            }
          }
          else
          { &doPrint($log,2,"   Could not find Infiniband Switch version ===>".
             " Not ok\n\n   * Please make sure that the execution of command:".
             " \n     $cmd on node $hst\n     shows the correct version.\n");
          }
        }
        else
        { &doPrint($log,2,"   Could not invoke command $cmd using SSH ===>".
           " Not ok\n\n   * Please check the password and host status.\n     ".
           "Additionally please check that SSH is not blocked by a firewall.".
           "\n");
        }
      }
    }
  }
  &doAckPause(" ");

  # Display PDU Firmware manual check instructions
  &doPrint($log,2,"\n Verifying PDU Firmware version...\n".
   " ---------------------------------\n  The current version can be obtained".
   " by logging into the web interface of\n  the PDU. On the left side of the".
   " screen, click Module Info to view the PDU\n  firmware version. Software".
   " updates for PDU are available at:\n  https://updates.oracle.com/Orion/".
   "PatchDetails/process_form?patch_num=12871297\n\n".
   "  * Please manually verify that PDU Firmware version is 1.02 or later.\n");
  &doAckPause(" ");

  # Display KVM Application manual check instructions
  &doPrint($log,2,"\n Verifying KVM Application version...\n".
   " ------------------------------------\n  The current version can be".
   " obtained by logging into the web interface of\n  the KVM. On the left".
   " side of the screen under Unit View,  Appliance,\n  Appliance Settings,".
   " click Versions to view the Application software version.\n  Software".
   " updates are available at:\n  http://www.avocent.com/Support_Firmware/".
   "MergePoint_Unity/MergePoint_Unity_Switch.aspx\n\n  * Please manually".
   " verify that KVM Application version is 1.2.8 or later.\n");
  &doAckPause(" ");
}

=head2 S<checkDomainNameSetup()>

This subroutine verifies the domain name setup.
Displays warning messages in case any issue is found.

=cut

sub checkDomainnameSetup
{ my ($cmd,$out) = ("/bin/domainname",undef);
  &doPrint($log,2,"\nVerifying domain name setup...\n".
   "------------------------------\n");
  $cmd = "/usr/bin/domainname" if ( $^O eq "solaris" );
  $out = `$cmd`;
  $out = &trim($out);
  &doPrint($log,2," Domain name obtained by this script is $domainName\n".
   " OS domain name is $out\n");
  if ( $domainName eq $out )
  { if ( $out eq "" or $out =~ /^.*\(none\).*$/)
    { &doPrint($log,2,"\n Both domain name definitions are empty/undefined ".
       "===> Not ok\n\n * Please make sure domain name setup is correct.\n");
    }
    else
    { &doPrint($log,2,"\n Both domain names are the same ===> Ok\n");
    }
  }
  else
  { if ( $domainName eq "" or $domainName =~ /^.*\(none\).*$/ )
    { &doPrint($log,2,"\n Domain name obtained by this script is ".
       "empty/undefined ===> Not ok\n".
       "\n * Please make sure domain name setup is correct.\n");
    }
    elsif ( $out eq "" or $out =~ /^.*\(none\).*$/ )
    { &doPrint($log,2,"\n Domain name obtained by this script is defined ".
       "===> Ok\n");
    }
    else
    { &doPrint($log,2,"\n Domain names are different ===> Not ok\n".
       "\n * Please make sure domain name setup is correct.\n");
    }
  }
  &doAckPause();
}

=head2 S<checkKfodPermissions()>

This subroutine verifies that ORACLE_HOME kfod binary has read and execute
permissions.

Displays warning messages in case any issue is found.

=cut

sub checkKfodPermissions
{ &doPrint($log,2,"\nVerifying ORACLE_HOME kfod binaries file permissions...\n".
   "-------------------------------------------------------\n");
  if ( ! defined($oh) )
  { &doPrint($log,2," Skipping as either provided ORACLE_HOME does not exist".
     " or could not find an\n alternative ORACLE_HOME in oratab file.\n");
  }
  else
  { my $kfo = $oh."/bin/kfod";
    if (-r $kfo && -x $kfo)
    { &doPrint($log,2," ORACLE_HOME kfod binary has read and execute".
       " permissions ===> Ok\n");
    }
    else
    { if (-e $kfo)
      { &doPrint($log,2," ORACLE_HOME kfod binary exists, but does not have".
         " either read or execute permissions.\n\n".
         " * Please make sure file is both executable and readable.\n");
      }
      else
      { &doPrint($log,2," Could not find kfod binary under the specified".
         " ORACLE_HOME.\n\n * Please make sure file exists and is both".
         " executable and readable.\n");
      }
    }
  }
  &doAckPause();
}

=head2 S<checkPingStatus()>

This subroutine verifies that IP addresses found in schematic file are alive.
Displays warning messages in case any issue is found.

=cut

sub checkPingStatus
{ &doPrint($log,2,"\nVerifying components IP address ping status...\n".
  "----------------------------------------------\n");
  if ( (scalar @comp) <= 0 )
  { &doPrint($log,2,"  Skipping as no components were found in".
     " schematic file.\n");
  }
  else
  { foreach my $elem (@elem)
    { my $ip = $elem->{adminIp};
      $ip = $elem->{clientIp} if defined($elem->{clientIp});
      my $hst = $elem->{adminName};
      $hst = $elem->{clientName} if defined($elem->{clientName});
      my $cmd = "/bin/ping  -c2 -W2 ".$ip." |";
      my $rcv = undef;
      my @output = ();
      $cmd = "/usr/sbin/ping -s ".$ip." 2 2 |" if $^O eq "solaris";
      open(PING, $cmd);
      while(<PING>)
      { push(@output,$_);
      }
      foreach my $lin (grep (/^.*transmitted, \d* [packets ]*received.*$/,
                             @output))
      { if ( $lin =~ /^.*transmitted, (\d*) [packets ]*received.*$/ )
        { $rcv = &trim($1);
        }
      }
      $rcv = 0 if ! defined($rcv);
      if( $rcv > 0 )
      { &doPrint($log,2," Admin ") if defined($elem->{adminIp});
        &doPrint($log,2," Client") if defined($elem->{clientIp});
        &doPrint($log,2," host ".$ip." (".$hst.") is alive ===> Ok\n");
      }
      else
      { &doPrint($log,2," Admin ") if defined($elem->{adminIp});
        &doPrint($log,2," Client") if defined($elem->{clientIp});
        &doPrint($log,2," host ".$ip." (".$hst.
         ") appears to be down ===> Not ok\n");
      }
    }
  }
  &doAckPause();
}

=head2 S<checkRootShExecution()>

This subroutine verifies that root.sh script was correctly executed.

Displays warning messages in case any issue is found.

=cut

sub checkRootShExecution
{ &doPrint($log,2,"\nVerifying that root.sh was correctly executed for agent".
 " installation...\n".
 "-----------------------------------------------------------------------\n");
  if ( !defined($aid) )
  { &doPrint($log,2," There is no agent installation present in this".
     " machine.\n Skipping this check.\n");
  }
  else
  { my $ok = 0;
    foreach my $itm (@nmb)
    { my $fil = "$aid"."/sbin/$itm";
      $ok = 0;
      $ok = 1 if ( -e $fil) && (getpwuid((stat($fil))[4]) eq "root") &&
                 ( -u $fil );
    }
    if ($ok)
    { &doPrint($log,2," Files nmb, nmhs and nmo under the Agent installation".
       " directory\n are owned by root and have set-user-ID bit correctly set".
       " ===> Ok\n");
    }
    else
    { &doPrint($log,2," Problem detected in either one or all nmb, nmhs and/or".
       " nmo files\n under the Agent installation directory ===> Not ok\n\n".
       " * Please make sure that root.sh was correctly executed.\n");
    }
  }
  &doAckPause();
}

=head2 S<checkSchematicFileContent()>

This subroutine parses the schematic file and verifies that current ADMINNAME
and ADMINIP definitions are correct in the schematic file.

Displays warning messages in case any issue is found.

=cut

sub checkSchematicFileContent
{ &doPrint($log,2,"\nVerifying hostname and IP address in the schematic".
  " file...\n----------------------------------------------------------\n");
  if (!defined($verSch))
  { &doPrint($log,2," Could not read or find version information in schematic".
     " file.\n\n * Please make sure that schematic file contains version".
     " information.\n");
  }
  elsif (($typ == 2 && $verSch < 502) or ($typ == 1 && $verSch < 868))
  { &doPrint($log,2," Skipping check as schematic file version is lower than");
    &doPrint($log,2," 868") if $typ == 1;
    &doPrint($log,2," 502") if $typ == 2;
    &doPrint($log,2,".\n\n * Please log an SR with Support and they will".
     " generate a new\n   schematic file.\n");
  }
  else
  { if ( (scalar @elem) <= 0 )
    { &doPrint($log,2,"  Skipping as no components were found in".
       " schematic file.\n");
    }
    else
    { foreach my $elem (@elem)
      { my $ip = undef;
        my $nam = undef;
        my $namFound = 0;
        my $hst = $elem->{adminName};
        $hst = $elem->{clientName} if defined($elem->{clientName});
        my $hstDom = undef;
        $hstDom = $elem->{adminName}.".".$elem->{adminDomain}
         if ($typ ==1 && defined($elem->{adminDomain}));
        $hstDom = $elem->{clientName}.".".$elem->{clientDomain}
         if ($typ ==1 && defined($elem->{clientName}) &&
             defined($elem->{clientDomain}));

        my @result = `nslookup $hst`;
        foreach my $lin (@result)
        { if ( $lin =~ /Name:\s*(.*)$/ )
          { $namFound = 1;
            $nam = &trim($1);
            $nam = undef if $nam eq "";
          }
          if ( $namFound && $lin =~ /Address:\s*(\d*\.\d*\.\d*\.\d*)/ )
          { $ip = &trim($1);
            next;
          }
        }

        &doPrint($log,2,"\n Verifying ");
        &doPrint($log,2,"admin") if defined($elem->{adminIp});
        &doPrint($log,2,"client") if defined($elem->{clientIp});
        &doPrint($log,2," $elem->{type} host $hst...\n");
        if ( defined($elem->{adminIp}) && $ip eq $elem->{adminIp} )
        { &doPrint($log,2,"  ADMINNAME:  $hst ,".
           " ADMINIP: $elem->{adminIp} ===> Ok\n");
        }
        elsif ( defined($elem->{clientIp}) && $ip eq $elem->{clientIp} )
        { &doPrint($log,2,"  CLIENTNAME: $hst ,".
           " CLIENTIP: $elem->{clientIp} ===> Ok\n");
        }
        elsif (defined($elem->{adminIp}))
        { &doPrint($log,2,"  ADMINNAME:  $hst ,".
           " ADMINIP: $elem->{adminIp} ===> Not ok\n   * Please correct".
           " ADMINIP definition for ADMINNAME $hst\n".
           "     in the schematic file for $elem->{type} ");
          &doPrint($log,2,"$elem->{hostName}.\n")
           if defined($elem->{hostName});
          &doPrint($log,2,"$hst.\n") if ! defined($elem->{hostName});
        }
        else
        { &doPrint($log,2,"  CLIENTNAME: $hst ,".
           " CLIENTIP: $elem->{clientIp} ===> Not ok\n   * Please correct".
           " CLIENTIP definition for CLIENTNAME $hst\n".
           "     in the schematic file for $elem->{type} $elem->{hostName}.\n");
        }

        # Secondary check when using catalog.xml and domain is defined
        if (($typ == 1) && (defined($hstDom)) && (defined($nam)) &&
            (defined($elem->{adminDomain}) || defined($elem->{clientDomain})))
        { &doPrint($log,2,"  Verifying domain definition for ");
          &doPrint($log,2,"admin host...\n") if defined($elem->{adminDomain});
          &doPrint($log,2,"client host...\n") if defined($elem->{clientDomain});
          if ($hstDom eq $nam)
          { &doPrint($log,2,"   ADMINNAME:  ") if defined($elem->{adminDomain});
            &doPrint($log,2,"   CLIENTNAME: ")
             if defined($elem->{clientDomain});
            &doPrint($log,2,"$hstDom matches name returned\n               ".
             "by nslookup ===> Ok\n");
          }
          else
          { &doPrint($log,2,"   ADMINNAME:  ") if defined($elem->{adminDomain});
            &doPrint($log,2,"   CLIENTNAME: ")
             if defined($elem->{clientDomain});
            &doPrint($log,2,"$hstDom does not match\n               name ".
             "returned by nslookup ===> Not ok\n    * Please correct domain ".
             "definition for ");
            &doPrint($log,2,"admin") if defined($elem->{adminDomain});
            &doPrint($log,2,"client") if defined($elem->{clientDomain});
            &doPrint($log,2," host\n      $hst in the schematic file.\n");
          }
        }
      }
    }
  }
  &doAckPause();
}

=head2 S<checkSchematicFilePermissions()>

This subroutine verifies that schematic file has read permissions.

Displays warning messages in case any issue is found.

=cut

sub checkSchematicFilePermissions
{ &doPrint($log,2,"\n Verifying schematic file permissions...\n".
 " ---------------------------------------\n");
  if (-r $sch)
  { &doPrint($log,2,"  Schematic file is readable ===> Ok\n");
  }
  else
  { if (-e $sch)
    { &doPrint($log,2,"  Schematic file exists, but does not have read".
       " permissions.\n\n  * Please make sure that file is readable.\n");
    }
    else
    { &doPrint($log,2,"  Could not find schematic file on the file system.".
       "\n\n  * Please make sure that file exists and is readable.\n");
    }
  }
}

=head2 S<checkSchematicFileVersion()>

This subroutine verifies that schematic file version is at least 502.

Displays warning messages in case any issue is found.

=cut

sub checkSchematicFileVersion
{ &doPrint($log,2,"\n Verifying schematic file version...\n".
   " -----------------------------------\n");
  $tgt = 868;
  $tgt = 502 if $typ == 2;
  $verSch  = undef;
  if (-r $sch)
  { if (!defined(open(IN, "< $sch")))
    { &doPrint($log,2,"  Could not open schematic file.\n\n".
       "  * Please make sure that file exists and is readable.\n");
    }
    else
    { @schContent = <IN>;
      close(IN);
      foreach my $lin (grep (/ORACLE_CLUSTER version=/, @schContent))
      { if ( $lin =~ /ORACLE_CLUSTER version=\"(\d*)\"/ )
        { $verSch  = &trim($1);
        }
      }
      $verSch = undef if $verSch == "";
      if (defined ($verSch ))
      { if ($verSch  >= $tgt)
        { &doPrint($log,2,"  Schematic file version is $verSch  ===> Ok\n");
        }
        else
        { &doPrint($log,2,"  Schematic file version is lower than $tgt.\n\n".
           "  * Please log an SR with Support and they will generate a".
           " new schematic file.\n");
        }
      }
      else
      { &doPrint($log,2,"  Could not find version information in schematic".
         " file.\n\n".
         "  * Please make sure that file contains version information.\n");
      }
    }
  }
  else
  { &doPrint($log,2,"  Could not read schematic file.\n\n".
     "  * Please make sure that file exists and is readable.\n");
  }
}

=head2 S<checkSetupFilesConsistency()>

This subroutine verifies that information in em.param and schematic
files is consistent.

Displays warning messages in case any issue is found.

=cut

sub checkSetupFilesConsistency
{ &doPrint($log,2,"\nVerifying setup files consistency...\n".
   "------------------------------------\n");
  if ( ! defined($emp) or ! defined($sch) )
  { &doPrint($log,2," Skipping as ");
    &doPrint($log,2,"em.param file ") if ! defined($emp);
    &doPrint($log,2,"and ") if ( ! defined($emp) and ! defined($sch) );
    &doPrint($log,2,"schematic file ") if ! defined($sch);
    &doPrint($log,2,"could not be found.\n ");
  }
  else
  { my %count = ();
    my $ok = 1;
    &doPrint($log,2," Verifying cell nodes...\n");
    foreach my $cel (@emCel, @schCel) { $count{$cel}++;};
    foreach my $cel (keys %count)
    { if ($count{$cel} == 1)
      { &doPrint($log,2,"  Cell node $cel is missing in one of the setup".
         " files.\n");
        $ok = 0;
      }
    }
    %count = ();
    &doPrint($log,2," Verifying infiniband nodes...\n");
    foreach my $ib (@emIb, @schIb) { $count{$ib}++;};
    foreach my $ib (keys %count)
    { if ($count{$ib} == 1)
      { &doPrint($log,2,"  Infiniband node $ib is missing in one of the setup".
         " files.\n");
        $ok = 0;
      }
    }
    %count = ();
    &doPrint($log,2," Verifying KVM nodes...\n");
    foreach my $kvm (@emKvm, @schKvm) { $count{$kvm}++;};
    foreach my $kvm (keys %count)
    { if ($count{$kvm} == 1)
      { &doPrint($log,2,"  KVM node $kvm is missing in one of the setup".
         " files.\n");
        $ok = 0;
      }
    }
    %count = ();
    &doPrint($log,2," Verifying PDU nodes...\n");
    foreach my $pdu (@emPdu, @schPdu) { $count{$pdu}++;};
    foreach my $pdu (keys %count)
    { if ($count{$pdu} == 1)
      { &doPrint($log,2,"  PDU node $pdu is missing in one of the setup".
         " files.\n");
        $ok = 0;
      }
    }
    if ($ok)
    { &doPrint($log,2,"\n Setup files are consistent ===> Ok\n");
    }
    else
    { &doPrint($log,2,"\n Setup files are not consistent ===> Not ok\n".
       "\n * Please make sure that node information in both parameter and".
       " schematic files\n   is consistent.\n");
    }
  }
  &doAckPause();
}

=head2 S<checkSshCiphers()>

This subroutine verifies that required SSH ciphers are used in all cell and
compute nodes. It uses SSH to connect to all the cell and compute nodes and
verifies ciphers SSH setup contained in /etc/ssh/sshd_config file.

Displays warning messages in case any issue is found.

=cut

sub checkSshCiphers
{ my $run = 1;
  my $verEMPlugin = undef;

  $tgt = "12.1.0.2.0";
  &doPrint($log,2,"\nVerifying SSH ciphers...\n".
   "------------------------\n");

  # Verify if cipher check needs to be performed
  if ( defined($opt{'sc'}) && $opt{'sc'} == 0 )
  { &doPrint($log,2," Force running as requested via '-sc' command option.".
     "\n\n");
  }
  elsif ( defined($opt{'sc'}) && $opt{'sc'} == 1 )
  { &doPrint($log,2," Skipping as requested via '-sc' command option.\n");
    $run = 0;
  }
  else
  { # Obtain EM agent version from agentimage.properties file
    &doPrint($log,2,"\n Obtaining EM agent version...\n".
     " -----------------------------\n");
    if ( (defined($aid)) && (-r "$aid/agentimage.properties") )
    { &doPrint($log,2," Reading file $aid/agentimage.properties\n");
      $verEMPlugin = `/bin/grep '^\s*VERSION\s*=' $aid/agentimage.properties \
       2>/dev/null | head -n 1`;
      if ( $verEMPlugin =~ /^\s*VERSION\s*=(.*)$/ )
      { $verEMPlugin = &trim($1);
      }
      else
      { $verEMPlugin = undef;
      }
    }

    # Check obtained EM agent version
    if (defined($verEMPlugin))
    { &doPrint($log,2," EM agent version is ".$verEMPlugin."\n");
      if ( &validVersion($verEMPlugin,$tgt) )
      { &doPrint($log,2,"\n Skipping as EM agent version is 12.1.0.2 or".
         " later.");
        $run = 0;
      }
      &doPrint($log,2,"\n");
    }
    else
    { &doPrint($log,2," Unable to obtain EM agent version.\n");

      # Ask the user for the EM agent version
      if ($interactive)
      { my $answer = 'N';
        do
        { &doPrint($log,2," Is EM agent version 12.1.0.2 or later being used?".
           " [Y/N]\n ");
          $answer = <STDIN>;
          chomp ($answer);
          &doPrint($log,0,$answer."\n");
        } until ($answer =~ /Y|y|N|n/);
        if ($answer =~ /Y|y/)
        { &doPrint($log,2,"\n Skipping as EM agent version is 12.1.0.2 or".
           " later.");
          $run = 0;
        }
        &doPrint($log,2,"\n");
      }
      else
      { &doPrint($log,2,"\n Skipping as we are running in non interactive".
         " mode, no '-sc' option was\n used and we were unable to find EM".
         " agent version.\n");
        $run = 0;
      }
    }
  }

  # Run the cipher check only when required
  if ($run)
  { &doPrint($log,2," If running Exadata 11.2.3.1.0 , please add the ciphers".
     " listed in the steps\n below back to the /etc/ssh/sshd_config file on".
     " all cell and compute nodes.\n".
     " 1) ssh to the cell node as root\n".
     " 2) cd /etc/ssh/\n".
     " 3) back up sshd_config\n".
     " 4) add at least one of the following ciphers to the Cipher line in\n".
     "    sshd_config file:\n".
     "    aes128-cbc,aes192-cbc,aes256-cbc,3des-cbc,blowfish-cbc\n".
     " 5) Restart the ssh daemon (as the root user):\n".
     "    service sshd restart\n\n * Please make sure ciphers are correctly".
     " set in all cell and compute nodes.\n");

    if ( (scalar @comp) <= 0 )
    { &doPrint($log,2,"\n Skipping as no components were found in".
       " schematic file.\n");
    }
    else
    { if ( ! $interactive and ! defined($genericCellPasswd) and
           ! defined($genericComputePasswd) )
      { &doPrint($log,2,"\n Skipping as we are running in non interactive mode".
         " and no generic cell or\n compute node passwords were provided.\n");
      }
      else
      { if ( ! $interactive and ! defined($genericCellPasswd) )
        { &doPrint($log,2,"\n Skipping for cell nodes as we are running".
           " in non interactive mode\n and no generic cell node password".
           " was provided.\n");
        }
        if ( ! $interactive and ! defined($genericComputePasswd) )
        { &doPrint($log,2,"\n Skipping for compute nodes as we are running".
           " in non interactive mode\n and no generic compute node password".
           " was provided.\n");
        }
        foreach my $comp (@comp)
        { next unless ($comp->{type} =~ /cellnode|computenode|cell|comp/ );
          my $hst = $comp->{adminName};
          my $nod = undef;
          my $pwd = undef;
          my $skip = 0;
          if ($comp->{type} =~ /cellnode|cell/)
          { $pwd = $genericCellPasswd;
            $nod = "cell node";
          }
          else
          { $pwd = $genericComputePasswd;
            $nod = "compute node";
          }
          $skip = 1 if (!defined($pwd) and ! $interactive);
          if ($skip)
          { &doPrint($log,2,"\n Skipping $hst $nod.\n");
          }
          else
          { &doPrint($log,2,"\n Verifying SSH cipher definition for $hst".
             " $nod...\n");
            my $cmd = "/bin/grep \"^Ciphers \" /etc/ssh/sshd_config";
            $pwd = &promptPassword("Enter root\@$hst user password:",
                                   0,"  ") if !defined($pwd);
            my $localCiphers = undef;
            @out = ();
            if ( &runSshCommand($hst, "root", $pwd, $cmd) )
            { foreach my $lin (@out)
              { next unless ( $lin =~ /^Ciphers\s*(.*)$/ );
                $localCiphers = &trim(&replace($1,'\s','',1));
              }
              # If ciphers definition was found on the current node verify that
              # at least one of the required ciphers are present
              if (defined ($localCiphers))
              { my @localCiphers = split(/,/, $localCiphers);
                my $found = 0;
                foreach my $elem (@expectedCiphers)
                { if ( grep { $_ eq $elem} @localCiphers )
                  { $found = 1;
                    &doPrint($log,2,"  Found $elem cipher in sshd_config file".
                     " ===> Ok\n");
                    last;
                  }
                }
                if ( ! $found )
                { &doPrint($log,2,"  None of the expected ciphers were found".
                   " in sshd_config file ===> Not ok\n\n  * Please make sure".
                   " ciphers are correctly set in sshd_config file.\n");
                }
              }
              else
              { &doPrint($log,2,"  No cipher definition was not found in".
                 " sshd_config file ===> Not ok\n\n  * Please make sure".
                 " ciphers are correctly set in sshd_config file.\n");
              }
            }
            else
            { &doPrint($log,2,"  Could not invoke command $cmd\n  using SSH".
               " ===> Not ok\n\n  * Please check the password and host status.".
               "\n    Additionally please check that SSH is not blocked by a".
               " firewall.\n");
            }
          }
        }
      }
    }
  }
  &doAckPause();
}

=head2 S<compareVersions($ver1,$ver2)>

This subroutine compares versions C<$ver1> and C<$ver2>. It returns 0 if both
versions are the same, 1 if version C<$ver1> is higher than version C<$ver2>,
and a negative number if version C<$ver1> is lower than version C<$ver2>.

=cut

sub compareVersions
{ my ($ver1, $ver2) = @_;
  my ($num1, $num2, @tbl);

  @tbl = split(/\./, $ver2);
  foreach $num1 (split(/\./, $ver1))
  { return 1 unless defined($num2 = shift(@tbl));
    return $num1 <=> $num2 unless $num1 == $num2;
  }
  return (scalar @tbl) ? -1 : 0;
}

=head2 S<createFile($fil)>

This subroutine creates file C<$fil>.
It shows error message in case any errors occur.

=cut

sub createFile()
{ my ($fil) = @_;
  open FILE, ">$fil" or $logError = $!;
  close FILE;
}

=head2 S<doAckPause([$spc])>

This subroutine makes a pause for user to acknowledge a piece of information.
It asks to hit Enter key to continue.
Argument is used for text indentation.

=cut

sub doAckPause
{ my ($spc) = @_;
  &doPrint($log,2,"\n".$spc."Press [Enter] to continue...");
  &doPrint($log,0,"\n");
  if ($interactive)
  { my $nothing = <STDIN>;
  }
  &doPrint($log,1,"\n") if $debug;
}

=head2 S<doPrint($fil,$mod,$txt)>

This subroutine writes C<$txt> to standard output and to file C<$fil>.
It shows error message in case any errors occur.

Second argument is used to indicate where the sobroutine writes to:
0 -> Write only to file
1 -> Write only to stdout
2 -> Write to both file and stdout

=cut

sub doPrint()
{ my ($fil,$mod,$txt) = @_;
  if ( $mod > 0)
  { print $txt if ($debug or $interactive);
  }
  if ( $mod == 0 || $mod > 1 )
  { open FILE, ">>$fil" or die "Cannot open file $fil for append: $!";
    print FILE $txt;
    close FILE;
  }
}

=head2 S<flush($file)>

This subroutine performs a flush in the file passed as argument.

=cut

sub flush {
   my $h = select($_[0]); my $a=$|; $|=1; $|=$a; select($h);
}

=head2 S<getAgentInstallDir()>

This subroutine obtains the Agent install directory.
It prompts the user for an Agent install directory location. It keeps on
asking until the provided location is a valid directory.

=cut

sub getAgentInstallDir
{ &doPrint($log,2," Agent installation directory location\n".
   " -------------------------------------\n");
  if ( ! $interactive )
  { if ( defined($opt{"aid"}) && $opt{"aid"} != 1 )
    { $aid = $opt{"aid"};
      if ( ! -d $aid )
      { &doPrint($log,2,"  $aid does not exist or is not a".
         " directory.\n  Provided directory will not be used.\n");
        $aid = undef;
      }
      elsif ( ! -d "$aid/sbin" )
      { &doPrint($log,2,"  $aid does not seem to be a valid Agent\n".
         "  install directory as it does not contain an 'sbin' folder.\n".
         "  Provided directory will not be used.\n");
        $aid = undef;
      }
      else
      { &doPrint($log,2,"  $aid\n");
      }
    }
    else
    { $aid = undef;
      &doPrint($log,2,"  No Agent installation directory location provided.\n");
    }
  }
  else
  { if ( defined($opt{"aid"}) && $opt{"aid"} != 1 )
    { $aid = $opt{"aid"};
      if ( (-d $aid) && (-d "$aid/sbin") )
      { &doPrint($log,2,"  ".$aid."\n");
      }
      else
      { while (! -d $aid || ! -d "$aid/sbin")
        { if ( ! -d $aid )
          { &doPrint($log,2,"  $aid does not exist or is not a".
             " directory.\n");
          }
          elsif ( ! -d "$aid/sbin" )
          { &doPrint($log,2,"  $aid does not seem to be a valid Agent\n".
             "  install directory as it does not contain an 'sbin' folder.\n");
          }
          &doPrint($log,2,"  Please enter the Agent install directory full".
           " path location: \n  ");
          $aid =  <STDIN>;
          chomp ($aid);
          &doPrint($log,0,$aid."\n");
        }
      }
    }
    else
    { my $answer = 'N';
      do
      { &doPrint($log,2,"  Is there an agent installation in this machine?".
         " [Y/N]\n  ");
        $answer = <STDIN>;
        chomp ($answer);
        &doPrint($log,0,$answer."\n");
      } until ($answer =~ /Y|y|N|n/);
      if ($answer =~ /N|n/)
      { $aid = undef;
      }
      else
      { do
        { &doPrint($log,2,"  Please enter the Agent install directory full".
           " path location: \n  ");
          $aid =  <STDIN>;
          chomp ($aid);
          &doPrint($log,0,$aid."\n");
          if ( ! -d $aid )
          { &doPrint($log,2,"  $aid does not exist or is not a".
             " directory.\n");
            $aid = undef;
          }
          elsif ( ! -d "$aid/sbin" )
          { &doPrint($log,2,"  $aid does not seem to be a valid Agent\n".
             "  install directory as it does not contain an 'sbin' folder.\n");
            $aid = undef;
          }
        } while (! defined($aid));
      }
    }
  }
  &doPrint($log,2,"\n");
}

=head2 S<getEMParamFile()>

This subroutine obtains the location of a readable em.param file.

=cut

sub getEMParamFile
{ &doPrint($log,2," Enterprise Manager parameter (em.param) file\n".
   " --------------------------------------------\n");
  if ( -r $emp )
  { &doPrint($log,2,"  Using default em.param file:\n   $emp\n");
  }
  else
  { &doPrint($log,2,"  Default em.param file:\n   $emp\n  does not exist".
     " or is not readable.\n\n  Enterprise Manager parameter (em.param)".
     " file will not be used.\n");
    $emp = undef;
  }
  &doPrint($log,2,"\n");
}

=head2 S<getGenericPasswds()>

This subroutine checks if the same password should be reused for all cell nodes.
If so, it prompts for the generic root user password that should be used to
connect to all cell nodes.

=cut

sub getGenericPasswds
{ &doPrint($log,2," Generic passwords\n -----------------\n");
  &doPrint($log,2,"  Cell Nodes\n  ----------\n");
  if ( defined($opt{"cePass"}) && $opt{"cePass"} != 1 )
  { $genericCellPasswd = $opt{"cePass"};
    &doPrint($log,2,"   Using generic cell node password provided.\n\n");
  }
  else
  { if ( ! $interactive )
    { &doPrint($log,2,"   Generic cell node password not provided.\n\n");
    }
    else
    { my $answer = 'N';
      do
      { &doPrint($log,2,"   Do you want to use the same password to connect ".
         "to all cell nodes? [Y/N]\n   ");
        $answer = <STDIN>;
        chomp ($answer);
        &doPrint($log,0,$answer."\n");
      } until ($answer =~ /Y|y|N|n/);
      if ($answer =~ /Y|y/)
      { $genericCellPasswd = &promptPassword("Enter generic root user".
         " password:",0,"   ");
        &doPrint($log,0,"   Enter generic root user password:\n");
        &doPrint($log,2,"\n");
      }
      else
      { &doPrint($log,2,"\n");
      }
    }
  }
  &doPrint($log,2,"  Compute Nodes\n  -------------\n");
  if ( defined($opt{"coPass"}) && $opt{"coPass"} != 1 )
  { $genericComputePasswd = $opt{"coPass"};
    &doPrint($log,2,"   Using generic compute node password provided.\n\n");
  }
  else
  { if (! $interactive )
    { &doPrint($log,2,"   Generic compute node password not provided.\n\n");
    }
    else
    { my $answer = 'N';
      do
      { &doPrint($log,2,"   Do you want to use the same password to connect ".
         "to all compute nodes? [Y/N]\n   ");
        $answer = <STDIN>;
        chomp ($answer);
        &doPrint($log,0,$answer."\n");
      } until ($answer =~ /Y|y|N|n/);
      if ($answer =~ /Y|y/)
      { $genericComputePasswd = &promptPassword("Enter generic root user".
         " password:",0,"   ");
        &doPrint($log,0,"   Enter generic root user password:\n");
        &doPrint($log,2,"\n");
      }
      else
      { &doPrint($log,2,"\n");
      }
    }
  }
  &doPrint($log,2,"  Infiniband Switches\n  -------------------\n");
  if ( defined($opt{"ibPass"}) && $opt{"ibPass"} != 1 )
  { $genericIbPasswd = $opt{"ibPass"};
    &doPrint($log,2,"   Using generic infiniband switch password provided.\n");
  }
  else
  { if ( ! $interactive )
    { &doPrint($log,2,"   Generic infiniband switch password not provided.\n");
    }
    else
    { my $answer = 'N';
      do
      { &doPrint($log,2,"   Do you want to use the same password to connect to".
         " all infiniband switches?\n   [Y/N]\n   ");
        $answer = <STDIN>;
        chomp ($answer);
        &doPrint($log,0,$answer."\n");
      } until ($answer =~ /Y|y|N|n/);
      if ($answer =~ /Y|y/)
      { $genericIbPasswd = &promptPassword("Enter generic nm2user user".
         " password:",0,"   ");
        &doPrint($log,0,"   Enter generic nm2user user password:\n");
      }
    }
  }
}

=head2 S<getLogFile()>

This subroutine obtains the script log file location.
By default log file will be /tmp/exadataDiscoveryPreCheck.log

It asks user to confirm the log file location. It keeps on asking for a log
file location until the confirmed log file is a valid file.

=cut

sub getLogFile
{ if ( defined($opt{"log"}) && $opt{"log"} != 1 )
  { if ( $opt{"log"} =~ /^(.*)\.(.*)$/ )
    { $log = "$1"."_".&timestamp().".$2";
    }
    else
    { $log = $opt{"log"}."_".&timestamp();
    }
  }
  if ( ! $interactive )
  { &createFile($log);
    if ( ! -w $log )
    { print("File $log could not be created.\nError was: $logError\n");
      exit(1);
    }
  }
  else
  { &doPrint($log,1," Log file location\n ------------------\n");
    if ( defined($opt{"log"}) && $opt{"log"} != 1 )
    { do
      { &createFile($log);
        if ( ! -w $log )
        { &doPrint($log,1,"  File $log could not be created.\n".
           "  Error was: $logError\n");
          &doPrint($log,1,"\n  Please enter the log file full path".
           " location: \n  ");
          $log =  <STDIN>;
          chomp ($log);
          if ( $log =~ /^(.*)\.(.*)$/ )
          { $log = "$1"."_".&timestamp().".$2";
          }
          else
          { $log = "$log"."_".&timestamp();
          }
        }
      } while (! -w $log);
      &doPrint($log,1," $log\n");
    }
    else
    { &doPrint($log,1,"  Default log location is $log\n");
      my $answer = 'N';
      do
      { &doPrint($log,1,"\n  Do you want to use this log file location?".
         " [Y/N]\n  ");
        $answer = <STDIN>;
        chomp ($answer);
      } until ($answer =~ /Y|y|N|n/);
      if ($answer =~ /N|n/)
      { do
        { &doPrint($log,1,"\n  Please enter the log file full path".
           " location: \n  ");
          $log =  <STDIN>;
          chomp ($log);
          if ( $log =~ /^(.*)\.(.*)$/ )
          { $log = "$1"."_".&timestamp().".$2";
          }
          else
          { $log = "$log"."_".&timestamp();
          }
          &createFile($log);
          &doPrint($log,1,"  File $log could not be created.\n  Error was:".
           " $logError\n") if ! -w $log;
        } while (! -w $log);
      }
      else
      { do
        { &createFile($log);
          if ( ! -w $log )
          { &doPrint($log,1,"  File $log could not be created.\n".
             "  Error was: $logError\n");
            &doPrint($log,1,"\n  Please enter the log file full path".
             " location: \n  ");
            $log =  <STDIN>;
            chomp ($log);
            if ( $log =~ /^(.*)\.(.*)$/ )
            { $log = "$1"."_".&timestamp().".$2";
            }
            else
            { $log = "$log"."_".&timestamp();
            }
          }
        } while (! -w $log);
      }
    }
  }
}

=head2 S<getOracleHome()>

This subroutine obtains the Oracle Home location.
It first tries to obtain its location from the /etc/oratab file. If found it
shows a message indicating that an Oracle Home was found and asks user to
confirm the Oracle Home found. If not confirmed it prompts the user for an
alternative Oracle Home location. It keeps on asking for an Oracle Home
location until the confirmed Oracle Home is a valid directory.

=cut

sub getOracleHome
{ &doPrint($log,2," Oracle Home location\n --------------------\n");
  ($oh,$ot) = (undef,undef);
  if ( defined($opt{"oh"}) && $opt{"oh"} != 1 && -d $opt{"oh"})
  { $oh = $opt{"oh"};
  }
  if ( defined($opt{"ot"}) && $opt{"ot"} != 1 && -r $opt{"ot"})
  { $ot = $opt{"ot"};
  }
  else
  { if ( -r "/etc/oratab" )
    { $ot = "/etc/oratab";
    }
    elsif ( -r "/var/opt/oracle/oratab" )
    { $ot = "/var/opt/oracle/oratab";
    }
  }
 if (defined($oh))
 { &doPrint($log,2,"  $oh\n");
 }
 elsif (defined($ot))
 { &doPrint($log,2,"  Provided ORACLE_HOME:\n   ".$opt{"oh"}.
    "\n  does not exist or is not a directory.".
    "\n") if (defined($opt{"oh"}) && $opt{"oh"} != 1);
   &doPrint($log,2,"  Trying to find ORACLE_HOME in $ot file...\n");
   if (defined(open(IN, "< $ot")))
   { my @buf = <IN>;
     close(IN);
     foreach my $lin (grep (!/^#|^\s*$|^.*ASM.*\:|^\*/, @buf))
     { last if defined($oh);
       if ( $lin =~ /^.*\:(.*)\:/ )
       { $oh = &trim($1) if ( -d &trim($1) );
       }
     }
   }
   if (defined($oh) && (-d $oh))
   { &doPrint($log,2,"  Found ORACLE_HOME location in $ot file:\n");
     &doPrint($log,2,"   $oh\n");
     if ($interactive)
     { my $answer = 'N';
       do
       { &doPrint($log,2,"\n  Do you want to use this ORACLE_HOME? [Y/N]\n  ");
         $answer = <STDIN>;
         chomp ($answer);
         &doPrint($log,0,$answer."\n");
       } until ($answer =~ /Y|y|N|n/);
       if ($answer =~ /N|n/)
       { do
         { &doPrint($log,2,"\n  Please enter the ORACLE_HOME full path".
            " location: \n  ");
           $oh =  <STDIN>;
           chomp ($oh);
           &doPrint($log,0,$oh."\n");
           &doPrint($log,2,"  $oh does not exist or is not a".
            " directory.\n") if ! -d $oh;
         } while (! -d $oh);
       }
     }
   }
   else
   { if (! $interactive)
     { &doPrint($log,0,"  Could not find ORACLE_HOME location.\n".
        "  ORACLE_HOME will not be used.\n");
       $oh = undef;
     }
     else
     { &doPrint($log,2,"  Could not find ORACLE_HOME location in $ot".
        " file.\n");
       do
       { &doPrint($log,2,"  Please enter the ORACLE_HOME full path".
          " location: \n  ");
         $oh =  <STDIN>;
         chomp ($oh);
         &doPrint($log,0,$oh."\n");
         &doPrint($log,2,"  $oh does not exist or is not a".
          " directory.\n") if ! -d $oh;
       } while (! -d $oh);
     }
   }
 }
 else
 { &doPrint($log,2,"  ".$opt{"oh"}." does not exist or is not a".
    " directory.\n") if (defined($opt{"oh"}) && $opt{"oh"} != 1);
   &doPrint($log,2,"  ".$opt{"ot"}.", /etc/oratab and ".
    "/var/opt/oracle/oratab files\n  do not exist or are not".
    " readable.\n") if (defined($opt{"ot"}) && $opt{"ot"} != 1);
   if ($interactive)
   { &doPrint($log,2,"  Could not find ORACLE_HOME location\n");
     do
     { &doPrint($log,2,"  Please enter the ORACLE_HOME full path".
        " location: \n  ");
       $oh =  <STDIN>;
       chomp ($oh);
       &doPrint($log,0,$oh."\n");
       &doPrint($log,2,"  $oh does not exist or is not a".
        " directory.\n") if ! -d $oh;
     } while (! -d $oh);
   }
   else
   { &doPrint($log,2,"  Could not find ORACLE_HOME location.\n".
      "  ORACLE_HOME will not be used.\n");
     $oh = undef;
   }
 }
 &doPrint($log,2,"\n");
}

=head2 S<getSchematicFile()>

 This subroutine obtains the location of a readable schematic file.

 Schematic file types:
  1 catalog.xml
  2 databasemachine.xml

=cut

sub getSchematicFile
{ &doPrint($log,2," Schematic file\n --------------\n");
  if ( defined($opt{"typ"}) && ($opt{"typ"} == 1 || $opt{"typ"} == 2) )
  { if ( -r $sch )
    { &doPrint($log,2,"  Using specified schematic file:\n   $sch\n");
    }
    else
    { &doPrint($log,2,"  Specified schematic file:\n   $sch\n  was not ".
       "found.\n");
      if ( $typ == 1 )
      { $sch = "/opt/oracle.SupportTools/onecommand/databasemachine.xml";
        $typ = 2;
      }
      else
      { $sch = "/opt/oracle.SupportTools/onecommand/catalog.xml";
        $typ = 1;
      }
      &doPrint($log,2,"  Using alternative schematic file:\n   $sch\n");
      if ( ! -r $sch)
      { &doPrint($log,2,"  Alternative schematic file:\n   $sch\n  was ".
         "not found.\n  None of the default schematic files:\n   ".
         "catalog.xml or databasemachine.xml exist or are readable.\n\n".
         "  Schematic file will not be used.\n");
        $sch = undef;
        $typ = undef;
      }
    }
  }
  else
  { if ( -r $sch )
    { if (! $interactive)
      { &doPrint($log,2,"  Using default schematic file:\n   $sch\n");
      }
      else
      { &doPrint($log,2,"  Default schematic file full path location is:\n".
         "  $sch\n");
        my $answer = 'N';
        do
        { &doPrint($log,2,"\n  Do you want to use this schematic file?".
           " [Y/N]\n  ");
          $answer = <STDIN>;
          chomp ($answer);
          &doPrint($log,0,$answer."\n");
        } until ($answer =~ /Y|y|N|n/);
        if ($answer =~ /N|n/)
        { $sch = "/opt/oracle.SupportTools/onecommand/databasemachine.xml";
          $typ = 2;
          &doPrint($log,2,"  Using alternative schematic file:\n   $sch\n");
          if ( ! -r $sch)
          { &doPrint($log,2,"  Alternative schematic file:\n   $sch\n  was ".
             "not found.\n  None of the default schematic files:\n   ".
             "catalog.xml or databasemachine.xml exist or are readable.\n\n".
             "  Schematic file will not be used.\n");
            $sch = undef;
            $typ = undef;
          }
        }
      }
    }
    else
    { &doPrint($log,2,"  Default schematic file:\n   $sch\n  was not ".
        "found.\n");
      $sch = "/opt/oracle.SupportTools/onecommand/databasemachine.xml";
      $typ = "2";
      &doPrint($log,2,"  Using alternative schematic file:\n   $sch\n");
      if ( ! -r "/opt/oracle.SupportTools/onecommand/databasemachine.xml")
      { &doPrint($log,2,"  Alternative schematic file:\n   $sch\n  was not ".
         "found.\n  None of the default schematic files:\n   catalog.xml or ".
         "databasemachine.xml exist or are readable.\n\n".
         "  Schematic file will not be used.\n");
        $sch = undef;
        $typ = undef;
      }
    }
  }
  &doPrint($log,2,"\n");
}

=head2 S<handleChar($expat,$text)>

This subroutine is used when non-markup is recognized while parsing XML files.

=cut

sub handleChar
{ my( $expat, $text ) = @_ ;
  if (defined($xmlElem))
  { if ($xmlElem eq "TYPE")
    { $curType = $text;
    }
    elsif ($xmlElem eq "HOSTNAME")
    { $curHostName = $text;
    }
    elsif ($typ == 2 && $xmlElem eq "ADMINNAME")
    { $curAdminName = $text;
    }
    elsif ($typ == 2 && $xmlElem eq "ADMINIP")
    { $curAdminIp = $text;
    }
    elsif ($typ == 1 && $adm && $xmlElem eq "NAME")
    { $curAdminName = $text;
    }
    elsif ($typ == 1 && $adm && $xmlElem eq "DOMAIN")
    { $curAdminDomain = $text;
    }
    elsif ($typ == 1 && $adm && $xmlElem eq "IP")
    { $curAdminIp = $text;
    }
    elsif ($typ == 1 && $cli && $xmlElem eq "NAME")
    { $curClientName = $text;
    }
    elsif ($typ == 1 && $cli && $xmlElem eq "DOMAIN")
    { $curClientDomain = $text;
    }
    elsif ($typ == 1 && $cli && $xmlElem eq "IP")
    { $curClientIp = $text;
    }
  }
}

=head2 S<handleEnd($expat,$element)>

This subroutine is used when an XML end tag is recognized while parsing XML
files. Note that an XML empty tag (<foo/>) generates both a start and an end
events.

=cut

sub handleEnd
{
  my( $expat, $element ) = @_;
  if ($typ == 1 && $element eq "ADMIN")
  {$adm = 0;
  }
  if ($typ == 1 && $element eq "CLIENT")
  {$cli = 0;
  }
  elsif (($element eq "ITEM") &&
      (defined($curAdminName)))
  { $curComp = Component->new($curAdminDomain,$curAdminIp,$curAdminName,
                              $curClientDomain,$curClientIp,$curClientName,
                              $curHostName,$curId,$curType);
    push(@comp, $curComp);
    $curComp = Component->new($curAdminDomain,$curAdminIp,$curAdminName,
                              undef,undef,undef,
                              $curHostName,$curId,$curType);
    push(@elem, $curComp);
    if ($typ == 1 && defined($curClientName) && defined($curClientIp))
    { $curComp = Component->new(undef,undef,undef,
                                $curClientDomain,$curClientIp,$curClientName,
                                $curHostName,$curId,$curType);
      push(@elem, $curComp);
    }
    if ( $curType eq "cellnode" || $curType eq "cell" )
    { push(@schCel, $curAdminName);
    }
    if ( $curType eq "ib" || $curType eq "ibl" || $curType eq "ibs" )
    { push(@schIb, $curAdminName);
    }
    if ( $curType eq "kvm")
    { push(@schKvm, $curAdminName);
    }
    if ( $curType eq "pdu")
    { push(@schPdu, $curAdminName);
    }
  }
  $xmlElem = undef;
}

=head2 S<handleStart($expat,$element[,%attrs])>

This subroutine is used when an XML start tag is recognized while parsing XML
files. C<$element> is the name of the XML element type that is opened with the
start tag. The C<%attrs> is generated for each attribute in the start tag.

=cut

sub handleStart
{ my( $expat, $element, %attrs ) = @_;
  $xmlElem = $element ;
  if ($typ == 1 && $element eq "ADMIN")
  { $adm = 1;
  }
  elsif ($typ == 1 && $element eq "CLIENT")
  { $cli = 1;
  }
  elsif ($element eq "ITEM")
  { $curId = $attrs{"ID"};
    $curType = undef;
    $curHostName = undef;
    $curAdminName = undef;
    $curAdminDomain = undef;
    $curAdminIp = undef;
    $curClientDomain = undef;
    $curClientIp = undef;
    $curClientName = undef;
  }
}

=head2 S<parseEmParamFile()>

This subroutine parses /opt/oracle.SupportTools/onecommand/em.param file.
It looks for cell, infiniband switch, KVM and PDU nodes. It stores the
cell nodes on C<@emCel> global array, the infiniband switch nodes on C<@emIb>
global array, the KVM nodes on C<@emKvm> global array and the PDU nodes on
C<@emPdu> global array for further use. It also shows the list of nodes found.

=cut

sub parseEmParamFile
{ &doPrint($log,2,"\nParsing Enterprise Manager parameter (em.param) file...\n".
   "-------------------------------------------------------\n");
  if ( defined($emp) )
  { &doPrint($log,2," File to parse:\n  $emp\n\n");
    if (!defined(open(IN, "< $emp")))
    { &doPrint($log,2," Could not open parameter file ===> Not ok\n\n".
       " * Please check that the file exists and is readable.\n");
    }
    else
    { my @buf = <IN>;
      close(IN);
      foreach my $lin (grep(
                         /^EM_CELLS=|^swiib.*name=|^swikvm.*name=|^pdu.*name=/,
                         @buf))
      { if ( $lin =~ /^EM_CELLS=(.*)$/ )
        { $lin = &trim(&replace(&replace(&trim($1),'\(',' ',1),'\)',' ',1));
          foreach my $hst (split(/\s+/, $lin))
          { push(@emCel,$hst);
          }
        }
        elsif ( $lin =~ /^swiib.*name=(.*)$/ )
        { $lin = &trim($1);
          push(@emIb,$lin);
        }
        elsif ( $lin =~ /^swikvm.*name=(.*)$/ )
        { $lin = &trim($1);
          push(@emKvm,$lin);
        }
        elsif ( $lin =~ /^pdu.*name=(.*)$/ )
        { $lin = &trim($1);
          push(@emPdu,$lin);
        }
      }
      &doPrint($log,2," Parameter file parsed successfully ===> Ok\n\n".
       " Cell nodes found in em.param file:\n  @emCel\n\n Infiniband switches".
       " found in em.param file:\n  @emIb\n\n KVM nodes found in em.param".
       " file:\n  @emKvm\n\n PDU nodes found in em.param file:\n  @emPdu\n");
    }
  }
  else
  {&doPrint($log,2," Skipping as could not find provided or default".
    " Enterprise Manager parameter\n (em.param) file.\n");
  }
  &doAckPause();
}

=head2 S<parseSchematicFile()>

This subroutine parses the schematic ile.
It stores the nodes found on C<@comp> global array for further use.
Additionally it stores the cell nodes on C<@schCel> global array, the
infiniband switch nodes on C<@schIb> global array, the KVM nodes on C<@schKvm>
global array and the PDU nodes on C<@schPdu> global array for further use.
It also shows the list of nodes found.

=cut

sub parseSchematicFile
{ &doPrint($log,2,"\nParsing schematic file...\n-------------------------\n");
  if ( defined($sch) )
  { &doPrint($log,2," File to parse:\n  $sch\n");
    &doPrint($log,2,"  Schematic file type: $typ");
    &doPrint($log,2," (catalog)") if $typ == 1;
    &doPrint($log,2," (databasemachine)") if $typ == 2;
    &doPrint($log,2,"\n");
    &checkSchematicFilePermissions();
    &checkSchematicFileVersion();
    &doPrint($log,2,"\n Parsing schematic file...\n".
     " -------------------------\n");
    if (! -r $sch)
    { &doPrint($log,2,"  Skipping as schematic file permissions are not ok.\n");
      $sch = undef;
    }
    elsif (($typ == 1 and $verSch< 868) or
           ($typ == 2 and $verSch< 502) or
           (! defined($verSch)))
    { &doPrint($log,2,"  Skipping as schematic file version is not ok.\n");
      $sch = undef;
    }
    else
    { if ( (scalar @schContent) <= 0 )
      { &doPrint($log,2,"\n Could not open schematic file ===> Not ok\n\n".
         " * Please check that the file exists and is readable.\n");
      }
      else
      { my $xmlout = join("",@schContent);
        my $parser = XML::Parser->new( Handlers =>
                                       { Start   => \&handleStart,
                                         End     => \&handleEnd,
                                         Char    => \&handleChar,
                                        });
        eval
        { $parser->parse($xmlout);
        };
        if ($@)
        { &doPrint($log,2,"  Schematic file XML Parser Error $@ ===> ".
           "Not ok\n\n  * Please verify that schematic file contains correct ".
           "information.\n");
        }
        else
        { &doPrint($log,2,"  Schematic file parsed successfully ===> Ok\n\n".
           "  Cell nodes found in schematic file:\n   @schCel\n\n  Infiniband".
           " switches found in schematic file:\n   @schIb\n\n  KVM nodes found".
           " in schematic file:\n   @schKvm\n\n  PDU nodes found in schematic".
           " file:\n   @schPdu\n");
        }
      }
    }
  }
  else
  {&doPrint($log,2," Skipping as could not find provided or default schematic".
    " file.\n");
  }
  &doAckPause();
}

=head2 S<promptPassword($txt[,$ech[,$spc]])>

This subroutine prompts for a password. By default it will try to suppress the
character echo for password entry when supported by the installed Perl version.

Second argument will be used to indicate if echo character should be
suppressed. Third argument will be used for text indentation.

It returns the captured password.

=cut

sub promptPassword
{ my ($txt, $ech, $spc) = @_;
  my $pwd;

  # Assume a default input prompt and text indentation
  $ech = 0 unless defined($ech);
  $spc = "" unless defined($spc);
  $txt = "Please enter the password: " unless defined($txt);
  $txt =~ s/[\s\r\n]+$/ /;

  print $spc.$txt;
  if (-t STDIN && $ech eq 0 )
  { system "stty -echo 2> /dev/null";
    do
    { unless (defined($pwd = <STDIN>))
     { print "\n".$spc."Failure to enter the password\n";
     }
    } until (defined($pwd));
    system "stty echo 2> /dev/null";
    print "\n";
  }
  else
  {
    $pwd=<STDIN>;
    print "\n" unless -t STDIN;
  }
  chomp ($pwd);
  return $pwd;
}

=head2 S<replace($str,$re[,$str[,$flg]])>

This subroutine replaces the first occurrence of the C<$re> pattern by C<$str>.
When the flag is set, it replaces all occurrences.

=cut

sub replace
{ my ($str, $re1, $re2, $flg) = @_;

  if (defined($str) && defined($re1))
  { $re2 = '' unless defined($re2);
    if ($flg)
    { $str =~ s#$re1#$re2#mg;
    }
    else
    { $str =~ s#$re1#$re2#m;
    }
  }
  $str;
}

=head2 S<runSshCommand($hst, $usr, $pwd, $cmd)>

Exadata supports Linux and Solaris
The perl distribution shipped with emagent does not have modules we need.
Use expect to invoke ssh since ssh takes input from terminal, not stdin.

This subroutine runs the specified command in the specidiced host using SSH.
It uses the provided user and password to connect to the host.
It updates global variable C<@obj> with the command output.
It manages special grep command executions.
It returns 1 in case of success, or 0 in case of failure.

=cut

sub runSshCommand
{ my ($hst, $usr, $pwd, $cmd) = @_;
  my ($exp, $grepCmd, $grepCount, $grepScript, $pid,
      $status) = ("/usr/bin/expect", undef, undef, undef, undef, undef);
  my $script =
    "set timeout 120\n" .
    "match_max -d 1000000\n" .
    "spawn -noecho /usr/bin/ssh -o StrictHostKeyChecking=no " .
    "-o ConnectTimeout=30  -o PreferredAuthentications=password " .
    "-o NumberOfPasswordPrompts=1 $usr\@$hst $cmd\n" .
    "expect {\n" .
    "  \"*assword:*\" {\n" .
    "     send -- \"$pwd\\r\"\n" .
    "     expect {\n" .
    "       eof\n" .
    "     }\n" .
    "  }\n" .
    "}\n" .
    "catch wait result\n" .
    "set rcode [lindex \$result 3]\n" .
    "if { \$rcode != 0 } {\n" .
    "  exit \$rcode\n" .
    "}\n";

  if (!(-e $exp))
  { return 0;
  }

  if ( $cmd =~ /^\/bin\/grep (.*)$/ )
  { $grepCmd = "/bin/grep -c ".$1;
    $grepScript =
      "set timeout 120\n" .
      "match_max -d 1000000\n" .
      "spawn -noecho /usr/bin/ssh -o StrictHostKeyChecking=no " .
      "-o ConnectTimeout=30  -o PreferredAuthentications=password " .
      "-o NumberOfPasswordPrompts=1 $usr\@$hst $grepCmd\n" .
      "expect {\n" .
      "  \"*assword:*\" {\n" .
      "     send -- \"$pwd\\r\"\n" .
      "     expect {\n" .
      "       eof\n" .
      "     }\n" .
      "  }\n" .
      "}\n" .
      "catch wait result\n" .
      "set rcode [lindex \$result 3]\n" .
      "if { \$rcode != 0 } {\n" .
      "  exit \$rcode\n" .
      "}\n";

    eval
    { $pid = open2(*BUFP, *INPUT, "$exp");
    };
    if ($@)
    { return 0;
    }

    print INPUT "$grepScript";
    close(INPUT);

    my $out = "";
    my $line = "";;
    @out = ();
    while (<BUFP>)
    { $line = $_;
      $out .= $line;
      push(@out,$line);
    }
    close(BUFP);

    # Need to avoid running out of resources
    waitpid($pid, 0);

    if ( (scalar @out) > 0 )
    { $grepCount = &trim($out[-1]) if &trim($out[-1]) =~ /^\d+$/;
    }
  }

  eval
  { $pid = open2(*BUFP, *INPUT, "$exp");
  };
  if ($@)
  { return 0;
  }

  print INPUT "$script";
  close(INPUT);

  my $out = "";
  my $line = "";;
  @out = ();
  while (<BUFP>)
  { $line = $_;
    $out .= $line;
    push(@out,$line);
  }
  close(BUFP);

  # Need to avoid running out of resources
  waitpid($pid, 0);

  $status = $? >> 8;

  # If ssh call fails for any reason
  if (! defined($grepCount) and $status != 0)
  { return 0;
  }

 return 1;
}

=head2 S<showCollectedSetupData()>

This subroutine shows the collected setup date.
It shows the agent installation and ORACLE_HOME directories, along with
em.param and schematic file locations.

=cut

sub showCollectedSetupData
{ &doPrint($log,2,"\nSetup information used:\n-----------------------\n".
   " Agent installation directory: ");
  if ( defined($aid) )
  { &doPrint($log,2,"$aid\n");
  }
  else
  { &doPrint($log,2,"No agent installation present\n");
  }
  &doPrint($log,2," Enterprise Manager parameter file: ");
  if ( defined($emp) )
  { &doPrint($log,2,"$emp\n");
  }
  else
  { &doPrint($log,2,"No em.param file was found\n");
  }
  &doPrint($log,2," ORACLE_HOME: ");
  if ( defined($oh) )
  { &doPrint($log,2,"$oh\n");
  }
  else
  { &doPrint($log,2,"No ORACLE_HOME was found\n");
  }
  &doPrint($log,2," Schematic file: ");
  if ( defined($sch) )
  { &doPrint($log,2,"$sch\n");
  }
  else
  { &doPrint($log,2,"No schematic file was found\n");
  }
  &doPrint($log,2," Schematic file type: ");
  if ( defined($typ) )
  { &doPrint($log,2,"$typ");
    &doPrint($log,2," (catalog)") if $typ == 1;
    &doPrint($log,2," (databasemachine)") if $typ == 2;
    &doPrint($log,2,"\n");
  }
  else
  { &doPrint($log,2,"No schematic file type was defined\n");
  }

  &doAckPause();
}

=head2 S<showHeader()>

This subroutine shows the script header in STDOUT.

=cut

sub showHeader
{ &doPrint($log,1,"\n*********************************************************".
 "*****\n".
 "* Enterprise Manager Exadata Pre-Discovery checks            *\n".
 "**************************************************************\n".
 "Running script from ".cwd()."\n".
 "Script used is ".dirname($0)."/".basename($0)."\n".
 "\nObtaining setup information...\n------------------------------\n")
 if ($debug or $interactive);
}

=head2 S<showLogHeader()>

This subroutine shows the script header in the log file.

=cut

sub showLogHeader
{ &doPrint($log,0,"\n*********************************************************".
 "*****\n".
 "* Enterprise Manager Exadata Pre-Discovery checks            *\n".
 "**************************************************************\n".
 "Running script from ".cwd()."\n".
 "Script used is ".dirname($0)."/".basename($0)."\n".
 "\nObtaining setup information...\n------------------------------\n");
&doPrint($log,2,"\n");
}

=head2 S<showProgress($progress)>

This subroutine displays a progress bar.
Argument indicates progress to show.

=cut

sub showProgress {
   my ($progress) = @_;
   my $dots   = '.....' x int($progress*10);
   my $percent = int($progress*100);
   if ( $percent >= 100 )
   { print("\rDone.                                                        ");
   }
   else
   { print("\r$dots $percent%");
   }
   flush(<STDOUT>);
}

=head2 S<timestamp()>

This subroutine generates the timestamp user for log file name creation.

=cut

sub timestamp {
  my $t = localtime;
  return sprintf( "%04d-%02d-%02d_%02d-%02d-%02d",
                  $t->year + 1900, $t->mon + 1, $t->mday,
                  $t->hour, $t->min, $t->sec );
}

=head2 S<trim($str[,$del])>

This subroutine trims all leading and trailing spaces. You can specify extra
characters to trim as a second argument.

=cut

sub trim
{ my ($str, $del) = @_;

  if (defined($str))
  { $str =~ s/^\s+//g;
    $str =~ s/\s+$//g;
    if ($del)
    { $str =~ s#^$del##;
      $str =~ s#$del$##;
    }
  }
  $str;
}

=head2 S<validVersion($ver1,$ver2)>

This subroutine validates C<$ver1> compared to C<$ver2>. True if C<$ver1> is
newer than or the same version as C<$ver2>

=cut

sub validVersion
{ my ($ver1, $ver2) = @_;
  my ($str1, $str2, $val);

  ($ver1, $str1) = split('-', $ver1);
  ($ver2, $str2) = split('-', $ver2);

  $val = &compareVersions($ver1, $ver2);
  return 0 if $val < 0;
  return 1 if $val > 0;
  if (defined($str2))
  { return 0 unless defined($str1) && (lc($str1) ge lc($str2));
  }
  1;
}

# Object to represent a rack component
package Component;

=head1 PACKAGE NAME

Component - Class Used to store Rack components and their attributes.

=head1 DESCRIPTION

The objects of the C<Component> class are used to store Rack components and
their attributes.

The following methods are available:

=cut

=head2 S<$h = Component-E<gt>new($adminDomain,$adminIp,$adminName,$clientDomain,$clientIp,$clientName,$hostName,$id,$type)>

The object constructor. It takes the admin node IP address, admin node name,
host name,component Id and node type as arguments.

C<Component> is represented by a blessed hash reference. The following
special keys are used:

=over 12

=item S<    B<'adminDomain'> > Admin node domain

=item S<    B<'adminIp'> > Admin node IP address

=item S<    B<'adminName'> > Admin node name

=item S<    B<'clientDomain'> > Client node domain

=item S<    B<'clientIp'> > Client node IP address

=item S<    B<'clientName'> > Client node name

=item S<    B<'hostName'> > Host name

=item S<    B<'id'> > Component Id

=item S<    B<'type'> > Node type

=cut

sub new
{ my $class = shift;
  my $self = { adminDomain => shift,
               adminIp => shift,
               adminName => shift,
               clientDomain => shift,
               clientIp => shift,
               clientName => shift,
               hostName => shift,
               id => shift,
               type => shift
             };
  bless $self, $class;
  return $self;
}

=back

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2012, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
