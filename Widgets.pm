package Curses::Widgets;

########################################################################
#
# Curses Widget Module
#
# $Id: Widgets.pm,v 0.8 1999/06/17 23:39:01 corliss Exp corliss $
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

$VERSION = '0.08';

@ISA = qw(Exporter);

@EXPORT		= qw(txt_field buttons init_colours list_box calendar 
				 select_colour);
@EXPORT_OK	= qw(txt_field buttons init_colours list_box calendar
				 line_split);
%EXPORT_TAGS = (
		'Functions' => [ qw(txt_field buttons init_colours list_box
							calendar line_split select_colour) ],
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
	# Provides an bordered text field, with lines, columns, title,
	# initial cursor position, focus shift characters, and border 
	# colour user definable.
	#
	# Usage:  ($key, $content) = txt_field( [name => value] );

	my (%args) = (
		'ypos' 		=> 1,
		'xpos' 		=> 1,
		'lines' 	=> 1,
		'cols'		=> $COLS - 4,
		'pos'		=> 1,
		'content'   => '',
		'border'	=> 'red',
		'regex'		=> '\t',
		'draw_only'	=> 0,
		@_,
	);

	my ($field_win) = ${ $args{'window'} }->derwin($args{'lines'} + 2,
		$args{'cols'} + 2, $args{'ypos'}, $args{'xpos'});
	my ($i, $ch, $k, $input);
	my ($n_lines, $c_line, $s_line, @lines, $curs);

	local *draw = sub {
		$field_win->erase();

		# Get the line count info
		@lines = line_split($args{'content'}, $args{'cols'});
		$n_lines = scalar @lines;
		if (exists $args{'l_limit'} && ($n_lines > $args{'l_limit'})) {
			chop($args{'content'});
			--$n_lines;
			beep();
		}

		# Determince current and starting line via $args{'pos'}
		$c_line = $k = $i = 0;
		while ($i < $n_lines) {
			$k += length($lines[$i]);
			if ($k > $args{'pos'}) {
				$c_line = $i + 1;
				last;
			}
			++$i;
		}
		$c_line = $n_lines if ($c_line == 0);
		++$c_line if (substr($args{'content'}, $args{'pos'} - 2,
			1) eq "\n" && $args{'pos'} > length($args{'content'}));
		++$c_line if (substr($args{'content'}, $args{'pos'} - 1,
			1) eq "\n" && $args{'pos'} == length($args{'content'}));
		--$c_line if (substr($args{'content'}, $args{'pos'} - 1,
			1) eq "\n");
		$s_line = $c_line / $args{'lines'};
		if (int($s_line) == 0) {
			$s_line = 1;
		} elsif (int($s_line) == $s_line) {
			--$s_line;
			$s_line = ($s_line * $args{'lines'}) + 1;
		} else {
			$s_line = int($s_line);
			$s_line = ($s_line * $args{'lines'}) + 1;
		}

		# Find the cursor position on the line
		$k -= length($lines[$c_line]) if 
			(substr($args{'content'}, $args{'pos'} - 1, 1) eq "\n");
		$lines[$c_line - 1] = '' if (! defined $lines[$c_line - 1]);
		$curs = length($lines[$c_line - 1]) - ($k - $args{'pos'});

		# Write text to the window
		for ($i = 0; $i < $args{'lines'}; $i++) {
			if (defined $lines[$s_line + $i - 1]) {
				$field_win->addstr($i + 1, 1, $lines[$s_line + $i - 1] .
					"\n");
			} else {
				$field_win->addstr($i + 1, 1, "\n");
			}
			if (($s_line + $i) == $c_line) {
				if ($args{'pos'} > length($args{'content'}) ||
					substr($args{'content'}, $args{'pos'} - 1, 1) eq
					"\n") {
					$ch = ' ';
				} else {
					$ch = substr($args{'content'}, $args{'pos'} - 1, 1);
				}
				$field_win->standout();
				$field_win->addch($i + 1, $curs, $ch);
				$field_win->standend();
			}
		}

		# Draw the border and title
		if (! $args{'draw_only'}) {
		select_colour(\$field_win, $args{'border'}) || 
			$field_win->attron(A_BOLD);
		} else {
			select_colour(\$field_win, $args{'border'});
		}
		$field_win->box(ACS_VLINE, ACS_HLINE);
		$field_win->attrset(0);
		if (exists $args{'title'}) {
			$args{'title'} = substr($args{'title'}, 0, $args{'cols'})
				if (length($args{'title'}) > $args{'cols'});
			$field_win->standout();
			$field_win->addstr(0, 1, $args{'title'});
			$field_win->standend();
		}

		# Draw the up arrow, if necessary
		$field_win->addch(0, $args{'cols'} - 1, ACS_UARROW) if 
			($s_line > 1);

		# Draw the down arrow, if necessary
		$field_win->addch($args{'lines'} + 1, $args{'cols'} - 1, ACS_DARROW)
			if (($s_line + $args{'lines'} - 1) < $n_lines);

		$field_win->refresh();
	};

	draw();
	if (! $args{'draw_only'}) {
		$field_win->keypad(1);
		while (1) {
			$input = grab_key(\$field_win, $args{'function'});
			if ($input =~ /^[$args{'regex'}]$/) {
				return ($input, $args{'content'});
				last;
			} elsif ($input eq KEY_BACKSPACE) {
				if ($args{'pos'} != 1) {
					substr($args{'content'}, $args{'pos'} - 2, 1) = '';
					--$args{'pos'};
				} else {
					beep();
				}
			} elsif ($input eq KEY_LEFT) {
				if ($args{'pos'} > 1) {
					--$args{'pos'};
				} else {
					beep();
				}
			} elsif ($input eq KEY_RIGHT) {
				if ($args{'pos'} < (length($args{'content'}) + 1)) {
					++$args{'pos'};
				} else {
					beep();
				}
			} elsif ($input eq KEY_UP) {
				if ($c_line != 1) {
					if (length($lines[$c_line - 2]) < $curs) {
						$args{'pos'} -= $curs;
					} else {
						$args{'pos'} -= length($lines[$c_line - 2]);
					}
				} else {
					beep();
				}
			} elsif ($input eq KEY_DOWN) {
				if ($c_line != $n_lines) {
					if (length($lines[$c_line]) >= $curs) {
						$args{'pos'} += length($lines[$c_line - 1]);
					} else {
						$args{'pos'} += (length($lines[$c_line - 1]) - $curs);
						$args{'pos'} += length($lines[$c_line]);
					}
				} else {
					beep();
				}
			} elsif ($input eq KEY_PPAGE) {
				if ($s_line != 1) {
					$i = $c_line - 1 - $args{'lines'};
					$args{'pos'} -= $curs;
					--$c_line;
					while (($c_line - 1) != $i) {
						$args{'pos'} -= length($lines[$c_line - 1]);
						--$c_line;
					}
					if (length($lines[$i]) >= $curs) {
						$args{'pos'} -= (length($lines[$c_line - 1]) -
							$curs);
					}
				} else {
					beep();
				}
			} elsif ($input eq KEY_NPAGE) {
				if (($s_line + $args{'lines'}) <= $n_lines) {
					if (($c_line + $args{'lines'}) > $n_lines) {
						$args{'pos'} = length($args{'content'}) + 1;
					} else {
						$i = $c_line + $args{'lines'};
						if (length($lines[$i - 1]) < $curs) {
							$args{'pos'} += (length($lines[$c_line - 1])
								- $curs);
							$args{'pos'} += length($lines[$i - 1]);
							++$c_line;
						}
						while ($c_line < $i) {
							$args{'pos'} += length($lines[$c_line - 1]);
							++$c_line;
						}
					}
				} else {
					beep();
				}
			} elsif ($input eq KEY_HOME) {
				$args{'pos'} = 1;
			} elsif ($input eq KEY_END) {
				$args{'pos'} = length($args{'content'}) + 1;
			} else {
				if (exists $args{'c_limit'} &&
					length($args{'content'}) == $args{'c_limit'}) {
					beep();
				} else {
					if ($args{'pos'} == 1) {
						$args{'content'} = $input . $args{'content'};
					} elsif ($args{'pos'} > (length($args{'content'}) + 1)) {
						$args{'content'} .= $input;
					} else {
						$args{'content'} = substr($args{'content'}, 0, 
							$args{'pos'} - 1) . $input . substr(
							$args{'content'}, $args{'pos'} - 1);
					}
					++$args{'pos'};
				}
			}
			draw();
		}
	}
	$field_win->delwin();
}

sub buttons {
	# Draws a set of vertical or horizontal buttons.
	#
	# Usage:  ($key, $selected) = buttons( [name => value] );

	my (%args) = (
		'ypos' 			=> 1,
		'xpos'			=> 1,
		@_,
	);
	my ($input, $i, $x, $y, $k);

	local *draw = sub {
		$x = $args{'xpos'};
		$y = $args{'ypos'};
		$i = 0;
		foreach (@{ $args{'buttons'} }) {
			if (exists $args{'vertical'}) {
				$y += 2 if ($i > 0);
			} else {
				($x += (2 + $i)) if ($i > 0);
			}
			${ $args{'window'} }->standout() if ($_ eq
				${ $args{'buttons'} }[$args{'active_button'}]);
			${ $args{'window'} }->addstr($y, $x, $_);
			${ $args{'window'} }->standend() if ($_ eq
				${ $args{'buttons'} }[$args{'active_button'}]);
			$i = length($_);
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
						> 0);
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
	#
	# Usage:  init_colours();

	$colour = has_colors();

	if ($colour) {
		start_color();
		init_pair(1, COLOR_BLUE, COLOR_BLACK);
		init_pair(2, COLOR_CYAN, COLOR_BLACK);
		init_pair(3, COLOR_GREEN, COLOR_BLACK);
		init_pair(4, COLOR_MAGENTA, COLOR_BLACK);
		init_pair(5, COLOR_RED, COLOR_BLACK);
		init_pair(6, COLOR_WHITE, COLOR_BLACK);
		init_pair(7, COLOR_YELLOW, COLOR_BLACK);
	}
}

sub select_colour {
	# Internal and external subroutine.  Used by all widgets.  Selects 
	# the desired colour pair.
	#
	# Usage:  select_colour(\$mwh, 'red');

	if ($colour) {
		if ($_[1] eq 'blue') {
			${ $_[0] }->attrset(COLOR_PAIR(1));
		} elsif ($_[1] eq 'cyan') {
			${ $_[0] }->attrset(COLOR_PAIR(2));
		} elsif ($_[1] eq 'green') {
			${ $_[0] }->attrset(COLOR_PAIR(3));
		} elsif ($_[1] eq 'magenta') {
			${ $_[0] }->attrset(COLOR_PAIR(4));
		} elsif ($_[1] eq 'red') {
			${ $_[0] }->attrset(COLOR_PAIR(5));
		} elsif ($_[1] eq 'white') {
			${ $_[0] }->attrset(COLOR_PAIR(6));
		} elsif ($_[1] eq 'yellow') {
			${ $_[0] }->attrset(COLOR_PAIR(7));
			${ $_[0] }->attron(A_BOLD);
		}
	}

	return $colour;
}

sub list_box {
	# Draws a list box with a border, with the number of lines and 
	# columns user definable, as well as the list, title, 
	# and the border colour.
	#
	# Usage:  ($key, $selected) = list_box( [name => value] );

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

		# Draw the border title
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
		if (exists $args{'title'}) {
			$args{'title'} = substr($args{'title'}, 0, $args{'cols'})
				if (length($args{'title'}) > $args{'cols'});
			$list_win->standout();
			$list_win->addstr(0, 1, $args{'title'});
			$list_win->standend();
		}

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

sub line_split {
	# Internal and external use, but not exported by default.  Returns
	# an array, which is the string broken according to column limits 
	# and whitespace.
	#
	# Usage:  @lines = line_split($string, 80);

	my ($content, $col_lim) = @_;
	my ($len) = length($content);
	my ($ch, $m, @lines, $tmp);

	--$col_lim;
	while ($len > 0) {
		if (substr($content, 0, $col_lim) =~ /\n/o) {
			$tmp = substr($content, 0, $col_lim - 1);
			$tmp =~ /^(.*\n){1}/;
			push (@lines, $1);
			$tmp = length($1);
			substr($content, 0, $tmp) = '';
		} else {
			if ($len < $col_lim) {
				push(@lines, $content);
				$content = '';
			} elsif (length($content) >= ($col_lim + 1) &&
				substr($content, $col_lim, 1) =~ /\s/o) {
				push (@lines, substr($content, 0, $col_lim + 1));
				substr($content, 0, $col_lim + 1) = '';
			} elsif (substr($content, $col_lim - 1, 1) =~ /\s/o) {
				push (@lines, substr($content, 0, $col_lim));
				substr($content, 0, $col_lim) = '';
			} else {
				$m = ($col_lim - 2);
				$ch = substr($content, $m, 1);
				while ($ch !~ /\s/o && $m > 0) {
					--$m;
					$ch = substr($content, $m, 1);
				}
				if ($m > 0) {
					push (@lines, substr($content, 0, $m + 1));
					substr($content, 0, $m + 1) = '';
				} else {
					push (@lines, substr($content, 0, $col_lim + 1));
					substr($content, 0, $col_lim + 1) = '';
				}
			}
		}
		$len = length($content);
	}

	return (@lines);
}

sub grab_key {
	# Internal subroutine only.  Used by any widgets that need some sort
	# of key handling for internal functions.
	#
	# Usage:  $input = grab_key(\$func_ref);

	my ($key) = -1;
	my ($func) = $_[1];

	while ($key eq -1) {
		$key = ${ $_[0] }->getch();
		&$func() if (defined ($_[1]));
	}

	return $key;
}

sub set_day {
	# Internal subroutine only.  Used by the Calendar widget.  Moves the
	# date in the direction provided by the passed argument.
	#
	# Usage:  set_day($key_passed, \@date_disp, \@cal_output);

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
		} elsif ($_[0] eq KEY_HOME) {
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
	# Usage: move_month($month_offset, \@date_disp);

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
	# Usage:  get_cal(\@date_disp, \@cal_output);

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
	# Usage:  calendar( [name => value] );

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
					   KEY_PPAGE, KEY_NPAGE, KEY_HOME);

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
			foreach (@spec_keys) {
				if ($_ eq $input) {
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
