package Curses::Widgets;

########################################################################
#
# Curses Widget Module
#
# $Id: Widgets.pm,v 0.6 1999/02/02 17:18:45 corliss Exp corliss $
#
# (c) Arthur Corliss, 1998
#
# Requires the Curses module for perl, Ncurses libraries, and the Unix
# cal tool.
#
########################################################################

use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION);
use Exporter;
use Curses;

$VERSION = .06;
@ISA = qw(Exporter);

@EXPORT		= qw(txt_field buttons init_colours list_box calendar 
				 select_colour);
@EXPORT_OK	= qw(txt_field buttons init_colours list_box calendar
				 line_count);
%EXPORT_TAGS = (
		'Functions' => [ qw(txt_field buttons init_colours list_box
							calendar line_count select_colour) ],
		# 'Variables' => [ ],
);

########################################################################
#
# Module code follows. . .
#
########################################################################

BEGIN {
	my (@cal_output);
	my ($colour);

sub txt_field {
	# Draws a text field with a border, with the number of lines and 
	# columns user definable, as well as content, and the border colour.
	#
	# Parameters passed are as follows:
	#		(\$window [, ypos] [, xpos] [, lines] [, cols]
	# 		  [, content] [, pos] [, border] [, \&function]
	#		  [, draw_only])

	my (%args) = (
		'ypos' 		=> 1,
		'xpos' 		=> 1,
		'lines' 	=> 1,
		'cols'		=> $COLS - 2,
		'pos'		=> 1,
		'content'   => "\n",
		'border'	=> 'red',
		'draw_only'	=> 0,
		@_,
	);

	my ($field_win) = ${ $args{'window'} }->derwin($args{'lines'} + 2,
		$args{'cols'} + 2, $args{'ypos'}, $args{'xpos'});
	my ($i, $ch, $k, $x, $y, $input);
	my ($n_lines, $c_line, $s_line, @lines, %ch_x_ln, $page);

	local *draw = sub {
		$field_win->erase();

		# Get the line count info
		@lines = ();
		%ch_x_ln = ();
		($n_lines, $c_line) = line_count($args{'content'}, $args{'cols'},
			$args{'pos'}, \@lines, \%ch_x_ln);
		$c_line = $n_lines if (! $c_line);
		
		# Determine which page to print
		$page = 0;
		++$page until ($c_line < ($page * $args{'lines'} + 1));
		--$page if ($c_line == (($page - 1) * $args{'lines'} + 1) &&
			substr($args{'content'}, $args{'pos'} - 1, 1) eq "\n");

		# Determine which line to start printing, based on the page
		if ($args{'lines'} > 1) {
			$s_line = ($page * $args{'lines'}) - ($args{'lines'} - 1);
		} else {
			$s_line = $page = $c_line;
		}

		# Write text to the field
		$y = 1;
		for ($i = $s_line; $i < (($page * $args{'lines'}) + 1); $i++) {
			$field_win->addstr($y, 1, $lines[$i]);
			++$y;
		}

		# Highlight the cursor position
		if (! $args{'draw_only'}) {
			$y = 0;
			for ($i = 1; $i < $c_line; $i++) {
				$y += $ch_x_ln{$i};
				++$y if (substr($args{'content'}, $y, 1) eq "\n");
			}
			$args{'pos'} = (length($args{'content'}) + 1) if 
				($args{'pos'} > length($args{'content'}));
			$k = $args{'pos'} - $y;
			$s_line = $c_line - (($page - 1) * $args{'lines'});
			$field_win->standout();
			if ($args{'pos'} > length($args{'content'})) {
				$field_win->addstr($s_line, $k, ' ');
			} elsif (substr($args{'content'}, $args{'pos'} - 1, 1) eq "\n") {
				$field_win->addstr($s_line - 1, length($lines[$c_line - 1])
					+ 1, ' ');
			} else {
				$field_win->addstr($s_line, $k, substr($lines[$c_line],
					$k - 1, 1));
			}
			$field_win->standend();
		}

		# Draw the border
		if (! $args{'draw_only'}) {
		select_colour(\$field_win, $args{'border'}) || 
			$field_win->attron(A_BOLD);
		} else {
			select_colour(\$field_win, $args{'border'});
		}
		$field_win->box(ACS_VLINE, ACS_HLINE);
		$field_win->attrset(0);

		# Draw the up arrow, if necessary
		$field_win->addch(0, $args{'cols'} - 1, ACS_UARROW) if ($page > 1);

		# Draw the down arrow, if necesasry
		$field_win->addch($args{'lines'} + 1, $args{'cols'} - 1, ACS_DARROW)
			if ($page < ($n_lines / $args{'lines'}));

		$field_win->refresh();
	};

	draw();
	if (! $args{'draw_only'}) {
		$field_win->keypad(1);
		while (1) {
			$input = grab_key(\$field_win, $args{'function'});
			if ($input eq "\t") {
				return ($input, $args{'content'});
				last;
			} elsif ($input =~ 
				/^[\w\d\-\\\/0,.:;!'"()\[\]\?\$ \n@#%%\^&*{}|<>~`+=-_]$/) {
				if ($args{'pos'} == 1) {
					$args{'content'} = $input . $args{'content'};
				} elsif ($args{'pos'} > (length($args{'content'}) + 1)) {
					$args{'content'} .= $input;
				} else {
					$args{'content'} = substr($args{'content'}, 0, 
						$args{'pos'} - 1) . $input . substr($args{'content'},
						$args{'pos'} - 1);
				}
				++$args{'pos'};
			} elsif ($input eq KEY_BACKSPACE) {
				if ($args{'pos'} == 2) {
					$args{'content'} =~ s/.//;
					--$args{'pos'};
				} elsif ($args{'pos'} > 2) {
					$args{'content'} = substr($args{'content'}, 0, 
						$args{'pos'} - 2) . substr($args{'content'}, 
						$args{'pos'} - 1);
					--$args{'pos'};
				}
			} elsif ($input eq KEY_LEFT) {
				--$args{'pos'} if ($args{'pos'} > 1);
			} elsif ($input eq KEY_RIGHT) {
				++$args{'pos'} if ($args{'pos'} < (length($args{'content'}) 
					+ 1));
			} elsif ($input eq KEY_UP) {
				if ($c_line != 1) {
					--$c_line if (substr($args{'content'}, $args{'pos'} - 1,
						1) eq "\n");
					$args{'pos'} -= $k;
					--$args{'pos'} if (substr($args{'content'}, $args{'pos'}
						- 1, 1) eq "\n" && $ch_x_ln{($c_line - 1)} > $k);
					$args{'pos'} -= ($ch_x_ln{($c_line - 1)} - $k) if
						($ch_x_ln{($c_line - 1)} > $k);
				} else {
					beep();
				}
			} elsif ($input eq KEY_DOWN) {
				if ($c_line != $n_lines) {
					if (substr($args{'content'}, $args{'pos'} - 1,
						1) eq "\n") {
						--$c_line;
						++$args{'pos'};
					}
					$args{'pos'} += ($ch_x_ln{$c_line} - $k + 1);
					++$args{'pos'} if (substr($args{'content'}, $args{'pos'}
						- 1, 1) eq "\n");
					if ($ch_x_ln{($c_line + 1)} > $k) {
						$args{'pos'} += ($k - 1);
					} else {
						$args{'pos'} += $ch_x_ln{($c_line + 1)};
					}
				} else {
					beep();
				}
			} elsif ($input eq KEY_PPAGE) {
				if ($c_line == 1) {
					beep();
				} else {
					if (substr($args{'content'}, $args{'pos'} - 1, 1) 
						eq "\n") {
						--$c_line;
					} else {
						$args{'pos'} -= $k;
					}
					$s_line = $c_line - $args{'lines'};
					$s_line = 1 if ($s_line < 1);
					--$c_line;
					while ($c_line != $s_line) {
						--$args{'pos'} if (substr($args{'content'},
							$args{'pos'} - 1, 1) eq "\n");
						$args{'pos'} -= $ch_x_ln{$c_line};
						--$c_line;
					}
					$args{'pos'} -= ($ch_x_ln{$c_line} - $k) if ($k < 
						$ch_x_ln{$c_line});
				}
			} elsif ($input eq KEY_NPAGE) {
				if ($c_line == $n_lines) {
					beep();
				} else {
					if (substr($args{'content'}, $args{'pos'} - 1, 1) 
						eq "\n") {
						--$c_line;
					} else {
						$args{'pos'} += ($ch_x_ln{$c_line} - $k + 1);
					}
					$s_line = $c_line + $args{'lines'};
					$s_line = $n_lines if ($s_line > $n_lines);
					++$c_line;
					while ($c_line != $s_line) {
						++$args{'pos'} if (substr($args{'content'}, 
							$args{'pos'} - 1, 1) eq "\n");
						$args{'pos'} += $ch_x_ln{$c_line};
						++$c_line;
					}
					if ($k > $ch_x_ln{$c_line}) {
						$args{'pos'} += $ch_x_ln{$c_line};
					} else {
						$args{'pos'} += $k;
					}
				}
			} elsif ($input eq KEY_HOME) {
				$args{'pos'} = 1;
			} elsif ($input eq KEY_END) {
				$args{'pos'} = length($args{'content'}) + 1;
			}
			draw();
		}
	}
	$field_win->delwin();
}

sub buttons {
	# Draws a set of vertical or horizontal buttons.
	#
	# Parameter list is as follows:
	# 	(\$window, \@buttons [, ypos] [, xpos] [, active_button] 
	#	 [, \&function] [, vertical] [, draw_only])
	my (%args) = (
		'ypos' 			=> 1,
		'xpos'			=> 1,
		@_,
	);
	my ($button, $input, $i, $x, $y, $k);

	local *draw = sub {
		$x = $args{'xpos'};
		$y = $args{'ypos'};
		$i = 0;
		foreach $button (@{ $args{'buttons'} }) {
			if (exists $args{'vertical'}) {
				$y += 2 if ($i > 0);
			} else {
				($x += (2 + $i)) if ($i > 0);
			}
			${ $args{'window'} }->standout() if ($button eq
				${ $args{'buttons'} }[$args{'active_button'}]);
			${ $args{'window'} }->addstr($y, $x, $button);
			${ $args{'window'} }->standend() if ($button eq
				${ $args{'buttons'} }[$args{'active_button'}]);
			$i = length($button);
		}
	};

	draw();
	if (! exists $args{'draw_only'}) {
		${ $args{'window'} }->keypad(1);
		while ($input = grab_key($args{'window'}, $args{'function'})) {
			$k = 0;
			if (exists $args{'vertical'}) {
				if ($input eq KEY_UP) {
					--$args{'active_button'} if ($args{'active_button'}
						> 1);
					draw();
					$k = 1;
				} elsif ($input eq KEY_DOWN) {
					++$args{'active_button'} if ($args{'active_button'}
						< (@{ $args{'buttons'} } - 1));
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
						< (@{ $args{'buttons'} } - 1));
					draw();
					$k = 1;
				}
			}
			if ($k == 0) {
				return ($input, $args{'active_button'});
				last;
			}
		}
	}
}

sub init_colours {
	# Initialise colour handling and the colour pairs.

	$colour = has_colors();

	if ($colour) {
		start_color();
		init_pair(1, COLOR_RED, COLOR_BLACK);
		init_pair(2, COLOR_GREEN, COLOR_BLACK);
		init_pair(3, COLOR_BLUE, COLOR_BLACK);
		init_pair(4, COLOR_YELLOW, COLOR_BLACK);
	}
}

sub select_colour {
	# Internal and external subroutine.  Used by all widgets.  Selects 
	# the desired colour pair.
	#
	# Parameters passed are as follows:
	#	(\$window, colour)

	if ($colour) {
		if ($_[1] eq 'red') {
			${ $_[0] }->attrset(COLOR_PAIR(1));
		} elsif ($_[1] eq 'green') {
			${ $_[0] }->attrset(COLOR_PAIR(2));
		} elsif ($_[1] eq 'blue') {
			${ $_[0] }->attrset(COLOR_PAIR(3));
		} elsif ($_[1] eq 'yellow') {
			${ $_[0] }->attrset(COLOR_PAIR(4));
			${ $_[0] }->attron(A_BOLD);
		}
	}

	return $colour;
}

sub list_box {
	# Draws a list box with a border, with the number of lines and 
	# columns user definable, as well as the list, and the border colour.
	#
	# Parameters passed are as follows:
	#		(\$window [, ypos] [, xpos] [, lines] [, cols]
	# 		 [, \%list] [, border] [, selected] [, \&function] 
	#		 [, draw_only])
	my (%args) = (
		'ypos' 		=> 1,
		'xpos' 		=> 1,
		'lines' 	=> 1,
		'cols'		=> $COLS - 2,
		@_,
	);
	my ($list_win) = ${ $args{'window'} }->derwin($args{'lines'} + 2,
		$args{'cols'} + 2, $args{'ypos'}, $args{'xpos'});
	my ($i, $z, $k, $x, $y, @list, $input);

	local *draw = sub {
		$i = $z = $k = $x = $y = @list = ();
		# Print the list, with the correct entry highlighted
		if (exists ($args{'list'})) {
			@list = sort { $a <=> $b } keys (%{ $args{'list'} });
			$args{'selected'} = $list[0] if (! exists $args{'selected'});
			$k = @list;
			$z = $args{'selected'} - $args{'lines'} if 
				($args{'selected'} > $args{'lines'});
			for ($i = $z; $i < $k && $i < $args{'lines'} + 1 + $z; $i++) {
				++$y;
				$list_win->standout() if 
					($list[$i] == $args{'selected'});
				$list_win->addstr($y, 1, substr(${ $args{'list'} }{$list[$i]}, 
					0, $args{'cols'}) . "\n");
				$list_win->standend() if ($list[$i] == $args{'selected'});
			}
		}

		# Draw the border
		if (! $args{'draw_only'}) {
			select_colour(\$list_win, $args{'border'}) ||
				$list_win->attron(A_BOLD);
		} else {
			select_colour(\$list_win, $args{'border'});
		}
		for ($i = $y + 1; $i < $args{'lines'} + 1; $i++) {
			$list_win->addch($i, 1, "\n");
		}
		$list_win->box(ACS_VLINE, ACS_HLINE);
		$list_win->attrset(0);

		# Draw the up arrow, if necessary
		$list_win->addch(0, $args{'cols'} - 1, ACS_UARROW) if ($z > 0);

		# Draw the down arrow, if necesasry
		$list_win->addch($args{'lines'} + 1, $args{'cols'} - 1, ACS_DARROW)
			if (($z + $args{'lines'}) < $list[(@list - 1)]);

		$list_win->refresh();
	};

	draw();
	if (! exists $args{'draw_only'}) {
		$list_win->keypad(1);
		while ($input = grab_key(\$list_win, $args{'function'})) {
			$k = 0;
			if ($input eq KEY_UP || $input eq KEY_DOWN) {
				if ($input eq KEY_UP) {
					--$args{'selected'} if (exists 
						${ $args{'list'} }{$args{'selected'} - 1});
				} else {
					++$args{'selected'} if (exists
						${ $args{'list'} }{$args{'selected'} + 1});
				}
				$k = 1;
				draw();
			}
			if ($k == 0) {
				return ($input, $args{'selected'});
				last;
			}
		}
	}
	$list_win->delwin();
}

sub line_count {
	# Internal and external use, but not exported by default.  Counts
	# the number of lines in a string, accounting for both line length
	# and new lines.  Returns the line count, and the line the passed
	# character position is on, if included in the arguments.
	#
	# Two optional references can be passed as the fourth and fifth
	# argument (an array ref & hash ref, respectively).  The string's
	# contents will be list by line number in the array, and the number
	# of characters on each line will be entered in the hash, by line.
	#
	# Parameters passed are as follows:
	#	(string, line_length [, cur_pos] [, \@lines] [, \%ch_x_ln])

	my ($i, $ch, $n_lns, $cur_line);
	my (@lines, %ch_x_ln);
	
	$n_lns = 1;
	for ($i = 0; $i < length($_[0]); $i++) {
		$ch = substr($_[0], $i, 1);
		if ($ch ne "\n") {
			++$n_lns if (length($lines[$n_lns]) == $_[1]);
			$lines[$n_lns] .= $ch;
			++$ch_x_ln{$n_lns};
		} else {
			++$n_lns;
		}
		($cur_line = $n_lns) if ($i == ($_[2] - 1));
	}
	@{ $_[3] } = @lines if (defined ($_[3]));
	%{ $_[4] } = %ch_x_ln if (defined ($_[4]));
	return ($n_lns, $cur_line);
}

sub grab_key {
	# Internal subroutine only.  Used by any widgets that need some sort
	# of key handling for internal functions.
	#
	# Parameters passed are as follows:
	#	(\$window [, \&timeout_function])

	my ($key) = -1;
	my ($func) = $_[1];

	while ($key == -1) {
		$key = ${ $_[0] }->getch();
		&$func() if (defined ($_[1]));
	}
	return $key;
}

sub set_day {
	# Internal subroutine only.  Used by the Calendar widget.  Moves the
	# date in the direction provided by the passed argument.
	#
	# Parameters passed are as follows:
	#	($key_passed, \@date_disp, \@cal_output)
	my (@days) = (31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31);
	my ($x, $y);

	if (defined $_[0]) {
		$days[1] += 1 if (((${ $_[1] }[2] / 4) !~ /\./) &&
			(((${ $_[1] }[2] / 100) =~ /\./) ||
			((${ $_[1] }[2] / 400) !~ /\./)));
		if ($_[0] eq KEY_LEFT) {
			${ $_[1] }[0] -= 1;
			if (${ $_[1] }[0] == 0) {
				move_month(-1, \@{ $_[1] });
				${ $_[1] }[0] = $days[${ $_[1] }[1] - 1];
				get_cal(\@{ $_[1] }, \@{ $_[2] });
			}
		} elsif ($_[0] eq KEY_RIGHT) {
			${ $_[1] }[0] += 1;
			if (${ $_[1] }[0] > $days[${ $_[1] }[1] - 1]) {
				${ $_[1] }[0] = 1;
				move_month(1, \@{ $_[1] });
				get_cal(\@{ $_[1] }, \@{ $_[2] });
			}
		} elsif ($_[0] eq KEY_UP) {
			${ $_[1] }[0] -= 7;
			if (${ $_[1] }[0] < 1) {
				move_month(-1, \@{ $_[1] });
				get_cal(\@{ $_[1] }, \@{ $_[2] });
				${ $_[1] }[0] = $days[${ $_[1] }[1] - 1] - 
					(${ $_[1] }[0] * -1);
			}
		} elsif ($_[0] eq KEY_DOWN) {
			${ $_[1] }[0] += 7;
			if (${ $_[1] }[0] > $days[${ $_[1] }[1] - 1]) {
				move_month(1, \@{ $_[1] });
				get_cal(\@{ $_[1] }, \@{ $_[2] });
				${ $_[1] }[0] = ${ $_[1] }[0] - $days[${ $_[1] }[1] - 1];
			}
		} elsif ($_[0] eq KEY_NPAGE) {
			$x = ${ $_[1] }[1] - 1;
			move_month(1, \@{ $_[1] });
			$y = ${ $_[1] }[1] - 1;
			${ $_[1] }[0] = $days[$y] if (${ $_[1] }[0] > $days[$y]);
			get_cal(\@{ $_[1] }, \@{ $_[2] });
		} elsif ($_[0] eq KEY_PPAGE) {
			$x = ${ $_[1] }[1] -1;
			move_month(-1, \@{ $_[1] });
			$y = ${ $_[1] }[1] - 1;
			${ $_[1] }[0] = $days[$y] if (${ $_[1] }[0] > $days[$y]);
			get_cal(\@{ $_[1] }, \@{ $_[2] });
		} elsif ($_[0] eq KEY_HOME || $_[0] eq 't') {
			@{ $_[1] } = ();
			@{ $_[1] } = (localtime)[3..5];
			${ $_[1] }[1] += 1;
			${ $_[1] }[2] += 1900;
			get_cal(\@{ $_[1] }, \@{ $_[2] });
		}
	}
}

sub move_month {
	# Internal subroutine only.  Used by the Calendar Widget.  Moves the
	# month value to the correct value when navigating to a subsequent or
	# previous year.
	#
	# Parameters passed are as follows:
	#	($month_offset, \@date_disp)
	if ((defined $_[0]) && ($_[0] =~ /^[-+]?\d+$/)) {
		${ $_[1] }[1] += $_[0];
		if (${ $_[1] }[1] < 1) {
			${ $_[1] }[1] = 12;
			${ $_[1] }[2] -= 1;
		} elsif (${ $_[1] }[1] > 12) {
			${ $_[1] }[1] = 1;
			${ $_[1] }[2] += 1;
		}
	}
}

sub get_cal {
	# Internal subroutine only.  Used by the Calendar widget.  Just gets
	# the output of the Unix cal program for the desired month.
	#
	# Parameters passed are as follows:
	#	(\@date_disp, \@cal_output)
	my ($command) = 'cal ' . ${ $_[0] }[1] . ' ' . ${ $_[0] }[2];
	
	open (INPT, "$command |");
	@{ $_[1] } = <INPT>;
	close (INPT);
}

sub calendar {
	# Draws the Calendar with the specified date highlighted.  Exits
	# immediately if draw_only is specified, otherwise, blocks and traps
	# keys, performing immediate navigation and updates on special keys, 
	# but exiting and returning other pressed keys as a function.
	#
	# Parameters are passed as follows:
	#	(\$window, ypos, xpos, \@date_disp [, border] [, \&function] 
	# 	 [, draw_only] [, \@days] [, d_colour])
	my (%args) = (
		'ypos'		=> 1,
		'xpos'		=> 1,
		'border' 	=> 'red',
		'd_colour'	=> 'yellow',
		@_
	);
	my ($cal_win) = ${ $args{'window'} }->derwin(10, 24, $args{'ypos'},
		$args{'xpos'});
	my ($i, $today, $y, $z, $input);
	my (@spec_keys) = (KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT,
					   KEY_PPAGE, KEY_NPAGE, KEY_HOME, 't');

	# Get the initial calendar, if none is loaded yet
	if (! ${ $args{'date_disp'} }[0]) {
		@{ $args{'date_disp'} } = (localtime)[3..5];
		${ $args{'date_disp'} }[1] += 1;
		${ $args{'date_disp'} }[2] += 1900;
	}
	if (@cal_output < 3) {
		get_cal($args{'date_disp'}, \@cal_output);
	}
	# Declare local sub draw
	local *draw = sub {
		# Print the calendar
		for ($i = 0; $i < 8; $i++) {
			$cal_win->addstr($i + 1, 2, 
				$cal_output[$i] . "\n");
		}

		# Highlight today's date, if in the current month and year
		if (((localtime)[4] + 1) == ${ $args{'date_disp'} }[1] &&
			((localtime)[5] + 1900) == ${ $args{'date_disp'} }[2]) {
			$today = (localtime)[3];
			for ($i = 2; $i < 8; $i++) {
				if ($cal_output[$i] =~ /\b$today\b/) {
					$y = $i;
					last;
				}
			}
			for ($i = 0; $i < length($cal_output[$y]); $i++) {
				if (substr($cal_output[$y], $i, length($today)) eq $today) {
					$z = $i;
					last;
				}
			}
			$cal_win->attron(A_BOLD);
			$cal_win->addstr($y + 1, $z + 2, $today);
			$cal_win->attrset(0);
		}
	
		# Draw the current displayed date in reverse video
		for ($i = 2; $i < 8; $i++) {
			if ($cal_output[$i] =~ 
				/${ $args{'date_disp'} }[0]/) {
				$y = $i;
				last;
			}
		}
		for ($i = 0; $i < length($cal_output[$y]); $i++) {
			if (substr($cal_output[$y], $i, length(
				${ $args{'date_disp'} }[0])) eq ${ $args{'date_disp'} }[0]) {
				$z = $i;
				last;
			}
		}
		$cal_win->attron(A_REVERSE);
		$cal_win->addstr($y + 1, $z + 2, ${ $args{'date_disp'} }[0]);
		$cal_win->attrset(0);

		if (! $args{'draw_only'}) {
			select_colour(\$cal_win, $args{'border'}) ||
				$cal_win->attron(A_BOLD);
		} else {
			select_colour(\$cal_win, $args{'border'});
		}
		$cal_win->box(ACS_VLINE, ACS_HLINE);
		$cal_win->attrset(0);
		$cal_win->refresh();
	};

	draw();
	if (! exists $args{'draw_only'}) {
		$cal_win->keypad(1);
		while ($input = grab_key(\$cal_win, $args{'function'})) {
			$z = 0;
			foreach $i (@spec_keys) {
				if ($i eq $input) {
					# Move the displayed date in the desired direction
					set_day($input, $args{'date_disp'}, \@cal_output);
					draw();
					$z = 1;
					last;
				}
			}
			if ($z == 0) {
				return $input;
				last;
			}
		}
	}
	$cal_win->delwin();
}

}
