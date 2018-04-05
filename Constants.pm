# package name (same as filename sans .pm)
package Constants;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = 0.01;

require Exporter;
@ISA = qw( Exporter );

# list of subroutines that we'll want to allow access to
my @stuff = qw( TRUE True FALSE False pcolor setColorHTMLOutput );

@EXPORT = ( @stuff );

%EXPORT_TAGS = ( 'vars' => [@stuff], );

# just for 'fancy' printing.
eval 'use Term::ANSIColor;';
our $COLOR = (!$@) ? 1 : 0;
if ($COLOR) {
  use Term::ANSIColor;
  $Term::ANSIColor::AUTORESET = 1;
}

# attempt to use pcolor routine to also emit an html strings so 
# simple color output test when rendered in html will be 'colorized'
sub setColorHTMLOutput { $COLOR = "UseHTMLString"; }

# easy to use and id True or False subroutines (each having two variations:
# all caps or only first list)
sub TRUE  { 1 }
sub True  { 1 }
sub FALSE { 0 }
sub False { 0 }

# just a short cut for print color "some color' if ($COLOR);
sub pcolor {

# attempt html color strings...
  if ($COLOR =~ /UseHTMLString/) {
    if (not scalar(@_)) { print '</span>'."\n"; return; }

    my $color  = shift || '</span>';
    my $size   = shift || "10px";
    my $weight = shift || ";";
       $weight = ($weight eq "bold") ? "font-weight:$weight;" : "";

    if ($color eq "\n") { print '<br>',"\n"; }
    elsif ($color =~ /span/) { print $color; }
    else {
      print '<span style="font-family: Arial, Helvetica, sans-serif; '.
            'font-size: ',$size,';',$weight,'color:',$color,'">',"\n";
    }
  }
# if Term::ANSIColor is available
  elsif ($COLOR) {

# if no args then silently do a color reset
    if (not scalar(@_)) { print color 'reset'; return; }

# switch to something colorful
    print color "@_";
  }

# go back
  return;
}

return 1;
