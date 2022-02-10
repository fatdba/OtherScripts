#!/usr/bin/perl
#
# $Id: lhm.pl,v 1.2 2014/10/29 10:54:02 oracle Exp $
#
# lhm.pl
#
#    NAME
#      lhm.sql - Latency Heat Map
#
#    DESCRIPTION
#      Perl script to plot the heat map of latency waits event in range
#      of snapshot id using gnuplot for a given wait event.
#
#    NOTES
#      The script is   divided in three parts, (1) it creates the matrix of
#      latency time for a given waitevent from the dba_hist_event_histogram
#      L(s,j) where s is  the snap id and j  is  the bucket   time interval
#      (wait_time_milli), (2)  Calcultes  for each J the differential value
#      between    snapid and snapid+1 D(s,j)=L(s,j)-L(s-1,j) for each J,(3)
#      Plot the heat map,  Heatmap(D(s,j)) for each s and j
#
#   UTILIZATION:
#      perl ./lhm.pl --begin [first snapid] --endid [last snapid] \
#                    --dbid=[database id] --instance=[instance num]  \
#
#    AUTHOR
#      matteo.malvezzi@oracle.com
#
#    LOG
#      $Log: lhm.pl,v $
#      Revision 1.2  2014/10/29 10:54:02  oracle
#      *** empty log message ***
#
#      Revision 1.1  2014/09/30 20:53:33  oracle
#      Initial revision
#
#

use strict;
use Getopt::Long;
use POSIX;
use Tie::File;
use Term::ANSIColor;

my $bgid = 0;    # Begin snasphot id
my $enid = 0;    # End snapshot id
my $isid = 1;    # Instance number default 1
my $dbid = 0;    # Database identifier
my $evnt;        # Wait event
my $ltcmtx = "./lmtx.txt";      # L(s,j)
my $delmtx = "./dmtx.txt";      # D(s,j)=L(s,j)-L(s-1,j)
my $trsmtx = "./tmtx.txt";      # Tr(D(s,j))=D(j,s)
my $gpfile = "./heatmap.gp";    # heatmap gnuplot file
my $line;
my $il;                         # number of columns
my $jl;                         # number of lines
my $cc;                         # counter for columns
my $cl;                         # counter for lines
my @vector;
my @matrix;
my $xticf;                      # xtic frequency
my $xticp = 12;                 # xtic number of point
my $font        = "/usr/share/fonts/liberation/LiberationMono-Regular.ttf";
my $oracle_home = $ENV{ORACLE_HOME};
my $oracle_sid  = $ENV{ORACLE_SID};
my $help;

sub usage {
    print "Unknown option: @_\n" if (@_);
    print "\n\n";
    print "usage: perl ./lhm.pl --begin [first snapid] --end [last snapid] \n";
    print "       --dbid [database id] --instance [instance num]        \n";
    print "       --wait_event \"wait event\"        \n";
    print "\n\n\n";
    exit;
}

GetOptions(
    "begin=i"    => \$bgid,
    "end=i"      => \$enid,
    "dbid=i"     => \$dbid,
    "event=s"    => \$evnt,
    "instance=i" => \$isid
);

if ( not defined $oracle_home || not defined $oracle_sid ) {
    print("ORACLE_SID or ORACLE_HOME are not set\n");
    exit;
}

if ( ( !-e "/usr/local/bin/gnuplot" ) || ( !-e "/usr/bin/gnuplot" ) ) {
    print color 'bold red';
    print colored( "Gnuplot is not installed\n", "blink" );
    print color 'bold red';
    print colored(
        "Download gnuplot package from http://public-yum.oracle.com/\n",
        "blink" );
    exit;
}

qx($oracle_home/bin/sqlplus -s '/as sysdba' <<EOF

variable b1 number;
variable b2 number;
variable ev varchar2(64);
variable b3 number;
variable b4 number;

begin 
   :b1 := $bgid ;
   :b2 := $enid ;
   :ev := '$evnt';
   :b3 := $dbid;
   :b4 := $isid;
end;
/

spool $ltcmtx
set head off
set feed off 
set line 1000 
set trimspool on 
set pages 0
select
    snap_id,
    sum (case when WAIT_TIME_MILLI=1         then WAIT_COUNT else 0 end) b1,
    sum (case when WAIT_TIME_MILLI=2         then WAIT_COUNT else 0 end) b2,
    sum (case when WAIT_TIME_MILLI=4         then WAIT_COUNT else 0 end) b3,
    sum (case when WAIT_TIME_MILLI=8         then WAIT_COUNT else 0 end) b4,
    sum (case when WAIT_TIME_MILLI=16        then WAIT_COUNT else 0 end) b5,
    sum (case when WAIT_TIME_MILLI=32        then WAIT_COUNT else 0 end) b6,
    sum (case when WAIT_TIME_MILLI=64        then WAIT_COUNT else 0 end) b7,
    sum (case when WAIT_TIME_MILLI=128       then WAIT_COUNT else 0 end) b8,
    sum (case when WAIT_TIME_MILLI=256       then WAIT_COUNT else 0 end) b9,
    sum (case when WAIT_TIME_MILLI=512       then WAIT_COUNT else 0 end) b10,
    sum (case when WAIT_TIME_MILLI=1024      then WAIT_COUNT else 0 end) b11,
    sum (case when WAIT_TIME_MILLI=2048      then WAIT_COUNT else 0 end) b12,
    sum (case when WAIT_TIME_MILLI=4096      then WAIT_COUNT else 0 end) b13,
    sum (case when WAIT_TIME_MILLI=8192      then WAIT_COUNT else 0 end) b14,
    sum (case when WAIT_TIME_MILLI=16384     then WAIT_COUNT else 0 end) b15,
    sum (case when WAIT_TIME_MILLI=32768     then WAIT_COUNT else 0 end) b16,
    sum (case when WAIT_TIME_MILLI=65536     then WAIT_COUNT else 0 end) b17,
    sum (case when WAIT_TIME_MILLI=131072    then WAIT_COUNT else 0 end) b18,
    sum (case when WAIT_TIME_MILLI=262144    then WAIT_COUNT else 0 end) b19,
    sum (case when WAIT_TIME_MILLI=524288    then WAIT_COUNT else 0 end) b20,
    sum (case when WAIT_TIME_MILLI=1048576   then WAIT_COUNT else 0 end) b21,
    sum (case when WAIT_TIME_MILLI=2097152   then WAIT_COUNT else 0 end) b22,
    sum (case when WAIT_TIME_MILLI=4194304   then WAIT_COUNT else 0 end) b23,
    sum (case when WAIT_TIME_MILLI > 4194304 then WAIT_COUNT else 0 end) b24
from DBA_HIST_EVENT_HISTOGRAM
where event_name=:ev and dbid=:b3
and snap_id between :b1 and :b2 
and instance_number = :b4
group by snap_id
order by snap_id desc
/
EOF);

open( MATRIX, $ltcmtx ) or die("Could not open  file.");

foreach $line (<MATRIX>) {

    #split lines in token
    @vector = split( /\s+/, $line );

    #get the number of column in the matrix
    $il = scalar(@vector);
    push( @matrix, [@vector] );

}

#get the number of rows in the matrix
$jl = scalar(@matrix);

if ( $jl == 0 || $il == 0 ) {
    print "Invalid arguemnts\n";
    usage();
    exit;
}

printf( "database id:     %i\n",       $dbid );
printf( "wait event:      %s\n",       $evnt );
printf( "Matrix:          [%ix%i] \n", $il, $jl );
printf( "snap range:      [%i:%i] \n", $bgid, $enid );
printf( "instance id:     %i\n",       $isid );

open FMTXD, ">$delmtx";

LINE_LOOP: for ( $cl = 1 ; $cl < $jl ; $cl++ ) {
  COLUMN_LOOP: for ( $cc = 2 ; $cc <= $il ; $cc++ ) {
        my $delta = $matrix[ $cl - 1 ][$cc] - $matrix[$cl][$cc];
        if ( $delta < 0 )    #skip negative delta (shutdown in the snapid range)
        {
            $delta = 0;
        }
        print FMTXD " $delta";
    }
    print FMTXD "\n";
}
close FMTXD;

# ~~ TRANSPOSE ~~

open FMTXT, ">$trsmtx";

COL_LOOP: for ( $cc = 2 ; $cc <= $il ; $cc++ ) {
  LIN_LOOP: for ( $cl = 1 ; $cl < $jl ; $cl++ ) {
        my $delta = $matrix[ $cl - 1 ][$cc] - $matrix[$cl][$cc];
        if ( $delta < 0 ) { $delta = 0; }
        printf FMTXT " $delta";
    }
    print FMTXT "\n";
}
close FMTXT;

open GPFILE, ">$gpfile";

if ( -e $font ) {
    print GPFILE "#marker set term png font '$font' 10 size 800,600 \n";
}
else {
    print GPFILE "#marker set term png size 800,600\n";
}

print GPFILE "set palette maxcolors 20 \n";
print GPFILE "set palette defined ( 0 '#ffffff', 1 '#000fff', 2 '#ee0000') \n";
print GPFILE "set cblabel \"# of waits\" \n";
print GPFILE "set border linewidth .1\n";
print GPFILE "set logscale cb \n";
print GPFILE "set label 3 at 0, 26.5 \n";
print GPFILE "set label 3 '[$evnt]\n";

print GPFILE "set label 2 at 0, 25 \n";
print GPFILE "set label 2 'range [$bgid:$enid]\\\n";
print GPFILE " dbid:$dbid inst_id:$isid ' \n";

print GPFILE "set ylabel \"latency times\" offset -4 \n";
print GPFILE "set xlabel \"snap id\" offset 0 \n";

$xticf = 1 + ( $enid - $bgid ) / $xticp;

printf GPFILE "set xtic (";
my $ind;
for ( $cl = $jl - 1 ; $cl >= 1 ; $cl-- ) {

    if ( ( $matrix[$cl][1] % $xticf ) == 0 ) {
        $ind = ( $jl - $cl );
        print GPFILE " \"$matrix[$cl][1]\" $ind ";
        if ( ( $cl - $xticf ) > 1 ) { print GPFILE ","; }
    }

}
print GPFILE ")\n";

print GPFILE "set grid\n";
print GPFILE " set ytics (\"1 ms\" 1,\"2 ms\"2,\"4 ms\"3,\"8 ms\" 4,\\\n";
print GPFILE " \"16 ms\"5,\"32 ms\"6,\"64 ms\"7,\"1/8 s\"8,\"1/4 s\"9,\\\n";
print GPFILE " \"1/2 s\"10,\"1 s\"11,\"2 s\"12,\"4 s\"13,\"8 s\" 14, \\\n";
print GPFILE " \"16 s\"15 ,\"32 s\"16,\"1 m\"17,\"2 m\"18 ,\"4 m\"19,\\\n";
print GPFILE " \"8 m\"20,\"1/4 h\"21,\"1/2 h\"22,\"1h\"23,\"> 1h\"24); \n";

$evnt =~ s/ /_/g;
print GPFILE "#marker set output './latency_$evnt.jpg'\n";
print GPFILE "set view map\n";
print GPFILE "splot './tmtx.txt' matrix with image notitle\n";

qx(gnuplot -persist $gpfile & );

my @arr;
tie @arr, 'Tie::File', $gpfile;
foreach (@arr) {
    s/#marker / /g;
}

qx(gnuplot $gpfile);
printf( "jpg file   :     latency_%s.jpg\n", $evnt );
