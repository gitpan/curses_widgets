########################################################################
#
# Curses Widget Module
#
# $Id: Widgets.pm,v 1.1 2000/02/22 02:04:33 corliss Exp $
#
# (c) Arthur Corliss, 1998-2000
#
# Requires the Curses module for perl, and (n)Curses libraries.
#
########################################################################

package Curses::Widgets;

use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION);
use Exporter;
use Curses;

$VERSION = '1.1';

@ISA = qw(Exporter);

@EXPORT		= qw(txt_field buttons list_box calendar select_colour msg_box 
	input_box init_scr);
@EXPORT_OK	= qw(txt_field buttons list_box calendar select_colour 
	line_split grab_key msg_box input_box init_scr);
%EXPORT_TAGS = (
		'standard' => [ qw(txt_field buttons list_box calendar 
			select_colour msg_box input_box) ],
		'functions' => [ qw(select_colour line_split grab_key init_scr) ],
		'all' => [ qw(txt_field buttons list_box calendar msg_box input_box
			select_colour line_split grab_key init_scr) ],
		# 'Variables' => [ ],
);

my ($colour, %col_pairs);

########################################################################
#
# Module code follows. . .
#
########################################################################

sub txt_field {
	# Provides an bordered text field, with lines, columns, title,
	# initial cursor position, focus shift characters, and border 
	# colour user definable.
	#
	# Usage:  ($key, $content) = txt_field( [name => value], etc. );

	my %args = (
		'ypos' 			=> 1,
		'xpos' 			=> 1,
		'lines' 		=> 1,
		'pos'			=> 0,
		'border'		=> 'red',
		'decorations'	=> 1,
		'regex'			=> '\t',
		'draw_only'		=> 0,
		'hz_scroll'		=> 0,
		'edit'			=> 1,
		@_,
	);
	my $wh = $args{'window'};
	my (@line, $count, $i, $t_line, $curs_pos);
	my ($ch, $k, $x, $y, $c_line, $fwh, $bwh);
	my ($input, $ml, $disp);

	# Check to make sure the text field won't exceed the window boundaries
	$args{'window'}->getmaxyx($y, $x);
	if ($args{'decorations'}) {
		$i = 0;
	} else {
		$i = 2;
	}
	if ($args{'xpos'} < 0 || $args{'ypos'} < 0 || 
		($args{'cols'} + 2 - $i + $args{'xpos'}) > $x ||
		($args{'lines'} + 2 - $i + $args{'ypos'}) > $y) {
		warn << "__EOF__";
Text field widget's boundaries exceed the parent window's--not drawing:
	YPOS:  $args{'ypos'}	LINES:  $args{'lines'}	MAXY:  $y
	XPOS:  $args{'xpos'}	COLS:   $args{'cols'}	MAXX:  $x
__EOF__
		return;
	}

	# Only allow horizontal scrolling for single line widgets
	$args{'hz_scroll'} = 0 if ($args{'lines'} > 1);

	# Create the text window and the border window as specified
	if ($args{'decorations'}) {
		$bwh = $args{'window'}->derwin($args{'lines'} + 2,
			$args{'cols'} + 2, $args{'ypos'}, $args{'xpos'});
		$fwh = $bwh->derwin($args{'lines'}, $args{'cols'}, 1, 1);
	} else {
		$fwh = $args{'window'}->derwin($args{'lines'}, $args{'cols'}, 
			$args{'ypos'}, $args{'xpos'});
	}
	if (! $fwh) { 
		warn "Internal error creating window--exiting early.\n";
		return;
	}

	# Set some sane values
	$args{'content'} ||= '';
	if ($args{'pos'} < 0 || $args{'pos'} > length($args{'content'})) {
		$args{'pos'} = length($args{'content'});
		++$args{'pos'} if (length($args{'content'}) > 0);
	}
	$t_line = $ml = 0;

	local *draw = sub {
		$fwh->erase;
		$args{'pos'} = 0 if ($args{'pos'} < 0);
		$args{'pos'} = length($args{'content'}) if ($args{'pos'} >
			length($args{'content'}));

		# Assign for horizontal scrolling
		if ($args{'hz_scroll'}) {
			if (defined $input && $input eq "\n") {
				substr($args{'content'}, $args{'pos'} - 1, 1) = '';
				beep();
				--$args{'pos'};
			}
			@line = ( $args{'content'} );

		# Split the lines, and check the line limit, if defined
		} else {
			@line = line_split($args{'content'}, $args{'cols'});

			if (exists $args{'l_limit'} && scalar @line > $args{'l_limit'}) {
				substr($args{'content'}, $args{'pos'} - 1, 1) = '';
				beep();
				@line = line_split($args{'content'}, $args{'cols'});
				--$args{'pos'};
			}
		}

		# Determine the cursor row by character position
		$i = $count = 0;
		while ($count <= $args{'pos'} && $i < scalar @line) {
			$curs_pos = ($args{'pos'} - $ml) - $count;
			$count += length($line[$i]);
			++$i;
		}
		$c_line = $i - 1;
		$c_line = 0 if ($c_line < 0);
		if ((length($line[$c_line]) == $args{'cols'} && 
			substr($args{'content'}, $args{'pos'}, 1) eq "\n") ||
			($args{'pos'} == length($args{'content'}) &&
			substr($args{'content'}, $args{'pos'} - 1, 1) eq "\n")) {
			++$c_line;
			$curs_pos = 0;
		}

		# Determine the top row displayed in the window by cursor row
		if (($c_line - $t_line) >= $args{'lines'}) {
			if ($c_line == ($t_line + $args{'lines'})) {
				++$t_line;
			} else {
				while (($t_line + $args{'lines'}) < $c_line) {
					$t_line += $args{'lines'};
				}
			}
		} elsif ($c_line < $t_line) {
			if (($t_line - $c_line) == 1) {
				--$t_line;
			} else {
				while ($c_line < $t_line) {
					$t_line -= $args{'lines'};
				}
				$t_line = 0 if ($t_line < 0);
			}
		}

		# Turn on underlining if decorations are turned off
		$fwh->attron(A_UNDERLINE) unless ($args{'decorations'});

		# Write text to the window
		for ($i = 0; $i < $args{'lines'}; $i++) {
			if (defined $line[$t_line + $i] && 
				$line[$t_line + $i] !~ /^\n*$/) {
				$disp = $line[$t_line + $i];

				# Add space padding to the end of the line
				$disp =~ s/\n//g;
				$disp = $disp . ' ' x ($args{'cols'} + $ml - length($disp));

				# Special handling for password fields
				if ($args{'password'}) {
					$disp =~ s/\s+$//g;
					$fwh->addstr($i, 0, "*" x length(substr($disp, $ml)) . 
						" " x ($args{'cols'} - length($disp)));
				} else {
					$fwh->addstr($i, 0, substr($disp, $ml));
				}

			} else {
				$fwh->addstr($i, 0, " " x $args{'cols'});
			}
		}

		# Draw the cursor
		unless ($args{'draw_only'} || ! $args{'edit'}) {
			if (($args{'pos'} + 1) > length($args{'content'}) ||
				substr($args{'content'}, $args{'pos'}, 1) eq
				"\n") {
				$ch = ' ';
			} else {
				$ch = substr($args{'content'}, $args{'pos'}, 1);
			}
			$fwh->standout();
			$fwh->addch(($c_line - $t_line), $curs_pos, $ch);
			$fwh->standend();
		}

		# Draw the border and title if decorations are enabled
		if ($args{'decorations'}) {
			if (! $args{'draw_only'}) {
				select_colour($bwh, $args{'border'}) || 
					$bwh->attron(A_BOLD);
			} else {
				select_colour($bwh, $args{'border'});
			}
			$bwh->box(ACS_VLINE, ACS_HLINE);
			$bwh->attrset(0);
			if (exists $args{'title'}) {
				$args{'title'} = substr($args{'title'}, 0, $args{'cols'})
					if (length($args{'title'}) > $args{'cols'});
				$bwh->standout();
				$bwh->addstr(0, 1, $args{'title'});
				$bwh->standend();
			}

			# Draw the up arrow, if necessary
			$bwh->addch(0, $args{'cols'} - 1, ACS_UARROW) if 
				($t_line > 0);

			# Draw the down arrow, if necessary
			$bwh->addch($args{'lines'} + 1, $args{'cols'} - 1, ACS_DARROW)
				if (($t_line + $args{'lines'}) < scalar @line);
		}

		# Flush to the screen
		if ($args{'decorations'}) {
			$bwh->touchwin;
			$bwh->refresh;
		} else {
			$fwh->refresh;
		}
	};

	draw();
	if (! $args{'draw_only'}) {
		$fwh->keypad(1);
		while (1) {
			$input = grab_key($fwh, $args{'function'});
			if ($input =~ /^[$args{'regex'}]$/) {
				last;
			} elsif ($input eq KEY_BACKSPACE) {
				if ($args{'pos'} > 0) {
					substr($args{'content'}, $args{'pos'} - 1, 1) = '';
					--$args{'pos'};
					if ($args{'hz_scroll'}) {
						--$ml if ($args{'pos'} < $ml);
					}
				} else {
					beep();
				}
			} elsif ($input eq KEY_LEFT) {
				if ($args{'pos'} > 0) {
					--$args{'pos'};
					if ($args{'hz_scroll'}) {
						--$ml if ($args{'pos'} < $ml);
					}
				} else {
					beep();
				}
			} elsif ($input eq KEY_RIGHT) {
				if ($args{'pos'} < length($args{'content'})) {
					++$args{'pos'};
					if ($args{'hz_scroll'}) {
						++$ml if ($args{'pos'} >= ($ml + $args{'cols'}));
					}
				} else {
					beep();
				}
			} elsif ($input eq KEY_UP) {
				if ($c_line != 0) {
					if (length($line[$c_line - 1]) < $curs_pos) {
						$args{'pos'} -= ($curs_pos + 1);
					} else {
						$args{'pos'} -= length($line[$c_line - 1]);
					}
				} else {
					beep();
				}
			} elsif ($input eq KEY_DOWN) {
				if ($c_line != (scalar @line - 1)) {
					if (length($line[$c_line + 1]) < $curs_pos) {
						$args{'pos'} += (length($line[$c_line]) -
							$curs_pos);
					} else {
						$args{'pos'} += length($line[$c_line]);
					}
				} else {
					beep();
				}
			} elsif ($input eq KEY_PPAGE) {
				if ($t_line != 0) {
					$i = $c_line - $args{'lines'} + 1;
					$i = 1 if ($i < 1);
					foreach (@line[$i..($c_line - 1)]) {
						$args{'pos'} -= length($_);
					}
					--$i;
					if ($curs_pos > length($line[$i])) {
						$args{'pos'} -= ($curs_pos + 1);
					} else {
						$args{'pos'} -= length($line[$i]);
					}
				} else {
					beep();
				}
			} elsif ($input eq KEY_NPAGE) {
				if (($t_line + $args{'lines'}) < scalar @line) {
					$args{'pos'} += (length($line[$c_line]) - $curs_pos);
					$i = 1;
					while (($i + $c_line) < (scalar @line - 1) && $i <
						$args{'lines'}) {
						$args{'pos'} += length($line[$i + $c_line]);
						++$i;
					}
					if (length($line[$i + $c_line]) > $curs_pos) {
						$args{'pos'} += $curs_pos;
					} else {
						$args{'pos'} += (length($line[$i + $c_line]) - 1);
					}
				} else {
					beep();
				}
			} elsif ($input eq KEY_HOME) {
				$args{'pos'} = $ml = 0;
			} elsif ($input eq KEY_END) {
				$args{'pos'} = length($args{'content'});
				$ml = ($args{'pos'} - $args{'cols'} + 1) if 
					(($args{'pos'} + 1) > $args{'cols'});
			} else {
				if ($args{'edit'}) {
					if (exists $args{'c_limit'} &&
						length($args{'content'}) == $args{'c_limit'}) {
						beep();
					} else {
						if ($args{'pos'} == 0) {
							$args{'content'} = $input . $args{'content'};
						} elsif ($args{'pos'} > length($args{'content'})) {
							$args{'content'} .= $input;
						} else {
							$args{'content'} = substr($args{'content'}, 0,
								$args{'pos'}) . $input .
								substr($args{'content'}, $args{'pos'});
						}
						++$args{'pos'};
						if ($args{'hz_scroll'}) {
							++$ml if ($args{'pos'} >= ($ml + $args{'cols'}));
						}
					}
				} else {
					beep();
				}
			}
			draw();
		}
	}
	$fwh->delwin;
	return ($input, $args{'content'}, $args{'pos'});
}

sub buttons {
	# Draws a set of vertical or horizontal buttons.
	#
	# Usage:  ($key, $selected) = buttons( [name => value], etc. );

	my %args = (
		'ypos' 			=> 1,
		'xpos'			=> 1,
		'spacing'		=> 2,
		'active_button'	=> 0,
		@_,
	);
	my ($input, $i, $x, $y, $k, $bwh);
	my ($x2, $y2, $maxx, $maxy);

	# Get the window boundaries
	$args{'window'}->getmaxyx($y2, $x2);
	--$y2;
	--$x2;
	$maxy = 1;
	$maxx = 0;
	if ($args{'vertical'}) {
		foreach (@{$args{'buttons'}}) {
			$maxy += $args{'spacing'};
			$maxx = length($_) if (length($_) > $maxx);
		}
		$maxy -= $args{'spacing'};
	} else {
		foreach (@{$args{'buttons'}}) {
			$maxx += (length($_) + $args{'spacing'});
		}
		$maxx -= $args{'spacing'};
	}
	if (($maxy + $args{'ypos'}) > $y2 || $args{'ypos'} < 0 || 
		($maxx + $args{'xpos'}) > $x2 || $args{'xpos'} < 0) {
		warn << "__EOF__";
Button bar widget's boundaries exceed the parent window's--not drawing:
	YPOS:  $args{'ypos'}	LINES:	$maxy	MAXY:  $y2
	XPOS:  $args{'xpos'}	COLS:   $maxx	MAXX:  $x2
__EOF__
		return;
	}
	$bwh = $args{'window'}->derwin($maxy, $maxx, $args{'ypos'}, 
		$args{'xpos'});

	local *draw = sub {
		$x = $y = $i = 0;
		foreach (@{$args{'buttons'}}) {
			if ($args{'vertical'}) {
				$y += $args{'spacing'} if ($i > 0);
			} else {
				($x += ($args{'spacing'} + $i)) if ($i > 0);
			}
			$i = length($_);
			$bwh->standout() if ($_ eq 
				$args{'buttons'}[$args{'active_button'}]);
			$bwh->addstr($y, $x, $_);
			$bwh->standend() if ($_ eq
				$args{'buttons'}[$args{'active_button'}]);
		}
		$bwh->refresh;
	};

	draw();
	if (! exists $args{'draw_only'}) {
		$bwh->keypad(1);
		while ($input = grab_key($bwh, $args{'function'})) {
			$k = 0;
			if (exists $args{'vertical'}) {
				if ($input eq KEY_UP) {
					--$args{'active_button'} if ($args{'active_button'}
						> 0);
					draw();
					$k = 1;
				} elsif ($input eq KEY_DOWN) {
					++$args{'active_button'} if ($args{'active_button'}
						< (@{$args{'buttons'}} - 1));
					draw();
					$k = 1;
				}
			} else {
				if ($input eq KEY_LEFT) {
					--$args{'active_button'} if ($args{'active_button'}
						> 0);
					draw();
					$k = 1;
				} elsif ($input eq KEY_RIGHT) {
					++$args{'active_button'} if ($args{'active_button'}
						< (@{$args{'buttons'}} - 1));
					draw();
					$k = 1;
				}
			}
			if ($k == 0) {
				$bwh->delwin;
				return ($input, $args{'active_button'});
			}
		}
	}
	$bwh->delwin;
}

sub select_colour {
	# Internal and external subroutine.  Used by all widgets.  Selects 
	# the desired colour pair.
	#
	# Usage:  select_colour($mwh, 'red', ['black']);

	my ($wh, $fore, $back) = @_;
	my %colours = ( 'black' => COLOR_BLACK,		'cyan'		=> COLOR_CYAN,
					'green' => COLOR_GREEN,		'magenta'	=> COLOR_MAGENTA,
					'red'	=> COLOR_RED,		'white'		=> COLOR_WHITE,
					'yellow'=> COLOR_YELLOW,	'blue'		=> COLOR_BLUE);
	my (@pairs, $pr);

	# Make sure the foreground was specified at a minimum.
	if (! defined $fore) {
		warn "No foreground colour specified--ignoring command.\n";
		return 0;
	}

	# Set defualt if necessary
	$back = "black" if (! defined $back);

	# If $colour hasn't been defined, assume that colour mode hasn't been
	# initialised, either.
	if (! defined $colour) {
		$colour = has_colors();
		start_color();
	}

	# Process only if on a colour-capable console
	if ($colour) {

		# Check to see if the colour pair has already been defined
		if (exists $col_pairs{"$fore:$back"}) {
			$wh->attrset(COLOR_PAIR($col_pairs{"$fore:$back"}));
			$wh->attron(A_BOLD) if ($fore eq "yellow");
		} else {

			# Define a new colour pair if valid colours were passed
			if (exists $colours{$fore} && exists $colours{$back}) {
				@pairs = map { $col_pairs{$_} } keys %col_pairs;
				$pr = 1;
				while (grep /^$pr$/, @pairs) { ++$pr };
				init_pair($pr, $colours{$fore}, $colours{$back});
				$col_pairs{"$fore:$back"} = $pr;
				$wh->attrset(COLOR_PAIR($col_pairs{"$fore:$back"}));
				$wh->attron(A_BOLD) if ($fore eq "yellow");
			} else {
				warn "Invalid color pair passed:  $fore/$back--ignoring.\n";
			}
		}
	}

	return $colour;
}

sub list_box {
	# Draws a list box with a border, with the number of lines and 
	# columns user definable, as well as the list, title, 
	# and the border colour.
	#
	# Usage:  ($key, $selected) = list_box( [name => value], etc. );

	my %args = (
		'ypos' 		=> 1,
		'xpos' 		=> 1,
		'lines' 	=> 1,
		'cols'		=> $COLS - 2,
		'selected'	=> 0,
		@_,
	);
	my (%list, @list);;
	my ($i, $z, $y, $input, $lwh);
	my ($x2, $y2);

	# Create the internal list and hash
	unless (exists $args{'list'} || ref($args{'list'}) !~ /(ARRAY|HASH)/) {
		warn "You must pass either a hash or array reference to the " .
			"list box.\n";
	}
	if (ref($args{'list'}) eq "ARRAY") {
		@list = @{$args{'list'}};
		foreach (@list) { $list{$_} = $_ };
	} else {
		@list = sort { $a <=> $b } keys %{$args{'list'}};
		%list = %{$args{'list'}};
		for ($i = 0; $i < @list ; $i++) {
			if ($args{'selected'} eq $list[$i]) {
				$args{'selected'} = $i;
				last;
			}
		}
	}

	# Get the window boundaries and exit if the widget will exceed them
	$args{'window'}->getmaxyx($y2, $x2);
	if (($args{'cols'} + 2 + $args{'xpos'}) > $x2 || $args{'xpos'} < 0 || 
		($args{'lines'} + 2 + $args{'ypos'}) > $y2 || $args{'ypos'} < 0) {
		warn << "__EOF__";
List box widget's boundaries exceed the parent window's--not drawing:
	YPOS:  $args{'ypos'}	LINES:  $args{'lines'}	MAXY:  $y2
	XPOS:  $args{'xpos'}	COLS:   $args{'cols'}	MAXX:  $x2
__EOF__
		return;
	}
	$lwh = $args{'window'}->derwin($args{'lines'} + 2,
		$args{'cols'} + 2, $args{'ypos'}, $args{'xpos'});

	local *draw = sub {
		$i = $z = $y = 0;

		# Print the list, with the correct entry highlighted
		$z = (($args{'selected'} - $args{'lines'}) + 1) if 
			($args{'selected'} >= $args{'lines'});
		for ($i = 0; $i < $args{'lines'} ; $i++) {
			last unless(defined $list[$i + $z]);
			++$y;
			$lwh->standout if ($i + $z == $args{'selected'});
			$lwh->addstr($y, 1, substr($list{$list[$i + $z]}, 0, 
				$args{'cols'}) . "\n");
			$lwh->standend if ($i + $z == $args{'selected'});
		}

		# Draw the border title
		if (! $args{'draw_only'}) {
			select_colour($lwh, $args{'border'}) ||
				$lwh->attron(A_BOLD);
		} else {
			select_colour($lwh, $args{'border'});
		}
		for ($i = $y + 1; $i < $args{'lines'} + 1; $i++) {
			$lwh->addch($i, 1, "\n");
		}
		$lwh->box(ACS_VLINE, ACS_HLINE);
		$lwh->attrset(0);
		if (exists $args{'title'}) {
			$args{'title'} = substr($args{'title'}, 0, $args{'cols'})
				if (length($args{'title'}) > $args{'cols'});
			$lwh->standout();
			$lwh->addstr(0, 1, $args{'title'});
			$lwh->standend();
		}

		# Draw the up arrow, if necessary
		$lwh->addch(0, $args{'cols'} - 1, ACS_UARROW) if ($z > 0);

		# Draw the down arrow, if necesasry
		$lwh->addch($args{'lines'} + 1, $args{'cols'} - 1, ACS_DARROW)
			if ($z > 0);

		$lwh->refresh();
	};

	draw();
	if (! exists $args{'draw_only'}) {
		$lwh->keypad(1);
		while ($input = grab_key($lwh, $args{'function'})) {
			if ($input eq KEY_UP) {
				if ($args{'selected'} > 0) {
					--$args{'selected'};
				} else {
					beep();
				}
			} elsif ($input eq KEY_DOWN) {
				if ($args{'selected'} < (@list - 1)) {
					++$args{'selected'};
				} else {
					beep();
				}
			} elsif ($input eq KEY_PPAGE) {
				if (($args{'selected'} - $args{'lines'}) >= 0) {
					$args{'selected'} -= $args{'lines'};
				} else {
					beep() if ($args{'selected'} == 0);
					$args{'selected'} = 0;
				}
			} elsif ($input eq KEY_NPAGE) {
				if (($args{'selected'} + $args{'lines'}) < @list) {
					$args{'selected'} += $args{'lines'};
				} else {
					beep() if ($args{'selected'} == (@list - 1));
					$args{'selected'} = @list - 1;
				}
			} else {
				$lwh->delwin;
				if (ref($args{'list'}) eq "HASH") {
					return ($input, $list[$args{'selected'}]);
				} else {
					return ($input, $args{'selected'});
				}
			}
			draw();
		}
	}
	$lwh->delwin;
}

sub line_split {
	# Internal and external use, but not exported by default.  Returns
	# an array, which is the string broken according to column limits 
	# and whitespace.
	#
	# Usage:  @lines = line_split($string, 80);

	my ($content, $col_lim) = @_;
	my ($m, @line);

	if (length($content) == 0) {
		push (@line, '');
	} else {
		foreach (split(/(\n)/, $content)) {
			if (length($_) <= $col_lim) {
				if ($_ eq "\n") {
					if (scalar @line > 0) {
						$line[scalar @line - 1] .= $_;
					} else {
						push (@line, $_);
					}
				} else {
					push (@line, $_);
				}
			} else {
				if (/\b/) {
					while (length($_) > $col_lim) {
						undef $m;
						while (/\b/g) {
							if ((pos) <= $col_lim) {
								$m = pos;
							} else {
								last;
							}
						}
						unless (defined $m) { $m = $col_lim };
						++$m if (substr($_, $m, 1) =~ /\s/);
						push (@line, substr($_, 0, $m));
						$_ = substr($_, $m);
					}
					push (@line, $_);
				} else {
					while (length($_) > $col_lim) {
						push (@line, substr($_, 0, $col_lim));
						$_ = substr($_, $col_lim);
					}
					push (@line, $_);
				}
			}
		}
	}

	return @line;
}

sub grab_key {
	# Internal subroutine only.  Used by any widgets that need some sort
	# of key handling for internal functions.
	#
	# Usage:  $input = grab_key($wh, \&func_ref);

	my ($key, $win, $func) = (-1, @_);

	while ($key eq -1) {
		$key = $win->getch();

		# Hack for broken termcaps
		$key = KEY_BACKSPACE if ($key eq "\x7f");
		if ($key eq "\x1b") {
			$key .= $win->getch();
			$key .= $win->getch();
		}
		$key = KEY_HOME if ($key eq "\x1bOH");
		$key = KEY_END if ($key eq "\x1bOF");

		&$func() if (defined ($func));
	}

	return $key;
}

sub set_day {
	# Internal subroutine only.  Used by the Calendar widget.  Moves the
	# date in the direction provided by the passed argument.
	#
	# Usage:  set_day($key_passed, @date_disp);

	my ($key, @date) = @_;
	my @days = (31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31);
	my $y;

	# Adjust for leap years, if necessary
	$days[1] += 1 if ((($date[2] / 4) !~ /\./) &&
		((($date[2] / 100) =~ /\./) ||
		(($date[2] / 400) !~ /\./)));

	# Navigate according to key press
	if ($key eq KEY_LEFT) {
		$date[0] -= 1;
		if ($date[0] == 0) {
			@date = move_month(-1, @date);
			$date[0] = $days[$date[1] - 1];
		}
	} elsif ($key eq KEY_RIGHT) {
		$date[0] += 1;
		if ($date[0] > $days[$date[1] - 1]) {
			$date[0] = 1;
			@date = move_month(1, @date);
		}
	} elsif ($key eq KEY_UP) {
		$date[0] -= 7;
		if ($date[0] < 1) {
			@date = move_month(-1, @date);
			$date[0] = $days[$date[1] - 1] - 
				($date[0] * -1);
		}
	} elsif ($key eq KEY_DOWN) {
		$date[0] += 7;
		if ($date[0] > $days[$date[1] - 1]) {
			@date = move_month(1, @date);
			$date[0] = $date[0] - $days[$date[1] - 1];
		}
	} elsif ($key eq KEY_NPAGE) {
		@date = move_month(1, @date);
		$y = $date[1] - 1;
		$date[0] = $days[$y] if ($date[0] > $days[$y]);
	} elsif ($key eq KEY_PPAGE) {
		@date = move_month(-1, @date);
		$y = $date[1] - 1;
		$date[0] = $days[$y] if ($date[0] > $days[$y]);
	} elsif ($_[0] eq KEY_HOME) {
		@date = (localtime)[3..5];
		$date[1] += 1;
		$date[2] += 1900;
	}

	return @date;
}

sub move_month {
	# Internal subroutine only.  Used by the Calendar Widget.  Moves the
	# month value to the correct value when navigating to a subsequent or
	# previous year.
	#
	# Usage: move_month($month_offset, @date_disp);

	my ($offset, @date) = @_;

	$date[1] += $offset;
	if ($date[1] < 1) {
		$date[1] = 12;
		$date[2] -= 1;
	} elsif ($date[1] > 12) {
		$date[1] = 1;
		$date[2] += 1;
	}

	return (@date);
}

sub get_cal {
	# Internal subroutine only.  Used by the Calendar widget.
	# Generates its own 'cal' output.
	#
	# Modified from code provided courtesy of Michael E. Schechter,
	# <mschechter@earthlink.net>
	#
	# Usage:  @output = get_cal(@date_disp);

	my @date = @_;
	my (@cal, $i, @out);

	local *print_month = sub {
		my( $year, $month ) = @_;
		my( @month ) = &make_month_array( $year, $month );
		my( $title, $diff, $left, $day, $end, $x, $out ) = ();
		my( @months ) = ( '', 'January', 'February', 'March', 'April', 'May',
						  'June', 'July', 'August', 'September', 'October',
						  'November', 'December' );
		my $days = 'Su Mo Tu We Th Fr Sa';

		$title = "$months[ $month ] $year";
		$diff = 20 - length($title);
		$left = $diff - int($diff / 2);
		$title = ' ' x $left."$title";
		$out = "$title\n$days";
		$end = 0;
		for( $x = 0; $x < scalar @month; $x++ ) {
			$out .= "\n" if( $end == 0 );
			$out .= "$month[ $x ]";
			$end++;
			if( $end > 6 ) {
				$end = 0;
			}
		}
		$out .= "\n";
		return $out;
	};

	local *make_month_array = sub {
		my( $year, $month ) = @_;
		my( @month_array, $numdays, $remain, $x, $y ) = ();
		my( $firstweekday ) = &day_of_week_num( $year, $month, 1 );
		$numdays = &days_in_month( $year, $month );
		$y = 1;
		for( $x = 0; $x < $firstweekday; $x++ ) { $month_array[$x] = '   ' };
		if( !(($year == 1752) && ($month == 9)) ) {
			for( $x = 1; $x <= $numdays; $x++, $y++ ) { 
				$month_array[$x + $firstweekday - 1] = sprintf( "%2d ", $y);
			}
		} else {
			for( $x = 1; $x <= $numdays; $x++, $y++ ) { 
				$month_array[$x + $firstweekday - 1] = sprintf( "%2d ", $y);
				if( $y == 2 ) {
					$y = 13;
				}
			}
		}
		return( @month_array );
	};

	local *day_of_week_num = sub {
		my( $year, $month, $day ) = @_;
		my( $a, $y, $m, $d ) = ();
		$a = int( (14 - $month)/12 );
		$y = $year - $a;
		$m = $month + (12 * $a) - 2;
		if( &is_julian( $year, $month ) ) {
			$d = (5 + $day + $y + int($y/4) + int(31*$m/12)) % 7;
		} else {
			$d = ($day + $y + int($y/4) - int($y/100) + int($y/400) + 
				int(31*$m/12)) % 7;
		}
		return( $d );
	};

	local *days_in_month = sub {
		my( $year, $month ) = @_;
		my( @month_days ) = ( 0,31,28,31,30,31,30,31,31,30,31,30,31 );
		if( ($month == 2) && (&is_leap_year( $year )) ) {
			$month_days[ 2 ] = 29;
		} elsif ( ($year == 1752) && ($month == 9) ) {
			$month_days[ 9 ] = 19;
		}
		return( $month_days[ $month ] );
	};

	local *is_julian = sub {
		my( $year, $month ) = @_;
		my( $bool ) = 0;
		if( ($year < 1752) || ($year == 1752 && $month <= 9) ) {
			$bool = 1;
		}
		return( $bool );
	};

	local *is_leap_year = sub {
		my( $year ) = @_;
		my( $bool ) = 0;
		if( &is_julian( $year, 1 ) ) {
			if( $year % 4 == 0 ) {
				$bool = 1;
			}
		} else {
			if( (($year % 4 == 0) && ($year % 100 != 0)) || 
				($year % 400 == 0) ) {
				$bool = 1;
			}
		}
		return( $bool );
	};

	@cal = split(/\n/, print_month(@date[2,1]));
	push(@cal, "\n") if (scalar @cal < 8);
	$i = 0;
	foreach (@cal) {
		if ($i > 1) {
			$_ =~ s/^\s+//;
			push(@out, [ grep(/^\d+$/, split(/\s+/, $_)) ]);
		} else {
			push(@out, $_);
		}
		++$i;
	}

	return @out;
}

sub calendar {
	# Draws the Calendar with the specified date highlighted.  Exits
	# immediately if draw_only is specified, otherwise, blocks and traps
	# keys, performing immediate navigation and updates on special keys, 
	# but exiting and returning other pressed keys as a function.
	#
	# Usage:  calendar( [name => value], etc. );

	my (%args) = (
		'ypos'		=> 1,
		'xpos'		=> 1,
		'border' 	=> 'red',
		't_colour'	=> 'yellow',
		'e_colour'	=> 'red',
		'events'	=> [],
		'date_disp'	=> [],
		@_
	);
	my ($i, $day, $y, $z, $input, $cwh, @cal, @events, $tmp, @tmp);
	my (@spec_keys) = (KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT,
					   KEY_PPAGE, KEY_NPAGE, KEY_HOME);
	my ($x2, $y2, $today);

	# Check to make sure the calendar won't exceed the window boundaries
	$args{'window'}->getmaxyx($y2, $x2);
	--$y2;
	--$x2;
	if ($args{'ypos'} < 0 || $args{'xpos'} < 0 ||
		($args{'ypos'} + 10) > $y2 || ($args{'xpos'} + 24) > $x2) {
		warn << "__EOF__";
List box widget's boundaries exceed the parent window's--not drawing:
	YPOS:  $args{'ypos'}	LINES:  @{[$args{'lines'} + 10]}	MAXY:  $y2
	XPOS:  $args{'xpos'}	COLS:   @{[$args{'cols'} + 24]}	MAXX:  $x2
__EOF__
		return;
	}
	$cwh = $args{'window'}->derwin(10, 24, $args{'ypos'}, $args{'xpos'});

	# Get the initial calendar, if none is loaded yet
	if (! ${$args{'date_disp'}}[0]) {
		@{$args{'date_disp'}} = (localtime)[3..5];
		${$args{'date_disp'}}[1] += 1;
		${$args{'date_disp'}}[2] += 1900;
	}
	@cal = get_cal(@{$args{'date_disp'}});

	# Declare local sub draw
	local *draw = sub {

		# Print the calendar
		$cwh->addstr(1, 2, "$cal[0]\n");
		$cwh->addstr(2, 2, "$cal[1]\n");
		$today = (localtime)[3] . "/" . ((localtime)[4] + 1) . "/" .
			((localtime)[5] + 1900);
		for ($i = 2; $i < 8; $i++) {
			$tmp = 0;

			# Check to see if month starts later in the week, and if so,
			# advance starting position
			if ($i == 2) {
				if (scalar @{$cal[$i]} < 7) {
					$tmp = (7 - scalar @{$cal[$i]}) * 3;
					$cwh->addstr($i + 1, 2, ' ' x $tmp);
				}
			}

			# Work through each day
			foreach (@{$cal[$i]}) {
				$day =
					"$_/${$args{'date_disp'}}[1]/${$args{'date_disp'}}[2]";

				# Check to see if the current date is today's date
				if ($day eq $today) {
					select_colour($cwh, $args{'t_colour'}) ||
						$cwh->attron(A_BOLD);
				}

				# Check to see if the current date has an event
				if (grep(/^$day$/, @{$args{'events'}})) {
					select_colour($cwh, $args{'e_colour'}) ||
						$cwh->attron(A_BOLD);
				}

				# Check to see if the current date is the date selected
				if ($day eq join("/", @{$args{'date_disp'}})) {
					$cwh->attron(A_REVERSE);
				}
					
				$cwh->addstr($i + 1, 2 + $tmp, ' ' x (2 - length($_)) . $_);
				$cwh->attrset(0);
				$tmp += 3;
			}
			$cwh->addstr($i + 1, 2 + $tmp, "\n");
		}

		# Draw the border
		if (! $args{'draw_only'}) {
			select_colour($cwh, $args{'border'}) ||
				$cwh->attron(A_BOLD);
		} else {
			select_colour($cwh, $args{'border'});
		}
		$cwh->box(ACS_VLINE, ACS_HLINE);
		$cwh->attrset(0);
		$cwh->refresh();
	};

	draw();
	if (! exists $args{'draw_only'}) {
		$cwh->keypad(1);
		while ($input = grab_key($cwh, $args{'function'})) {
			$z = 0;
			foreach (@spec_keys) {
				if ($_ eq $input) {
					# Move the displayed date in the desired direction
					@{$args{'date_disp'}} =
						set_day($input, @{$args{'date_disp'}});
					@cal = get_cal(@{$args{'date_disp'}});
					draw();
					$z = 1;
					last;
				}
			}
			if ($z == 0) {
				$cwh->delwin();
				return $input;
			}
		}
	}
	$cwh->delwin();
}

sub msg_box {
	# Draws an message box with a single OK button on it.  The window is
	# auto resizing, and auto-centering.  Once the OK button is activated, 
	# it will destroy it's window before touching and refreshing the 
	# calling window.  The message box can optionally be created with an
	# OK and CANCEL button, if desired.
	#
	# Usage:  msg_box( [ 'title' => $title], etc. );

	my %args = ( 'message' => '!', 'mode' => 1, 'border' => 'blue', @_ );

	my ($x1, $y1, $x2, $cols, $rows);
	my (@line, $mbwh, $max, $ok, @buttons);

	# Get the console geometry and start plotting the msg_box dimensions
	$cols = $COLS - 4;
	$rows = $LINES - 3;

	# Set the absolute minimum of any msg_box, and exit now if there's 
	# not enough room.
	$max = 10;
	$max = 20 if ($args{'mode'} == 2);
	if ($rows < 1 || $cols < $max) {
		warn "Not enough room for the message box--not showing.\n";
		return;
	}

	# Continue plotting dimensions
	if (length($args{'message'}) > $cols) {
		@line = line_split($args{'message'}, $cols);
	} else {
		push(@line, $args{'message'});
	}
	@line = @line[0..$rows] if (scalar @line > $rows);
	$max = 0;
	foreach (@line) { $max = length($_) if (length($_) > $max) };
	$max = 20 if ($args{'mode'} == 2 && $max < 20);
	$x1 = int(($cols - $max) / 2);
	$y1 = int(($rows - scalar @line) / 2);
	$x1 = 0 if ($x1 < 0);
	$y1 = 0 if ($y1 < 0);

	$mbwh = newwin(scalar @line + 3, $max + 4, $y1, $x1);

	$x1 = 2;
	$y1 = 1;
	foreach (@line) {
		$mbwh->addstr($y1, $x1, $_);
		++$y1;
	}
	select_colour($mbwh, $args{'border'}) if (exists $args{'border'});
	$mbwh->box(ACS_VLINE, ACS_HLINE);
	$mbwh->attrset(0);
	if (exists $args{'title'}) {
		$args{'title'} = substr($args{'title'}, 0, $max + 2)
			if (length($args{'title'}) > $max + 2);
		$mbwh->standout();
		$mbwh->addstr(0, 1, $args{'title'});
		$mbwh->standend();
	}
	$mbwh->refresh();

	# Display the proper button set
	@buttons = ( "< Ok >" );
	push(@buttons, "< Cancel >") if ($args{'mode'} == 2);

	if ($args{'mode'} == 2) {
		$x1 = int(($max - 18) / 2) + 1;
	} else {
		$x1 = int(($max - 6) / 2);
	}
	$ok = '';
	$x2 = 0;
	while ($ok !~ /[\n ]/) {
		($ok, $x2) = buttons( 'window'		=> $mbwh,
							  'buttons'		=> \@buttons,
							  'ypos'		=> $y1,
							  'xpos'		=> $x1,
							  'active_button' => $x2,
							  'function'	=> $args{'function'});
	}
	++$x2;
	$x2 = 0 if ($x2 == 2);

	$mbwh->delwin;

	return ($x2);
}

sub input_box {
	# Draws an input box with OK/CANCEL buttons on it.  The window is
	# auto resizing, and auto-centering.  Once a button is activated, 
	# it will destroy it's window before touching and refreshing the 
	# calling window.  This will return both the input field value
	# and a 1 or a 0, depending on whether OK or CANCEL was pressed.
	#
	# Usage:  ($input, $button) = input_box( [ 'title' => $title], etc. );

	my %args = ( 'password' => 0, 
				 'cols'		=> 0,
				 'border'	=> 'blue',
				 'f_colour' => 'yellow',
				 @_ );

	my ($x1, $y1, $x2, $cols, $rows, $c_max);
	my (@line, $ibwh, $max, $ok, $in, $key);

	# Get the console geometry and start plotting the msg_box dimensions
	$cols = $COLS - 4;
	$rows = $LINES - 6;

	# Set the absolute minimum of any msg_box, and exit now if there's 
	# not enough room.
	if ($rows < 1 || $cols < 20) {
		warn "Not enough room for the input box--not showing.\n";
		return;
	}

	# Continue plotting dimensions
	if (length($args{'prompt'}) > $cols) {
		@line = line_split($args{'prompt'}, $cols);
	} else {
		push(@line, $args{'prompt'});
	}
	@line = @line[0..$rows] if (scalar @line > $rows);
	$max = 0;
	foreach (@line) { $max = length($_) if (length($_) > $max) };
	$max = 20 if ($max < 20);
	$x1 = int(($cols - $max) / 2);
	$y1 = int(($rows - scalar @line) / 2);
	$x1 = 0 if ($x1 < 0);
	$y1 = 0 if ($y1 < 0);

	$ibwh = newwin(scalar @line + 6, $max + 4, $y1, $x1);

	$x1 = 2;
	$y1 = 1;
	foreach (@line) {
		$ibwh->addstr($y1, $x1, $_);
		++$y1;
	}
	select_colour($ibwh, $args{'border'}) if (exists $args{'border'});
	$ibwh->box(ACS_VLINE, ACS_HLINE);
	$ibwh->attrset(0);
	if (exists $args{'title'}) {
		$args{'title'} = substr($args{'title'}, 0, $max + 2)
			if (length($args{'title'}) > $max + 2);
		$ibwh->standout();
		$ibwh->addstr(0, 1, $args{'title'});
		$ibwh->standend();
	}
	$ibwh->refresh();

	$x1 = int(($max - 18) / 2) + 1;
	$x2 = 0;
	$ok = "\t";
	$in = $args{'content'} || '';
	$c_max = $args{'c_limit'} || 255;
	while ($ok eq "\t") {
		buttons( 'window'	=> $ibwh,
				 'buttons'	=> [ "< Ok >", "< Cancel >" ],
				 'ypos'	=> $y1 + 3,
				 'xpos'	=> $x1,
				 'draw_only' => 1);
		($key, $in) = txt_field( 'window'	=> $ibwh,
								 'ypos'		=> $y1,
								 'xpos'		=> 2,
								 'cols'		=> $max - 2,
								 'border'	=> $args{'f_colour'},
								 'function' => $args{'function'},
								 'l_limit'	=> 1,
								 'hz_scroll'=> 1,
								 'c_limit'	=> $c_max,
								 'content'	=> $in,
								 'pos'		=> length($in) + 1,
								 'regex'	=> "\t\n",
								 'password'	=> $args{'password'});
		txt_field( 'window'		=> $ibwh,
				   'ypos'		=> $y1,
				   'xpos'		=> 2,
				   'cols'		=> $max - 2,
				   'content'	=> $in,
				   'border'		=> $args{'border'},
				   'draw_only'	=> 1,
				   'password'	=> $args{'password'});
		if ($key eq "\n") {
			$x2 = 1;
			$ok = "\n";
		} else {
			($ok, $x2) = buttons( 'window'	=> $ibwh,
								  'buttons'	=> [ "< Ok >", "< Cancel >" ],
								  'ypos'	=> $y1 + 3,
								  'xpos'	=> $x1,
								  'active_button' => $x2,
								  'function'=> $args{'function'});
			if ($x2 == 0) {
				$x2 = 1;
			} elsif ($x2 == 1) {
				$x2 = 0;
			}
		}
	}

	$ibwh->delwin;

	return ($in, $x2);
}

sub init_scr {
	# Check to see if executed from an interactive terminal,
	# and input/output not redirected, and setup initial screen
	# if everything passes.
	#
	# Usage:  $mwh = init_scr($miny, $minx);
	my $miny = shift;
	my $minx = shift;
	my $mwh;

	if (-t STDIN && -t STDOUT) {
	
		# Check for minimum allowable terminal size
		$mwh = new Curses;
		if ($COLS < ($minx || 80) || $LINES < ($miny || 25)) {
			endwin();
			warn "\nYour terminal size isn't large enough!\n\n";
			return 0;
		}
	} else {
		warn "\nThe terminal isn't interactive!\n\n";
		return 0;
	}

	# Initialise console settings
	noecho();
	cbreak();
	halfdelay(10);
	$mwh->keypad(1);

	return $mwh;
}

1;
