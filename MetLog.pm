# package name (same as filename sans .pm)
package MetLog;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = 0.01;

require Exporter;
@ISA = qw( Exporter );

# short routine to call the logging python script
my @stuff = qw( MetLogger );

@EXPORT = ( @stuff );
%EXPORT_TAGS = ( 'vars' => [@stuff], );

sub MetLogger
{
my $procname  = shift;
my $MET       = shift;
my $ymdh      = shift;
my $action    = shift;
my $logstatus = shift;
my $message   = shift;

# logger info
my $API_ENDPOINT = 'http://status-log-production.herokuapp.com/status-logs';
my $API_KEY      = "700824e31cfe11e4a89f3c15c2c6639e";
my $API_SECRET   = "73fa27801cfe11e481873c15c2c6639e";

# log cmd
my $logcmd  = "/usr/local/bin/log-status.py ".
              "-e \"$API_ENDPOINT\" -k $API_KEY -s $API_SECRET ".
              "-p $procname -o $logstatus ".
              "-f domain=\"CANSAC_$MET\" ".
              "-f initialization_time=$ymdh ".
              "-f step=\"$step\" ".
              "-f action=\"$action\" ".
              "-f comments=\"$message\"";
system($logcmd);
}
