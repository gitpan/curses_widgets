#!/usr/bin/perl -w
#
# Simple script that demonstrates the uses of Curses::Widgets
#
# $Id: test.pl,v 0.1 1999/06/17 23:06:15 corliss Exp $
#

use strict;
use Curses;
use Curses::Widgets;

#####################################################################
#
# Set up the environment
#
#####################################################################

my ($mwh, $dwh);
my ($colours);
my ($text, $content);
my (@date_disp);
my (@buttons, $sel, %list);

#####################################################################
#
# Program Logic starts here
#
#####################################################################

# Unless specifically noted, most functions are provided by the Curses
# package, *not* Curses::Widgets.  See the pod for Curses for more
# information on the functions.  Additional information is available
# with the (n)Curses man pages (section 3), if you have them.
$mwh = new Curses;
$colours = has_colors();
noecho();
cbreak();
halfdelay(10);
$mwh->keypad(1);

# This is just a function that maps some colour pairs:
init_colours();

main_win();

$dwh = $mwh->subwin(8, $COLS - 2, 1, 1);

$text = << '__EOF__';
To start the demonstration, we'll show you the calendar widget,
which requires the Unix 'cal' command for speedy access to any
month.  Press any key to begin. . .
__EOF__

dialog($text, 'green');
grab_key();

$text = << '__EOF__';
Use the cursor keys to navigate from day to day.  The Page Up &
Page Down keys will move you from month to month, and Home will
always bring you back to the current date.

Any other key will cause the calendar to 'lose focus'.
__EOF__

dialog($text, 'red');

# Note that we haven't initialised @date_disp, but it will be set to
# the current date by the calendar function, if not set already.
# Since we're calling in the default 'interactive' mode, it will return a
# key value.
$text = calendar( 'window'		=> \$mwh,
				  'date_disp'	=> \@date_disp,
				  'border'		=> 'green',
				  'xpos'		=> 10,
				  'ypos'		=> 9);

$text = << "__EOF__";
The last key you pushed was $text.  Remember, any key not used
for navigation is returned by the calendar function.

Please press a key to continue.
__EOF__

dialog($text, 'green');

# This redraws the calender in non-interactive mode.
calendar( 'window'		=> \$mwh,
		  'date_disp'	=> \@date_disp,
		  'border'		=> 'red',
		  'xpos'		=> 10,
		  'ypos'		=> 9,
		  'draw_only'	=> 1);

grab_key();

main_win();

$text = << "__EOF__";
Next, is the text field function.  When calling this function,
one can specify both character and/or line limits to the content
allowed to be typed into it.  Note that titles can be applied in
the border as well.  This should save some screen real estate.

Press TAB to make the text field 'lose focus'.
__EOF__

dialog($text, 'red');

# This calls the Text field in interactive, edit mode.
($text, $content) = txt_field(   'window'		=> \$mwh,
							   'title'		=> 'Test field',
							   'xpos'		=> 1,
							   'ypos'		=> 9,
							   'lines'		=> 5,
							   'cols'		=> $COLS - 4,
							   'content'	=> 'Type something in here. . .',
							   'border'		=> 'green');

# And, in non-interactive mode.
txt_field(   'window'		=> \$mwh,
			'title'		=> 'Test field',
			'xpos'		=> 1,
			'ypos'		=> 9,
			'lines'		=> 5,
			'cols'		=> $COLS - 4,
			'content'	=> $content,
			'border'		=> 'red',
			'draw_only'	=> 1);

$text = << "__EOF__";
You can assign any key or keys to the text widget that will cause
the widget to 'lose focus'.  Full navigation via the PgUp, PgDn,
Home, and End keys are supported, in addition to the cursor keys.

Press any key to continue.
__EOF__

dialog($text, 'green');
grab_key();

main_win();

$text = << '__EOF__';
The next widget available for your use is the button bar.  These
bars can be laid out either vertically or horizontally.  A SPACE
or RETURN is used to select the appropriate button, while cursor
keys are used for Navigation.
__EOF__

dialog($text, 'red');

@buttons = ('< Test 1 >', '< Test 2 >', '< Test 3 >');
$sel = 1;

# Calls a horizontal button bar
($text, $sel) = buttons( 'window'			=> \$mwh,
						 'buttons'			=> \@buttons,
						 'active_button'	=> $sel,
						 'ypos'				=> 10,
						 'xpos'				=> 10);

$text = << '__EOF__';
Called as a function, the button bar will return two values:

	1) The key pressed
	2) The button selected
__EOF__

main_win();
dialog($text, 'red');

# Calls a vertical button bar
($text, $sel) = buttons( 'window'			=> \$mwh,
						 'buttons'			=> \@buttons,
						 'active_button'	=> $sel,
						 'ypos'				=> 10,
						 'xpos'				=> 10,
						 'vertical'			=> 1);

$text = << '__EOF__';
Lastly, we have the list box.  The Up & Down arrow
keys are used for navigation, while any other key
will be returned, along with a selected item number,
if there is one.
__EOF__

dialog($text, 'red');

%list = ( '1'	=> 'Item 1',
		  '2'	=> 'Another Item',
		  '3'	=> 'Item 3',
		  '4'	=> 'One more',
		  '5'	=> 'Item 5',
		  '6'	=> 'Item 6',
		  '7'	=> 'Item 7',
		  '8'	=> 'Last Choice');

# List box in interactive mode.
($text, $sel) = list_box( 'window'		=> \$mwh,
						  'title'		=> 'Choose one',
						  'ypos'		=> 9,
						  'xpos'		=> 10,
						  'lines'		=> 5,
						  'cols'		=> 25,
						  'list'		=> \%list,
						  'border'		=> 'green',
						  'selected'	=> 1);

# Non-interactive mode.
list_box( 'window'		=> \$mwh,
		  'title'		=> 'Choose one',
		  'ypos'		=> 9,
		  'xpos'		=> 10,
		  'lines'		=> 5,
		  'cols'		=> 25,
		  'list'		=> \%list,
		  'border'		=> 'red',
		  'selected'	=> $sel,
		  'draw_only'	=> 1);

$text = << "__EOF__";
The last key you pressed was $text, and the item
selected was $list{$sel}.

Press any key to continue.
__EOF__

dialog($text, 'green');
grab_key();

$text = << '__EOF__';
That pretty much concludes this demonstration.  There will be
more features coming down the pike eventually, but hopefully
this is more than adequate for most purposes.

Any comments, grips, suggestions and critiques are welcome.
__EOF__

dialog($text, 'green');
grab_key();

$mwh->refresh();

endwin();
exit 0;

#####################################################################
#
# Subroutines follow here
#
#####################################################################

sub main_win {

	$mwh->erase();

	# This function selects a few common colours for the foreground colour
	select_colour(\$mwh, 'red');
	$mwh->box(ACS_VLINE, ACS_HLINE);
	$mwh->attrset(0);

	$mwh->standout();
	$mwh->addstr(0, 1, "Welcome to the Curses::Widgets Demo!");
	$mwh->standend();
}

sub grab_key {
	my ($key) = -1;

	while ($key eq -1) {
		$key = $mwh->getch();
	}

	return $key;
}

sub dialog {
	my ($text, $colour) = @_;
	my (@lines) = split(/\n/, $text);
	my ($i, $j, $line);

	for ($i = 1; $i < 7; $i++) {
		if (defined ($lines[$i - 1])) {
			$line = $lines[$i -1] . "\n";
		} else {
			$line = "\n";
		}
		$dwh->addstr($i, 2, $line);
	}

	select_colour(\$dwh, $colour);
	$dwh->box(ACS_VLINE, ACS_HLINE);
	$dwh->attrset(0);

	touchwin($mwh);
	$mwh->refresh();
}
