# package name (same as filename sans .pm)
package Utilities;

use lib '/usr/local/share/perl';

use POSIX ":sys_wait_h";
use POSIX qw( WNOHANG );
use DateTime;
use DateTime::Duration;
use DateTime::TimeZone;
use DateTime::TimeZone::Local;
use DateTime::Format::Strptime;

use TimeUtilities;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = 0.01;

require Exporter;
@ISA = qw( Exporter );

# list of subroutines that we'll want to allow access to
my @stuff = qw(
                regexMatchList getMatchingFiles runMulti
              );

@EXPORT = ( @stuff );
%EXPORT_TAGS = ( 'vars' => [@stuff], );

use lib "/usr/local/share/perl";


# takes a template regex with groupings of matches, a string to match
# against, an array to hold the contents (by ref) and an optional array
# that gives the order of the matches in the returned list.
# fore example template '\c\c\c' string "abc" this gives matchs for a b c
# which are placed in the array. if the orderlist was 3 1 2 then
# the array would contain the 3rd 1st and 2nd in that order (ie  c a b)
# if the order array has fewer elements than groups then only that many
# are placed in the array the others are dropped (ie order array comained
# 3 2, then the returned array would have elements c b. Note that the
# number of matches returned would still be the actual number, not the
# number placed into the array (ie, 3 in our exanmple).
sub regexMatchList
{
  my $template  = shift;
  my $string    = shift;
  my $matchlist = shift;

# return zero no matches
  return(0) unless ( $string =~ /$template/ );

# put the contents into or ref array reordering if necessary....
  my @orderlist = ( scalar(@_) ) ? @_ :  ( 1 .. $#- ) ;
  push @$matchlist, ( ${$_} ) foreach ( @orderlist );

# return the number of matches.
  return($#-);
}

# geven a directory and regex template, return list of files matching that
# template
sub getMatchingFiles
{
  my $directory = shift;
  my $template  = shift;

# opendir get files matching template 
  opendir(INFILES,$directory) or return(-1);
  my @infiles = sort grep { $_ = /$template/ } readdir(INFILES);
  closedir(INFILES);
  return(\@infiles);
}

sub runMulti
{
  my $commands   = shift;
  my $concurrent = shift;

  my $cmd;
  my %Children;
  my $children = 0;

  while ( scalar(@$commands ) || ($children)) {
    my $num_to_run = scalar(@$commands);
    my $in_prog = runs_in_progress(\%Children);
    my $cmd = ($num_to_run && available(\%Children,$concurrent)) ?
              shift @$commands : undef;
    if (defined($cmd)) { 
      my $pid = fork;
      if ($pid == 0) {
        system($cmd);
        exit;
      }
      $children++;
      $Children{$pid}{"cmd"}   = $cmd;
      $Children{$pid}{"stime"} = DateTime->now;
      print "parent: child{$pid} launched $Children{$pid}{cmd}\n";
    }
    $num_to_run = scalar(@$commands);
    $children += reap(\%Children,$concurrent,$num_to_run);
  }
}

# how many kids do we have working on runs
sub runs_in_progress
{
  $_ = shift;
  my @in_progress = keys %$_;
  return(scalar(@in_progress));
}

# any kids that we can pop out to work on a run for us?
sub available
{
     $_          = shift;
  my $concurrent = shift;

  my $working_children = scalar(keys %$_);
  my $num_available    = $concurrent - $working_children;
  return($num_available);
}

sub reap
{
  my $refChildren = shift;
  my $concurrent  = shift;
  my $num_to_run  = shift;

  my $value       = 0;
  my $in_prog     = runs_in_progress($refChildren);
  my $dead_kid;

  do {
    $dead_kid = waitpid(-1,WNOHANG);
    sleep 2 
    unless ((available($refChildren,$concurrent) && $num_to_run) || $dead_kid );
  } until  ((available($refChildren,$concurrent) && $num_to_run) || $dead_kid );

  if ( $dead_kid && exists($$refChildren{$dead_kid}) ) {
    my $etime = DateTime->now;
    my $stime = $$refChildren{$dead_kid}{"stime"};
    print "parent: child{$dead_kid} completed in ",
           delta_seconds($etime,$stime)," seconds\n";
    delete $$refChildren{$dead_kid};
    $value = -1;
  }
  elsif ( $dead_kid && (! exists($$refChildren{$dead_kid}))) {
    warn("confusing return from waitpid. dead child $dead_kid doesn't ".
         "exist...ignoring it.\n") 
  }
  return($value);
}
