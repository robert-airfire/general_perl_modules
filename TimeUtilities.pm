# package name (same as filename sans .pm)
package TimeUtilities;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = 0.01;

require Exporter;
@ISA = qw( Exporter );

# list of subroutines that we'll want to allow access to
# NOTE although similar in action the two routines dt_from_datestr
# and get_dt_from_datestr are called in drastically different
# manners so  pick the one you like best and/or what ever whim
# stricks you at the moment
my @stuff = qw( dt_gmt
                dt_local
                assign_name
                delta_hours
                delta_seconds
                delta_minutes
                check_ymd
                check_ymdh
                check_ymdh_str 
                dt_from_datestr
                get_dt_from_datestr
                get_ymdh_from_datestr
                timestr_to_gmt
                dt_to_str
                dt_to_ymdh );

@EXPORT = ( @stuff );
%EXPORT_TAGS = ( 'vars' => [@stuff], );

use lib "/usr/local/share/perl";

use DateTime;
use DateTime::Duration;
use DateTime::TimeZone;
use DateTime::TimeZone::Local;
use DateTime::Format::Strptime;

use Constants;

sub dt_gmt   { return(DateTime->now->set_time_zone("GMT")); }
sub dt_local { my $tz = DateTime::TimeZone::Local->TimeZone();
               return(DateTime->now->set_time_zone($tz)); }

# ============================================================================ #
#      given YYYYMMDDHH return the year, month, day and hour in an array       #
#    we will also deal with the possibility of only YYYYMMDD being sent by     #
#      checking the initial length of YYYYMMDDHH and setting HH to undef       #
#         for the return value and use 00 for the validity check               #
# ============================================================================ #
sub get_ymdh_from_datestr
{
# get arg
  my $date_time = shift;
  
  my $l = length($date_time);
  my @T;
  my $i=0;
     $T[$i++] = ($l >=  4) ? substr($date_time, 0,4) : 0 ;
     $T[$i++] = ($l >=  6) ? substr($date_time, 4,2) : 0 ;
     $T[$i++] = ($l >=  8) ? substr($date_time, 6,2) : 0 ;
     $T[$i++] = ($l >= 10) ? substr($date_time, 8,2) : 0 ;
     $T[$i++] = ($l >= 12) ? substr($date_time,10,2) : 0 ;
     $T[$i++] = ($l >= 14) ? substr($date_time,12,2) : 0 ;

# do a quick check
  $status = check_ymdh(@T);
  my @badreturn;
  return(@badreturn) unless ($status);

# return array (we drop the part we didn't originally receive in the process
  splice(@T,($l-14)/2);
  return(@T);
}

sub check_ymdh_str
{
  my $date_str = shift;
  my @dump = get_ymdh_from_datestr($date_str);
  die("invalid date_str: $date_str\n") unless (defined($dump[0]));
  return;
}

# ============================================================================ #
# do a check on the yy, mm, dd & hh values obtained from the YYYYMMDDHH string #
#        note: doesn't check that year is greater than default value.          #
#     the check_ymdh is just a quicky routine if you don't care about hours    #
# ============================================================================ #
sub check_ymd
{
  my @T = @_;
  push @T, ( 0 );
  return( check_ymdh(@T) );
}

sub check_ymdh
{
# make sure we got four elements or we return 0 (FALSE)
  return(FALSE) if ((scalar(@_) < 4) || (scalar(@_) > 6));

# okay put'm into temp vars and test them out....
  my $i = 0;
  my @T = qw( 0 0 0 0 0 0 );

  $T[$i++] = $_ foreach ( @_ );
  if ((($T[1] < 1) || ($T[1] > 12)) || (($T[2] < 1) || ($T[2] > 31)) ||
      (($T[3] < 0) || ($T[3] > 24)) || (($T[4] < 0) || ($T[4] > 60)) ||
      (($T[5] < 0) || ($T[5] > 60))) { return(FALSE); }

  eval '$dt = DateTime->new(year => $T[0], month  => $T[1], day    => $T[2],
                            hour => $T[3], minute => $T[4], second => $T[5]);';

  if ($@) {
    print "Error: invalid date_time: @T\n";
    return(FALSE);
  }
  return(TRUE);
}

# ============================================================================ #
# given YYYYMMDD... return a DateTime representation of it. if a seocond       #
# arg is provided, it is assumed to be the timezone and handled appropriately  #
# ============================================================================ #
sub get_dt_from_datestr
{
# define a few things
  my %tlist;

# we might get a tz also...
  my $offset_add_to_minutes = 0;
  my $tz = (scalar(@_) == 2) ? pop : undef ;

# if tz is not 0 (numerical zero) then it must be an offset
  if (defined($tz) && ($tz != 0)) {
    $offset_add_to_minutes = -60.0 * $tz;
    $tz = 'GMT';
  }

# get YYYYMMDDHH
  my $date_str = shift;

# what we can set */
  my @tvars = qw( year month day hour minute sec );

# extract year mont day and hour from the string
  my @T = get_ymdh_from_datestr($date_str);
  foreach (@T) {
    $temp = shift @tvars;
    $tlist{$temp} = $_;
  }

# create the DateTime object
  my $dt = DateTime->new( %tlist );

# if time zone provided, apply it.
  $dt->add(minutes => $offset_add_to_minutes );
  $dt->set_time_zone($tz) if (defined($tz));

# return value
  return $dt;
}

# a variation of the above routine...the arguments are given as the
# elements in a hash. currently recognized keys are:
#   timezone
#   datetime
#   format

sub dt_from_datestr
{
  my $arg_ref   = { @_ };
  my $timezone  = $$arg_ref{timezone} ||= "GMT";
  my $dt_string = $$arg_ref{datetime};
     $dt_string =~ s/://g;
  my $format    = $$arg_ref{format}   ||= "%Y%m%d%H%M%z";

  my $strp_parser  = new DateTime::Format::Strptime(pattern => $format );
  my $dt           = $strp_parser->parse_datetime( $dt_string );
     $dt->set_time_zone( $timezone );

  return($dt);
}


# given a date and time in local time zone, convert to GMT
sub timestr_to_gmt
{
  my $num_args = scalar @_;
  my $error = FALSE;
  my $datetime;
  my $tz; 

# two args: YYYYMMDDHHMM and TZ_name
  if ($num_args == 2) {
    $datetime = shift;
    $error    = TRUE if (length($date) != 12);
    $tz       = shift;
  }
# three args: YYYYMMDD HHMM and TZ_name
  elsif ($num_args == 3) {
    my $date  = shift;
    my $time  = shift;
    $error    = TRUE if (length($date) != 8);
    $datetime = sprintf("%08d%04d",$date,$time);
    $tz       = shift;
  }
# six args: YY MM DD HH MM and TZ_name
  elsif ($num_args == 6) {
    my $year     = shift;
    my $month    = shift;
    my $day      = shift;
    my $hour     = shift;
    my $minute   = shift;

    $datetime = sprintf("%04d%02d%02d%02d%02d",$year,$month,$day,
                                               $hour,$minute);
    $tz       = shift;
  }
  else {
    $error = TRUE;
  }

  if ($error) {
    warn("TIME ERROR: can't convert local to gmt\n");
    my $a = -1;
    return(($a,$a));
  }

# if unknown timezone assume its UTC already (prob wrong but what can you do?)
  $tz =~ s/Unknown/UTC/;
  my $dt = get_dt_from_datestr($datetime,$tz);
     $dt->set_time_zone('UTC');
  my $gmtdate = sprintf("%04d%02d%02d",$dt->year,$dt->month,$dt->day);
  my $gmttime = sprintf("%02d%02d",$dt->hour,$dt->minute);
  my @value = ( $gmtdate , $gmttime );
  return @value;
}

# does the basic file name substitution (of the YYYYMMDD stuff etc)
# input: YYYYMMDDHH
#        string(s)
# output: string(s) with various time stamp things replaced with the
#         actual numbers
#
# input can be an array of strings or a scalar. which is determined
# by the variable on the left hand of the call to the subroutine
sub assign_name
{
# get the  date_time string
  my $YYYYMMDDHH = shift;

# does it look valid?
  if ((length($YYYYMMDDHH) != 10) || ($YYYYMMDDHH < 1000000000)) {
    print "assign_name: date-time string does not appear valid\n";
    print "              YYYYMMDDHH => $YYYYMMDDHH\n";
  }

# other date strings used here and there
  my $YYYYMMDD = substr($YYYYMMDDHH,0,8);  # w/o hour bit
  my $MMDDYY   = substr($YYYYMMDD,4,2).    # month day 2-digit year format
                 substr($YYYYMMDD,6,2).
                 substr($YYYYMMDD,2,2);
  my @files = @_;
# make the substitutions (NOTE: careful about the order that they're
# done in. eg, YYYYMMDDHH must come before YYYYMMDD or else you'll be
# left with an HH string that won't get changed to the correct value.)
  for (@files) {
    s/FORECAST_DATEHR_STR|YYYYMMDDHH/$YYYYMMDDHH/g;
    s/FORECAST_DATE_STR|YYYYMMDD/$YYYYMMDD/g;
    s/MMDDYY/$MMDDYY/g;
  }

# returning an array of values or just a scalar?
  return wantarray ? @files : $files[0];
};

# returns the number of hours between the two datetime objects
# NOTE: only valid for difference less than a month
sub delta_hours
{
  my $dt1 = shift;
  my $dt2 = shift;

  my $seconds = delta_seconds($dt1,$dt2);
  my $hours   = $seconds/3600.0;
  return($hours);
};

sub delta_minutes
{
  my $dt1 = shift;
  my $dt2 = shift;

  my $seconds = delta_seconds($dt1,$dt2);
  my $minutes = $seconds/60.0;
  return($minutes);
}

sub delta_seconds
{
  my $dt1 = shift;
  my $dt2 = shift;

  my $diff    = $dt1->subtract_datetime($dt2);
  my $seconds = $$diff{seconds} + 60.0*($$diff{minutes} +
                                  60.0*($$diff{hours} +
                                  24.0*$$diff{days}));
  return($seconds);
}

sub dt_to_ymdh
{
  my $dt     = shift;
  my $format = "%Y%m%d%H";

  $str = dt_to_str($dt,$format);
  return($str);
}

sub dt_to_str
{
  my $dt     = shift;
  my $format = shift;

  my $formatter = DateTime::Format::Strptime->new(pattern => $format);
  my $str       = $formatter->format_datetime($dt);

  return($str);
}


return 1;
