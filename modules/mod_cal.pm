package mod_cal;
#use strict;
use data;

	@week = ('Sun','Mon','Tue','Wed','Thu','Fri','Sat');
	$ENV{'TZ'} = "JST-9";
	$cgi_name = $ENV{'SCRIPT_NAME'};
	$cgi_path = "$ENV{'SCRIPT_NAME'}?";
	$cgi_path="" if ($ENV{'PATH_INFO'}=~/^\//);
	$cgi_path.='../' if $main::mode;

	($sec,$min,$hour,$cur_d,$cur_m,$cur_y,$wday) = localtime();
	$cur_y +=  1900;
	$cur_m++;

	data::conf_read(\%cfg,'CALENDER');

	if ($cfg{WEEKSTR} ne "") {
		@week = split(/,/,$cfg{WEEKSTR});
	}



# print_cal(year,month,day)
sub print_html{
	my($year, $month, $day) = @_;
	if ($main::entry_) {
		($year,$month,$day) = split(/-/,$main::entry_);
	} else {
		($year,$month) = split(/-/,$main::page_name);
	}
	$year=$cur_y if $year==0;
	$month=$cur_m if $month==0;

	if (!data::dir_exist($main::page_dir)) {
		return;
	}

	print "<div class='module calendar'>\n";

	$w=get_week(1,$year, $month);
	$yy=$year;
	$mm=$month-1;
	if ($mm<1){
		$yy--;
		$mm=12;
	}
	print "<h3><A href=\"$cgi_path".sprintf('%04d-%02d">%02d',$yy,$mm,$mm)."</A>&lt;&lt;&nbsp;";
	print "<A href='$cgi_path".sprintf('%04d-%02d',$year,$month)."'>$year-$month</A>";
	$mm+=2;
	if ($mm>12){
		$yy++;
		$mm-=12;
	}
	print "&nbsp;&gt;&gt;<a href=\"$cgi_path".sprintf('%04d-%02d">%02d',$yy,$mm,$mm)."</a></h3>";
	print "<table>\n";
	print "<TR>\n";
	foreach (0..6){
		print "<TD>$week[$_]</TD>";
	}
	print "\n";

	print "</TR>\n<TR><TD colspan=$w>" if $w;

	my $f=data::page_exist($main::page) || $main::user;
	foreach (1..&get_days($year, $month)){
		if($w==0){
			print "\n</TR><TR>\n";
		}
		$d=$_;
		if($year==$cur_y && $month==$cur_m && $_ == $cur_d){
			$d= "<span id=today>$d</span>";
		}

		if($_ == $day){
			print "<TD><span id=select>$d</span></TD>";
		} elsif ($f) {
			print "<TD><A href='$cgi_path".sprintf('%04d-%02d-%02d',$year,$month,$_)
				."'>$d</A></TD>";
		} else {
			print "<TD>$d</TD>";
		}
		$w=($w+1)%7;
	}

	print "</table>\n";
	print "</div>\n";
}

sub get_week {
	my($day, $year, $month) = @_;
	if($month < 3){
		$year--;
		$month += 12;
	}
	int ($year + int ($year/4) - int ($year/100) + int ($year/400) + int ((13*$month+8)/5) + $day) % 7;
}

sub get_days{
	my($year, $month) = @_;
	my $days = (31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31) [$month - 1];
	$days += ($month == 2 && (($year % 4 == 0 && $year % 100 != 0) || $year % 400 == 0));
	return $days;
}


1;
