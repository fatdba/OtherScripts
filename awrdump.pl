#!/usr/bin/perl
# Copyright (c) 1989, 2021, Oracle and/or its affiliates.
# All rights reserved.
#
# NAME
#   awrdmp.pl
#
# FUNCTION
#   Manages
#
# RETURNS
#   None.
#
# NOTES
#   None.
#
# MODIFIED
#   mmalvezz     10/11/21  - Initial version
#   mmalvezz     15/11/21  - manage container databases
#   mmalvezz     12/02/22  - add html2text feature

### -------------------------------------------------------------------
### Disclaimer:
###
### EXCEPT WHERE EXPRESSLY PROVIDED OTHERWISE, THE INFORMATION, SOFTWARE,
### PROVIDED ON AN \"AS IS\" AND \"AS AVAILABLE\" BASIS. ORACLE EXPRESSLY DISCLAIMS
### ALL WARRANTIES OF ANY KIND, WHETHER EXPRESS OR IMPLIED, INCLUDING, BUT NOT
### LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
### PURPOSE AND NON-INFRINGEMENT. ORACLE MAKES NO WARRANTY THAT: (A) THE RESULTS
### THAT MAY BE OBTAINED FROM THE USE OF THE SOFTWARE WILL BE ACCURATE OR
### RELIABLE; OR (B) THE INFORMATION, OR OTHER MATERIAL OBTAINED WILL MEET YOUR
### EXPECTATIONS. ANY CONTENT, MATERIALS, INFORMATION OR SOFTWARE DOWNLOADED OR
### OTHERWISE OBTAINED IS DONE AT YOUR OWN DISCRETION AND RISK. ORACLE SHALL HAVE
### NO RESPONSIBILITY FOR ANY DAMAGE TO YOUR COMPUTER SYSTEM OR LOSS OF DATA THAT
### RESULTS FROM THE DOWNLOAD OF ANY CONTENT, MATERIALS, INFORMATION OR SOFTWARE.
###
### ORACLE RESERVES THE RIGHT TO MAKE CHANGES OR UPDATES TO THE SOFTWARE AT ANY
### TIME WITHOUT NOTICE.
###
### Limitation of Liability:
###
### IN NO EVENT SHALL ORACLE BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
### SPECIAL OR CONSEQUENTIAL DAMAGES, OR DAMAGES FOR LOSS OF PROFITS, REVENUE,
### DATA OR USE, INCURRED BY YOU OR ANY THIRD PARTY, WHETHER IN AN ACTION IN
### CONTRACT OR TORT, ARISING FROM YOUR ACCESS TO, OR USE OF, THE SOFTWARE.
### -------------------------------------------------------------------
### This tool is NOT supported by Oracle World Wide Technical Support.
### The tool has been tested and appears to work as intended.
### -------------------------------------------------------------------

BEGIN {
   die "ORACLE_HOME not set\n" unless $ENV{ORACLE_HOME};
   unless ( $ENV{OrAcLePeRl} ) {
      $ENV{OrAcLePeRl} = "$ENV{ORACLE_HOME}/perl";
      $ENV{PERL5LIB}   = "$ENV{PERL5LIB}:\
      $ENV{OrAcLePeRl}/lib:$ENV{OrAcLePeRl}/lib/site_perl";
      $ENV{LD_LIBRARY_PATH} = "$ENV{LD_LIBRARY_PATH}:\
      $ENV{ORACLE_HOME}/lib32:$ENV{ORACLE_HOME}/lib";
      exec "$ENV{OrAcLePeRl}/bin/perl", $0, @ARGV;
   }
}

use strict;
use warnings;
use POSIX;
use DBD::Oracle;
use Term::ANSIColor;
use Getopt::Long qw(GetOptions);
use Pod::Usage;
use Cwd;

use sigtrap qw(die untrapped normal-signals stack-trace any error-signals);
use constant TRUE    => 0;
use constant FALSE   => 1;
use constant ERROR   => 1;
use constant SUCCESS => 0;

my @row = ();
my @dbl = ();
my $pwd = getcwd();
my $rwf;
my $debug ;

my $usr;
my $psw;
my $tns;
my $fre = 1;
my $dmp = "dumpdir";
my $minsnapid;
my $maxsnapid;
my $mindate;
my $maxdate;
my $smindate = 0;
my $smaxdate = 0;
my $handle;
my $option;
my $batch;
my $list;
my $ins;
my $dbi;
my $dbn;
my $mode;
my $rac;
my $function;
my $cdb;
my $reportpath;
my $printSQL=FALSE;
my $help;
my $html2text;
my $LynxAvailable=TRUE;
my $rmhtml;
my $LYNX="/usr/bin/lynx";
my $RM="/bin/rm";
my $offlinedir;

my %SessionAttribute = (
   ora_oci_success_warn => 0,
   ora_session_mode     => 2,
   RaiseError           => 0,
   PrintError           => 0,
);

if ( ! -e $LYNX ) {
   $LynxAvailable=FALSE;
   }

GetOptions(
   'rac'                => \$rac,
   'batch'              => \$batch,
   'list'               => \$list,

   #  'username=s' => \$usr,
   #  'password=s' => \$psw,
   #  'tnsalias=s' => \$tns,
   'freq=i'            => \$fre,
   'instid=i'          => \$ins,
   'dbid=s'            => \$dbi,
   'begin=s'           => \$smindate,
   'end=s'             => \$smaxdate,
   'mode=s'            => \$mode,
   'dbn=s'             => \$dbn,
   'html2text'         => \$html2text,
   'rmhtml'            => \$rmhtml,
   'offlinedir=s'      => \$offlinedir,
   'help'              => \$help,
  )
  or die
"Usage: $0 --rac --batch  --freq FREQ --instid ID --dbid DBID --begin DD/MM/YYYY --end  DD/MM/YYYY  --dbn dbname --mode text/html --html2text --rmhtml --offlinedir \n";

if ( defined $help ) {
   pod2usage( -exitval => 0, -verbose => 3 );
}

if ( defined $offlinedir ) {
   if ( $LynxAvailable==FALSE ) {
      printf "ERROR: lynx is not istalled - cannot convert html report \n";
      exit(ERROR);
   }

   if ( ! -e $offlinedir ) {
      printf "ERROR: directory $offlinedir does not existss\n";
      exit(ERROR); 
   }

  if ( ! opendir (DIRAWR,$offlinedir) ) {
      printf "ERROR: $offlinedir Permission denied\n";
     exit(ERROR);
  }

  if ( not -w $offlinedir ) {
      printf "ERROR: $offlinedir is not writteable \n"; 
     exit(ERROR);
  }

  my @FileList=grep { /\.html/ && -f "$offlinedir/$_" } readdir(DIRAWR);
  my $ListSize=scalar(@FileList);
  printf "OFFLINE AWR REPORT CONVERTION HTML->TEXT\n";
  printf "Num. html reports:\t%d\n",$ListSize;
  my $htmlfile;
  my $cnt;
  my $lnsz=72;
  my $sg0;
  my $sg1;
  my $pct;
 
  foreach  $htmlfile (@FileList){
    ConvertHtml2Text($offlinedir . "/" . $htmlfile);
    $cnt++;
   $pct=100*($cnt/$ListSize);
   my $sg0=sprintf("%s" ,"=" x ceil($lnsz*( ($cnt) / ( ($ListSize)))));
   my $sg1=sprintf("%s" ," " x ($lnsz-ceil($lnsz*( ($cnt) / ( ($ListSize))))));
   printf "\r[%3d%s][%s%s]",$pct,chr(37),$sg0,$sg1;
    
  } 
  printf "\n";
  exit(SUCCESS);
}  


if ( not defined $batch ) {
   print "Enter usrname: - ";
   $usr = <>;

   print "Enter password: - ";
   system("stty -echo");
   chop( $psw = <> );
   print "\n";
   system("stty echo");

   print "Enter tnsalias: - ";
   $tns = <>;

   print "Enter frequency - ";
   $fre = <>;

   print "Enter mode\n(text/html) - ";
   $mode = <>;
   if ( $mode !~ m/text{1}|html{1}/i ) {
      printf("Setting mode to text\n");
      $mode = "text";
   }

   $usr =~ s/\n//g;
   $psw =~ s/\n//g;
   $tns =~ s/\n//g;
   $fre =~ s/\n//g;
   $mode =~ s/\n//g;

   if ( length($tns) != 0 ) {
      $usr .= "\@";
      $usr .= $tns;
   }
   if ( length($fre) == 0 ) { $fre = 1; }
}

#if (defined $batch)
#{
#  if (defined $tns) {
#        $usr .= "\@";
#        $usr .= $tns;
#    }
#
#}

my $dbh;
if ( not defined $usr )  { $usr  = ''; }
if ( not defined $psw )  { $psw  = ''; }
if ( not defined $mode ) { $mode = "text"; }

if ( length($usr) != 0 && length($psw) != 0 ) {
   $dbh =
     DBI->connect( 'dbi:Oracle:', $usr, $psw, { ora_oci_success_warn => 0 } );
   print "CONNECTED TO  $usr\n";
}

if ( length($usr) == 0 && length($psw) == 0 ) {
   $dbh =
     DBI->connect( 'dbi:Oracle:', 'SYS /AS SYSDBA', '', \%SessionAttribute );
   print "CONNECTED AS SYSDBA  $usr\n";
}

my $ora_server_version = $dbh->func("ora_server_version");

print("RDBMS VERSION: ");
printf(
   "%i.%i.%i.%i.%i\n\n",
   $ora_server_version->[0], $ora_server_version->[1],
   $ora_server_version->[2], $ora_server_version->[3],
   $ora_server_version->[4]
);

if ( $ora_server_version->[0] < 12 ) {
   printf "RDBMS VERSTION TOO OLD\n";
   exit;
}

if ( ( $mode eq 'html' ) && ( defined $html2text )  && ( $LynxAvailable==FALSE ) ) {
    printf "WARNING: lynx is not istalled: html to text conversion is not available\n";
    printf "AWR will be extracted anyway\n";
}

$cdb = CheckContainer();

if ( $ora_server_version->[0] < 10
   || ( $ora_server_version->[0] = 12 && $ora_server_version->[0] < 2 ) )
{
   print "AWR NOT AVAILABLE FOR THIS RDBMS VERSION \n";
   exit(ERROR);
}

#Just show the list of awr collections present in the rep
if ( defined $batch and defined $list ) {
   ShowCatalog();
   exit;
}

if ( !-d $dmp ) {
   print "Creating directory $dmp\n";
   mkdir $dmp;
}

### Select database in the repository ###

ShowCatalog();

if ( not defined $batch ) {
   printf "Enter database num: [0,%i] -: ", $rwf - 1;
   $option = <>;
}

if ( defined $debug and not defined $batch ) {
   printf(
      "%4i %10s %7s %10s %10s %20s\n",
      $option,          $dbl[$option][0], $dbl[$option][1],
      $dbl[$option][2], $dbl[$option][3], $dbl[$option][4]
   );
}

$handle->finish();
$rwf = 0;
@row = ();

# Identify the snap id range
my $sqlrange = "select  min(snap_id),
                      min(begin_interval_time),
                      max(snap_id),
                      max(begin_interval_time)
                      from dba_hist_snapshot 
                      where dbid=? and INSTANCE_NUMBER=?";

if ( not defined $batch ) {
   $dbi = $dbl[$option][0];
   $ins = $dbl[$option][1];
   $dbn = $dbl[$option][2];
}

if ( defined $rac ) {
   $function = "awr_global_report_" . $mode;
}

if ( not defined $rac ) {
   $function = "awr_report_" . $mode;
}

$handle = $dbh->prepare($sqlrange);
$handle->bind_param( 1, $dbi );
$handle->bind_param( 2, $ins );

$handle->execute();
( $minsnapid, $mindate, $maxsnapid, $maxdate ) = $handle->fetchrow_array();

print "RANGE AVAILABLE IN REPOSITORY ";
print "FOR DBID $dbi INST $ins:\n";
print("------------------------------------------------------\n");
printf( "[%s %s : %s %s] \n", $minsnapid, $mindate, $maxsnapid, $maxdate );

$handle->finish();

if ( not defined $batch ) {
   while ( $smindate !~ /(\d\d)\/(\d\d)\/(\d{4})/ ) {
      print "Enter the minimum date interval (DD/MM/YYYY) -: ";
      $smindate = <>;
   }

   while ( $smaxdate !~ /(\d\d)\/(\d\d)\/(\d{4})/ ) {
      print "Enter the maximum date interval (DD/MM/YYYY) -: ";
      $smaxdate = <>;
   }
}

my $sqlsnapid = "select snap_id from dba_hist_snapshot
               where dbid=? and INSTANCE_NUMBER=? 
               and begin_interval_time between to_date(?,'DD/MM/YYYY')
               and to_date(?,'DD/MM/YYYY')+1 order by snap_id";

$handle = $dbh->prepare($sqlsnapid);
$handle->bind_param( 1, $dbi );
$handle->bind_param( 2, $ins );
$handle->bind_param( 3, $smindate );
$handle->bind_param( 4, $smaxdate );
$handle->execute();

my $snapid;
my @snparr;
while ( $snapid = $handle->fetchrow_array() ) {
   push( @snparr, $snapid );
}

my $sizear = scalar(@snparr);

if ( $sizear == 0 ) {
   print "\n-- NO SNAPSHOT FOUND IN THE SNAPSHOT ID RANGE --\n";
   exit;
}

$handle->finish();

my $sqlawr = "select rtrim(output,' ') 
    from table(dbms_workload_repository." . "$function( ?, ?, ?, ?, 0 ))";

$handle = $dbh->prepare($sqlawr);

local $| = 1;
my $pct = 0;

print "output directory:$pwd/$dmp\n";
print color 'bold red';
print colored( "GENERATING FILES\n", "blink" );

#for ($cnt = 0 ; $cnt < $sizear - 1 ; $cnt+$fre)
my $cnt = 0;
if ( defined $rac ) {
   $ins = "";
}

my $lnsz;
my $sg0;
my $sg1;

while ( $cnt + $fre < $sizear - 1 ) {

   $pct = 100 * ( ($cnt+$fre) /  ($sizear-2)  );
   
   if ( not defined $rac ) {
     $reportpath="$dmp/report_$ins\_$dbn\_$snparr[$cnt]_$snparr[$cnt+$fre].$mode";
   }
   else {
     $reportpath="$dmp/report_RAC_$dbn\_$snparr[$cnt]_$snparr[$cnt+$fre].$mode";
   }

   if( defined $debug ) {
         printf( "\r[%3d %s] writing file : report_%i_%s_%i_%i.%s \n",
       	 $pct, chr(37), $ins, $dbn, $snparr[$cnt], $snparr[ $cnt + $fre ], $mode );
   } 

    $lnsz=72;
    $sg0=sprintf("%s" ,"=" x ceil($lnsz*( ($cnt+$fre) / ( ($sizear-2)))));
    $sg1=sprintf("%s" ," " x ($lnsz-ceil($lnsz*( ($cnt+$fre) / ( ($sizear-2))))));
   printf "\r[%3d%s][%s%s]",$pct,chr(37),$sg0,$sg1;
   
   open( AWRDMP,">$reportpath");

   $handle->bind_param( 1, $dbi );
   $handle->bind_param( 2, $ins );
   $handle->bind_param( 3, $snparr[$cnt] );
   $handle->bind_param( 4, $snparr[ $cnt + $fre ] );

   if ( $printSQL == TRUE ) {
      printf
"select rtrim(output,' ') from table(dbms_workload_repository.$function( %s, %s, %s, %s, 0 ))",
	$dbi, $ins, $snparr[$cnt], $snparr[ $cnt + $fre ];
   }

   $handle->execute();

   print AWRDMP "\n";
   while ( @row = $handle->fetchrow_array() ) {
      if   ( defined $row[0] ) { print AWRDMP "$row[0]" . "\n"; }
      else                     { print AWRDMP "\n"; }

      # warn "Error ----> \n" if $DBI::err;
   }

   if ( ( $mode eq "html" )  && ( defined $html2text ) && ( $LynxAvailable ==TRUE ) ) {
       ConvertHtml2Text($reportpath)
   }

   close(AWRDMP);
   $cnt = $cnt + $fre;
}

print "\n";
$handle->finish();
$dbh->disconnect;

printf "Check $pwd/$dmp\n";
printf "[.........]\n";
printf "[.........]\n";
printf "[.........]\n";
printf "[.........]\n";

system("ls -ltr $pwd/$dmp| tail -4");

sub ShowCatalog {
   my $cdb     = CheckContainer();
   my $sqlreps = "select distinct
       wr.dbid            dbbid
     , wr.instance_number instt_num
     , wr.db_name         dbb_name
     , wr.instance_name   instt_name
     , wr.host_name       host
     , wr.con_id          con_id 
  from dba_hist_database_instance wr
    where wr.con_id = ? ";

   $handle = $dbh->prepare($sqlreps);
   $handle->bind_param( 1, $cdb );
   $handle->execute();

   while ( @row = $handle->fetchrow_array() ) {
      if ( defined $row[0] ) {
	 $rwf++;
	 push( @dbl, [@row] );

      }
      else { print "\n"; }
   }

   printf "\342" x 80 ;
   printf "\n";
   print(
"---- ---------- ------- ---------- ---------- -------------------- ------\n"
   );
   print(
" NUM       DBID  INSTID     DBNAME     INSTID              MACHINE CONTID\n"
   );
   print(
"---- ---------- ------- ---------- ---------- -------------------- ------\n"
   );
   for ( my $cnt = 0 ; $cnt < $rwf ; $cnt++ ) {
      printf(
	 "%4i %10s %7s %10s %10s %20s %6s\n",
	 $cnt,          $dbl[$cnt][0], $dbl[$cnt][1], $dbl[$cnt][2],
	 $dbl[$cnt][3], $dbl[$cnt][4], $dbl[$cnt][5]
      );
   }
   print "\n";
   @row = ();

   printf "\342" x 80 ;
   printf "\n";
}

sub CheckContainer {
   my $incdb;
   my $cdbid;
   my $sqlcheckcontainer =
     " select upper(CDB), sys_context('USERENV','CON_ID') from   v\$database";
   my $sqlsetcontaier = "select sys_context('userenv','con_dbid') from dual";

   $handle = $dbh->prepare($sqlcheckcontainer);
   $handle->execute;
   ( $incdb, $cdbid ) = $handle->fetchrow_array();
   $handle->finish;

   if ( $cdbid < 3 ) { return (0) }
   return ($cdbid);
}

sub ConvertHtml2Text {

   my $htmlfile=shift;
   my $textfile = $htmlfile ;

   $textfile =~ s/\.html/\.text/g  ;
   system("$LYNX   -dump -nonumbers -hiddenlinks=ignore -width=300  $htmlfile |grep -v \"file:\" > $textfile");

   if ( defined $rmhtml ) {
    system("$RM  $htmlfile");
   }

}

__END__

=head1 NAME

awrdmp.pl - awr time series generator

=head1 SYNOPSIS

perl B<awrdmp.pl> [-rac] [--batch  [--freq FREQ] [--instid ID] [--dbid DBID] [--begin DD/MM/YYYY --end  DD/MM/YYYY]  [--dbn dbname] [--mode text/html] --list ] 

=head1 DESCRIPTION

This script generates a timeseries of awr report for a given database in a awr repository. It connects to database via oracle sid on the db server or via tnsalias. To run the script just execute B<perl awrdmp.pl> . To connect via oracle sid do not specify username password and tnsalias. In order to have sixty minutes time-series reports do not specify frequency if awr snapshot is executed every 60 minutes (default awr setting), set frequency 2 if awr snapshot is executed every 30 mins , 4 if awr snapshot is executed every 15 mins and so on. Leaving frequency blank will generate a series based on the awr snapshot frequency.
The script works with RDBMS 12.1 and later.  By default awr reports will be generated in text format. To generate pluggable database awr reports connect to database by specifying username , password and tns alias of the pluggable db. 

=begin text

     [Example of execution]

     [oracle@racnode1 ~]$ perl ./awrdmp.pl 
     Enter usrname: - 
     Enter password: - 
     Enter tnsalias: - 
     Enter frequency - 
     Enter mode
     (text/html) - text
     CONNECTED AS SYSDBA  
     RDBMS VERSION: 23.0.0.0.0

     ---- ---------- ------- ---------- ---------- -------------------- ------
     NUM       DBID  INSTID     DBNAME     INSTID              MACHINE CONTID
     ---- ---------- ------- ---------- ---------- -------------------- ------
     0 2531872897       2      MMGDB       pdm2             racnode2      0
     1 2531872897       1      MMGDB       pdm1             racnode1      0

     Enter database num: [0,1] -: 0
      0 2531872897       2      MMGDB       pdm2             racnode2
     RANGE AVAILABLE IN REPOSITORY FOR DBID 2531872897 INST 2:
     ------------------------------------------------------
     [191 04-NOV-21 07.58.34.180 AM : 420 15-NOV-21 06.28.18.307 AM] 
     Enter the minimum date interval (DD/MM/YYYY) -: 04/11/2021
     Enter the maximum date interval (DD/MM/YYYY) -: 05/11/2021
     GENERATING FILES
     [  0 %] writing file : report_2_MMGDB_191_192.text 



    
=end text

All reports generated during execution will be saved in dumpdir, if the directory does not exist it will be automatically created. 

=begin text 
    
    ls -ltr ./dumpdir
    [...]
    -rw-r--r-- 1 oracle oinstall 145147 Nov 12 14:16 report_1_MMGDB_196_197.text
    -rw-r--r-- 1 oracle oinstall 159775 Nov 12 14:16 report_1_MMGDB_197_198.text
    -rw-r--r-- 1 oracle oinstall 157100 Nov 12 14:16 report_1_MMGDB_198_199.text
    -rw-r--r-- 1 oracle oinstall 148216 Nov 12 14:16 report_1_MMGDB_199_200.text
    -rw-r--r-- 1 oracle oinstall 144003 Nov 12 14:16 report_1_MMGDB_200_201.text
    -rw-r--r-- 1 oracle oinstall 146216 Nov 12 14:16 report_1_MMGDB_201_202.text
    [...]


=end text


   
   

=head1 OPTIONS

=over 8

=item B<--rac>

generates the global awr report 

=item B<--batch>

Let the user specify input parameters on the command line to execute the script in background. This option is available only with a local connection(oracle sid). All the following options need --batch

=item B<--freq> 

As described in the previous section use this option to produce one hour reports when awr snapshot frequency has a non default value (60 min )

=item B<--instid> 

Specify the instance number 

=item B<--instid> 

Specify the instance number 

=item B<--dbn> 

Specify the database name 

=item B<--begin>

Starting date of the time frame

=item B<--end>

Ending date of the time frame

=item B<--mode> 

Two options available: text of html. Text is the deafult one. 

=item B<--html2text>

Convert report files to text. Use this function only if you need to use grep/awk and other parse tool with exadata statistics which are present in html version only.
It converts the html report to text file as they are generated. This feature requires lynx package to be installed on the server. If you need this feature and you cannot install lynx on the server you can move html reports on other server and convert them using --html2txt and --offlinedir. (see --offlinedir)

=item B<--rmhtml> 

If html2text is used then rm the original html after conversion. The default setting does not remove the htmls reports.

=item B<--offlinedir> 

Use this option to convert html files offline, tipycally when you cannot install lynx on the server. You can generate html reports one the db server and convert them on another one by using this option.

=item B<--list>

List all the database available in the AWR repository

=back

=begin text

     [Example of execution]
     perl awrdmp.pl --batch --freq 1 --instid 1 --dbid 2531872897 --dbn MMGDB --begin 04/11/2021 --end 15/11/2021 --rac --mode html

=end text
      

     

=head1 REFERENCES

=over 8


=item B<Note 557525.1> 

how to get all the AWR reports in a given snapshot id range 	

=item B<Note 977037.1> 

How to Generate all AWR Reports in a Given Snapshot Range 	 

=item B<Note 1378510.1>  

Script to Generate AWR Reports for All snap_ids Between 2 Given Dates 


=back


=cut
