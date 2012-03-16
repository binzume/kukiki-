#
#    トラックバック・コメントモジュール
#                           2007-01-

package mod_tb;
use conf;
use Encode;

$cgi_name = $ENV{'SCRIPT_NAME'};

sub print_html
{
	%FORM = %main::FORM;
	%cfg = %main::cfg;

	if ($ARGV[0]=~/^__mode=(\w*)$/) {
		$mode = $1;
		shift @ARGV;
	}


	my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst)
		= localtime(time);
	$mon++;
	$year+=1900;
	$date = sprintf("%04d-%02d-%02dT%02d:%02d",
		$year, $mon , $mday,  $hour, $min);

	if ($FORM{mode} eq 'comment') {
		$err=write_trackback('C');
		print "Content-Type: text/html\n\n";
		print "<HTML>\n<HEAD>\n";
		if ($ENV{HTTP_REFERER} && $err==0) {
			print "  <TITLE>please wait few time</TITLE>\n";
			print "  <META http-equiv=refresh content='0;URL=$ENV{HTTP_REFERER}'>\n";
		}
		print "</HEAD>\n<BODY>\n";
		print "\n";
		print "OK.\n" if $err==0;
		print "</BODY>\n</HTML>\n";
	} elsif ($FORM{url} =~/^http:/) {
		$FORM{text}=$FORM{excerpt};
		$FORM{name}=$FORM{blog_name};
		if ($FORM{charset} ne '') {
			Encode::from_to( $FORM{title}, $FORM{charset}, $cfg{CODE_SET});
			Encode::from_to( $FORM{name}, $FORM{charset}, $cfg{CODE_SET});
			Encode::from_to( $FORM{text}, $FORM{charset}, $cfg{CODE_SET});
		}
		if (length($FORM{text})>255) {
			$FORM{text}=substr($FORM{text},0,253)."...";
		}
		$err=write_trackback('T');
		print "Content-Type: text/xml\n\n";
		print "<?xml version=\"1.0\" encoding=\"iso-8859-1\"?>";
		print "<response>\n";
		print "<error>$err</error>\n";
		print "</response>\n";
	} else {
		($mode eq 'rss')?print_rss():print_comment();
	}
}

sub print_comment
{

	if ($mode ne 'module') {
		print "Content-Type: text/html\n\n";
		print "<HTML><HEAD><TITLE>trackback</TITLE></HEAD><BODY>\n";
		print "<H2>Trackback : $entry</H2>\n";
	} else {
		print "<A name=tb></A>";
		print "<H2>Comment/Trackback</H2>\n";
	}

	open(TB,$file_tb);
	while (<TB>) {
		chomp;
		last if ($_ eq "-$entry");
	}
	while (<TB>) {
		last if (/^-/);
		next if (/^\s+$/);
		s/</&lt;/g;
		s/>/&gt;/g;
		($date,$name,$title,$url,$text)=split(/\t/,$_,5);
		print "<DIV class=comment>\n";
		if ($date=~s/^C\s*//){
			print "Comment:$date $title  by $name<BR>\n";
			print "URL: <A href='$url'>$url</A><BR>\n" if $url ne '';
		} else {
			$date=~s/^T\s*//;
			print "Trackback: <A href='$url'>$title</A> from $name [$date]<BR>\n";
		}
		$text=~s/\t/<BR>\n/g;
		print $text;
		print "</DIV>\n";
		print "-";
	}
	close(TB);

	print "<HR>\n";

print <<__EOF ;
<DIV class=form>
<FORM method=POST action="$entry/-tb">
タイトル: <INPUT class=input type=text name=title size=40><BR>
投稿者: <INPUT class=input type=text name=name size=40><BR>
URL: <INPUT class=input type=text name=url size=40><BR>

<TEXTAREA class=input name=text rows=4 cols=50></TEXTAREA><BR>

<INPUT type=hidden name=mode value="comment">
<INPUT class=button type=submit name=post value="送信">

</FORM>
</DIV>
__EOF

	print "Trackback URL: http://$ENV{'SERVER_NAME'}$cgi_name/$main::page/$entry/-tb<BR>\n";

	if ($mode ne 'module') {
		print "</BODY></HTML>\n";
	}
}

sub print_rss
{

	my $err=0;
	open(TB,$file_tb) || ($err=1);
	while (<TB>) {
		chomp;
		last if ($_ eq "-$entry");
	}
	print "Content-Type: text/xml\n\n";

print <<__EOF ;
<?xml version="1.0" encoding="iso-8859-1"?>
<response>
<error>$err</error>
<rss version="0.91">
<channel>
__EOF
	print "<title>$entry</title>";
	print "<link>http://$ENV{'SERVER_NAME'}$cgi_name/$main::page/$entry/-tb</link>";

	while (<TB>) {
		last if (!/^-/);
		next if (!/^C/);
		($date,$name,$title,$url,$text)=split(/\t/,$_,5);
		print "<item>\n";
		print "  <title>$title</title>\n";
		print "  <link>$url</link>\n";
		print "<description>$text</description>\n";
		print "</item>\n";

	}
	close(TB);

print <<__EOF ;
</channel>
</rss>
</response>
__EOF

}

sub write_trackback
{
	my $f=0;
	my $data = "$_[0] ".$date."\t";

	$FORM{url}=~s/\s+//g;
	$FORM{title}=~s/\t//g;
	$FORM{title}=~s/\s+$//;
	$FORM{text}=~s/\s+$//;
	$FORM{text}=~s/\t//g;
	$FORM{name}=~s/\t//g;

	$t=$FORM{text};
	$t=~s/\s/\t/g;

	$data.= $FORM{name}."\t".$FORM{title}."\t".$FORM{url}."\t".$t;

	# copy to tmp
	open(TB,$file_tb);
	open(TMP,">tb.tmp") || return 1;
	while (<TB>) {
		print TMP;
		chomp;
		$f=1 if ($_ eq "-$entry");
	}
	close(TMP);
	close(TB);

	# wrire tb file
	open(TMP,"tb.tmp");
	open(TB,"> $file_tb");
	if (!$f) {
		print TB "-$entry\n";
		print TB "$data\n";
	}
	while (<TMP>) {
		print TB;
		chomp;
		if ($_ eq "-$entry") {
			print TB "$data\n";
		}
	}
	close(TMP);
	close(TB);
	return 0;
}

