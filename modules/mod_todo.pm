#あ
#    掲示板モジュール
#                           2007-05-05

package mod_todo;
#use strict;
use data;

sub print_page {
	$user=$mod_login::user;
	%FORM = %main::FORM;
	%cfg = %main::cfg;

	if ($user && $FORM{text}) {
		addtodo($FORM{page},$FORM{text});
	}

	print "Location: $main::top_url/$FORM{page}\n\n";

}

sub addtodo {
	my ($page,$text)=@_;
	my ($sec, $min, $hour, $day, $mon, $year, $wday, $yday, $isdst) = localtime(time);
	$year+=1900;
	$mon++;
	my $date="$year-$mon-$day";

	*IN=data::page_open($page);
	*OUT=data::page_tmp('w');
	while(<IN>) {
		print OUT;
		if (/^\&\s*todo[{<\[\(]/) {
			print OUT "$date,0000-00-00,0,$text\n";
		}
	}
	close(IN);
	close(OUT);

	*IN=data::page_tmp();
	*OUT=data::page_open($page,'w');
	while(<IN>) {
		print OUT;
	}
	close(IN);
	close(OUT);
}

sub start {
#	main::txt2html_flush(); # avoid bug
#	main::txt2html_init();
	$user = $main::user;

	if ($user) {
		print "<form method='POST' action='?todo'>\n";
		print "<input type='hidden' name='module' value='todo'>\n";
	}

	$a=0;
	return "<table>\n"
		."<tr><th>内容</th><th>登録日</th><th>完了日</th><th>状態</th></tr>\n";
}

sub conv {
	my ($rdate,$fdate,$state,$txt)=split(/,/,$_[0],4);
	my $s=('予定','作業中','完了')[$state];
	$a++;

	if ($user) {
		$s="<select name='$a'>";
		my @a=('未','作業中','完了');
		for (0..2) {
			$s.= "<option value='$_'".($state==$_?'selected="selected"':'').">$a[$_]</option>";
		}
		$s.='</select>';
	}

	if ( $state<2 ) {
		$fdate='-';
	}
	return "<tr><td>$txt</td><td>$rdate</td><td>$fdate</td><td>$s</td></tr>\n";
}

sub finish{
#	main::txt2html_flush();
	print "</table>\n";
	if ($user) {
		print "<input class='button' type='submit' value='適用'>";
		print "</form>\n";

		print "<form method='POST' action='-todo'>\n";
		print "<input type='hidden' name='module' value='todo'>\n";
		print "<input type='hidden' name='page' value='$main::page'>\n";
		print "<input type='text' name='text' value='' size=40>\n";
		print "<input class='button' type='submit' value='追加'>\n";
		print "</form>\n";
	}
	return;
}

1;
