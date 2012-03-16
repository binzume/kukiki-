#
#    find module
#                           2007-01-01

package mod_find;

# Set default config

$cgi_name = $ENV{'SCRIPT_NAME'};
$prefix=$main::prefix;
$file_style = "style.css";
$file_log = "logs/find.log";


sub print_page {
	find_google( $main::FORM{'find_key'});
}


sub print_html {

	if ($main::FORM{module} eq 'mod_find' && $main::FORM{'find_key'}) {
		find($main::FORM{'find_key'});
	} else {
		find('');
		print "<div class='module find'>\n";
		print "\t<h3>検索</h3>";
		print "\t<form method='POST' action='?find'>\n";
print <<END_OF_DATA;
		<input type='hidden' name='module' value='mod_find'>
			<input class='input' type='text' name='find_key' size='20'>
			<input class='button' type='submit' value="検索">
END_OF_DATA
		print "\t</form>\n";
		print "</div>\n";
	}
}

sub find_google{
	my ($key) = @_;
	$key=~s/\s+/ /;
	$key=~s/^\s//;
	$key=~s/\s$//;

	if ($key eq ''){
		print "Content-Type: text/html\n";
		print "\n";
		print "何かいれてね\n";
		return '';
	}

	if (-f $file_log && $ENV{'HTTP_USER_AGENT'}!~/OYSLITS_SUS/) {
		($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst)
			= localtime(time);
		$date = sprintf('%04d-%02d-%02dT%02d:%02d',
			$year+1900, $mon + 1, $mday, $hour, $min);
		open(OUT, ">> $file_log");
		print(OUT "$date $key:$ENV{'HTTP_USER_AGENT'} from $ENV{'REMOTE_HOST'}\n");
		close(OUT);
	}

	if (-f 'keys.txt') {
		open(IN,'keys.txt');
		my ($k,$file,$title);
		my $f=0;
		while(<IN>){
			($k,$file,$title)=split(/,/,$_,3);
			if($k eq $key){
				$f=1;
				last;
			}
		}
		close(IN);

		if($f){
			print "Content-Type: text/html\n";
			print "\n";
			print "登録キーワードにヒットしました．<br />\n";
			print "<a href='$file'>$title</a><br />\n";
		}
	}
	
	$q = $key;
	$q =~ s/([^\w\-\._~ ])/'%'.unpack('H2', $1)/eg;
	$q =~ s/ /+/g;

	print "Location: http://www.google.com/search?q=site:$ENV{SERVER_NAME}+$q&hl=ja&lr=lang_ja\r\n";
	print "\r\n";

	return $key;
}

sub find{
	my ($key) = @_;

	$key=~s/^\s+//;
	$key=~s/\s+$//;

	if ($key eq ''){
		return;
	}

	my $k=$key;
	my $html_title="'$k'を含む記事";

	$k=~s/>/&gt;/g;
	$k=~s/</&lt;/g;

	if (-f "$file_log" && $ENV{'HTTP_USER_AGENT'}!~/OYSLITS_SUS/) {
		open(OUT, ">> $file_log");
		($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst)
			= localtime(time);
		$date = sprintf("%02d/%02d/%02d %02d:%02d",
			$year+1900, $mon + 1, $mday, $hour, $min);
		print(OUT "$date $key:$ENV{'HTTP_USER_AGENT'} from $ENV{'REMOTE_HOST'}\n");
		close(OUT);
	}

	print "<H2>$html_title</H2>\n";

	if (-f "keys.txt") {
		open(IN,"keys.txt");
		$f=0;
		while(<IN>){
			($k,$file,$title)=split(/,/,$_,3);
			if($k eq $key){
				print "<A href=\"$file\">$title</A> -- 登録キーワード<BR>\n";
				$f=1;
			}
		}
		close(IN);

		if($f){
			print "登録キーワードにヒットしました．<BR>\n";
			return;
		}
	}

	$cnt=find_all($key);

}

sub find_all
{
	my ($key)=@_;
	my $c=0;
	my ($sec,$min,$hour,$cur_d,$cur_m,$cur_y,$wday) = localtime();
	$cur_y+=1900;
	$cur_m++;
	my ($st_y,$st_m) = split(/-/,$main::cfg{START});
	my $dir=$main::page_dir;

	$y=$cur_y; $m=$cur_m;
	while ($y*12+$m >= $st_y*12+$st_m) {
		if(-f $main::cfg{TEXT_DIR}.$dir.sprintf("%04d-%02d.txt",$y,$m)){
			$c+=find_file($main::cfg{TEXT_DIR}.$dir.sprintf("%04d-%02d.txt",$y,$m),$key);
			last if $c >100;
		}
		if (--$m<1) {$m=12;$y--;}
	}

	if ($c==0) {
		print "記事が見つかりませんでした．<BR>\n";
	} elsif ($c>100) {
		print "100件を超えています．検索ワードを変更してください．<BR>\n";
	} else {
		print "$c件の記事がヒットしました．<BR>\n";
	}

	return $c;
}

sub find_file
{
	my ($file,$key) = @_;
	my $c=0;
	my @keys;


	open(IN, $file);
	$num=-1;
	while(<IN>){
		chomp $_;
		if($_=~/^\[([\w\-]+)\]/){
			if ($num==0) {
				$c++;
				last if $c >100;
				if ($main::cfg{DIARY_MODE}) {
					print "<A href='$prefix$main::page_dir$ent'>$ent</A><BR>";
				} else {
					print "<A href='$prefix$main::page$ent'>$ent</A><BR>";
				}
			}
			$ent=$1;
			$cday = $1 if $ent=~/\d+-\d\d-(\d\d)/;
			@keys = split(/\s+/,$key);
			$num=@keys;
		}

		for ($i=0;$i<@keys;$i++) {
			last if ($num<=0);
			next if $keys[$i] eq "";
			if (index($_,$keys[$i])>-1) {
				$num--;
				$keys[$i]="";
			}
		}
	}
	close(IN);

	return $c;
}

1;
