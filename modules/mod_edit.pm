#
#    編集モジュール
#                           2007-05-04

package mod_edit;
use data;

#use strict;
sub new {
	my $class = shift;
	my $self = {};
	return bless $self,$class;
}

# ページを表示
sub print_page
{
	my $context = shift;

	%FORM = %{$context->{form}};
	%PARAMS = %{$context->{params}};
	%cfg = %{$context->{conf}};

	$page = $context->{page};
	$page_dir = $context->{page_dir};
	$prefix = $main::prefix;
	$entry = $main::entry;

	$cfg{TEXT_DIR} = '.'  if $cfg{TEXT_DIR} eq '';
	
	if ($ENV{QUERY_STRING} =~/^edit/) {
		$action_prefix = '?edit';
	} else {
		$action_prefix = '-edit';
	}
	

	# 認証
	if ($context->{user} eq '') {
		mod_login::print_page();
		return;
	}

	#///////////////////////////////////////////////////////////////////
	# ここからは認証済み
	#

	if ($FORM{mode} eq 'newpage'){
		$FORM{name} =~s/\.\.//g;
		$FORM{name} =~s/\/\///g;
		$FORM{name} =~s/^\///;
		print "Location: http://$ENV{SERVER_NAME}$ENV{SCRIPT_NAME}/$FORM{name}$action_prefix\n";
		print "Pragma: no-cache\n";
		print "Cache-Control: no-cache\n";
		print "\n";
		return;
	}

	print "Content-type: text/html\n";
	print "Pragma: no-cache\n";
	print "Cache-Control: no-cache\n";
	print "\n";

	# 記事編集
	if ($FORM{mode} eq 'rename'){
		$FORM{old}=~s/^[\.\/]+//;
		$FORM{name}=~s/^[\.\/]+//;
		my $orgname = $cfg{TEXT_DIR}.'/'.$FORM{old}.'.txt';
		my $newname = $cfg{TEXT_DIR}.'/'.$FORM{name}.'.txt';
		my $orgdir = $cfg{DATA_DIR}.'/'.$FORM{old};
		my $newdir = $cfg{DATA_DIR}.'/'.$FORM{name};
		$f=0;
		if (-f $orgname) {
			$f=rename($orgname,$newname);
			rename($orgdir,$newdir) if $FORM{DIRECTORY}==1 && -d $orgdir;
		}
		if ($f) {
			$data::msgvar{PAGE} = "ページ名変更";
			data::print_msg('HTML_HEADER');
			print "<h1>ページ名を変更しました</h1>\n";
			print "旧：$FORM{old}<br>\n";
			print "新：$FORM{name}<br>\n";
		} else {
			$data::msgvar{PAGE} = "エラー：ページ名変更".$cfg{TEXT_DIR}.'/'.$FORM{old};
			data::print_msg('HTML_HEADER');
			print "<h1>ページ名を変更できませんでした</h1>\n";
		}
		data::print_msg('HTML_FOOTER');
		return;
	} elsif ($context->{params}{mode} eq 'new' || $ARGV[0] eq 'new') {
		$data::msgvar{PAGE} = "ページ新規作成";
		data::print_msg('HTML_HEADER');
		print "<h1>ページ新規作成</h1>\n";
		print "<form METHOD=POST action='". $action_prefix . "'>\n";
		print "<input type='hidden' name='modele' value='mod_edit'>\n";
		print "<input type='hidden' name='mode' value='newpage'>\n";
		print "<div>\n";
		print "ページ名：<input type='text' name='name' size='30' value='${page_dir}NewPage'>\n";
		print "<input class=button type='submit' value='編集'><br />\n";
		print "ページ名を指定して編集ボタンを押してください\n";
		print "</div>\n";
		print "</form>\n";
		data::print_msg('HTML_FOOTER');
		return;
	} elsif ($context->{params}{mode} eq 'rename' || $ARGV[0] eq 'rename') {
		$data::msgvar{PAGE} = "ページ名変更";
		data::print_msg('HTML_HEADER');
		print "<h1>ページ名変更</h1>\n";
		print "<form METHOD=POST ACTION='". $action_prefix . "'>\n";
		print "<input type='hidden' name='modele' value='mod_edit'>\n";
		print "<input type='hidden' name='mode' value='rename'>\n";
		print "<input type='hidden' name='old' value='$page'>\n";
		print "<div>\n";
		print "ページ名：<input type='text' name='name' size='30' value='$page'>\n";
		print "<input type='checkbox' name='DIRECTORY' value='1' checked='checked'>添付ファイルも移動" if -d $cfg{DATA_DIR}.$page;
		print "<input class=button type='submit' value='変更'>\n";
		print "</div>\n";
		print "</form>\n";
		data::print_msg('HTML_FOOTER');
		return;
	}

	if ($FORM{date}=~/^\d+-\d+-\d+$/) {
		$entry=$FORM{date};
	} elsif ($context->{params}{mode} eq 'newentry' || $ARGV[0] eq 'post' || $FORM{date} eq 'post') {
		my ($y,$m,$d)=(localtime())[5,4,3];$y+=1900;$m++;
		$page = $page_dir.sprintf("%04d-%02d", $y,$m);
		$entry=sprintf("%04d-%02d-%02d", $y,$m,$d);
		$mode = 'post';
	} elsif ($entry!~/^\d+-\d+-\d+$/) {
		$page.='/'.$entry if $entry;
		$entry='';
	}


	if ($entry) {
		$data::msgvar{PAGE} = "記事編集";
		data::print_msg('HTML_HEADER');
		print "<H1>記事編集</H1>\n";
	} else {
		$data::msgvar{PAGE} = "ページ編集";
		data::print_msg('HTML_HEADER');
		print "<H1>「$page」を編集</H1>\n";
	}

	$page=~s/\.\.//g;
	if ($FORM{WRITE}) {
		&save();
	}

	$curdir = $main::curdir;
	$curdir =~s/\.\.\///;
	$curdir = './' if !$curdir;
	print "&nbsp;[<a href='$curdir'>トップ</A>]\n";
	print "&nbsp;[<a href='?edit&mode=rename'>ページ名変更</A>]\n";
	print "&nbsp;[<a href='".main::get_path($main::page)."'>戻る</A>]\n";

	if ($FORM{text}) {
		print "<H2>プレビュー</H2>\n";
		print_preview($FORM{text});
		print "<br clear='all'>\n";
	}

	print "<H2>テキスト</H2>\n";
	print "<form method=POST action='". $action_prefix . "'>\n";
	print "<input type=hidden name='modele' value='mod_edit'>\n";
	if ($mode eq 'post' || $FORM{mode} eq 'add') {
		print "<input type=hidden name='mode' value='add'>\n";
		print "Date: <input type='text' name='date' value='$entry'><br>\n";
		print "Title: <input type='text' name='title' value='$FORM{title}' size='50'><br>\n";
		$mode='add';
	} else {
		print "<input type=hidden name='mode' value='post'>\n";
		print "<input type='hidden' name='date' value='$entry'>\n";
	}
	print "<TEXTAREA class=input name=text rows=16 cols=80>\n";
	if ($FORM{text} ne "") {
		$FORM{text}=~s/</\&lt;/g;
		print $FORM{text};
	} else {
		print_data($page,$entry) if $mode ne 'add';
	}
	print "</TEXTAREA>\n";
	print "<div style='width:40em;text-align:right;'>\n";
	print "<input type='checkbox' name='NOUPDATE' value='1'>更新日時を変更しない\n";
	print "<input class=button type=submit name=PREVIEW value=\"プレビュー\">\n";
	print "<input class=button type=submit name=WRITE value=\"投稿\">\n";
	print "</div>\n";
	print "</form>\n";
	print "<p>※空のテキストを投稿すると記事が削除されます</p>\n";

	if (-f 'modules/mod_attach.pm') {
		require 'mod_attach.pm';
		mod_attach::print_html();
	}

	data::print_msg('HTML_FOOTER');
}


#---------------------------------------------------------------------------
#   mod_edit
#

sub print_preview
{
	my @lines = split(/\r?\n/,$_[0]);

	$main::ctag="";
	$main::mode=0;
	$ano=$use_paragraph_a?1:0;

	for (@lines) {
		if (/^\[([^\]]+)\]\s*$/) {
			$ent = $1;
			last if ($entry ne '' && $entry ne $ent);
			$entry=$ent if $ent eq 'INDEX';
			#&main::txt2html_flush;
			&main::entry_tail;
			$main::ent=$ent;
			$ano=$use_paragraph_a?1:0;

			# for diary
			if ($ent=~/(\d\d+)-(\d\d)-(\d\d)/) {
				$cyear=$1; $cmonth=$2; $cday=$3;
				my $aname=$entry eq '' ? $cday : 'A0';
				$_ = "<H2><A name='${aname}' href='$prefix$ent#A0'>$ent ($main::week[main::get_week($1,$2,$3)])</A></H2>\n";
			} else {
				$_="<hr>\n";
			}
		} else {
			$_=main::txt2html($_);
		}

		print;
	}
	#&main::txt2html_flush;
	&main::entry_tail;
}

sub write_entry
{
	my ($page,$entry,$text,$timestamp) = @_;
	my $f=0;
	my $t="";

	print "write [$entry] to page:$page ...<BR>\n";

	$f = 1 if $entry eq '' && data::page_exist($page);

	# copy to temporary
	*OUT = data::page_tmp('w');
	*IN = data::page_open($page);
	while(<IN>){
		if (/^\[([^#\]]+)#+(.*)]\s*$/ && $1 eq $entry) {
			$f = 1;
			$timestamp="#$2" if $FORM{NOUPDATE};
		}
		print OUT;
	}
	close(IN);
	close(OUT);

	# write
	my $tim=data::page_time($page);
	*OUT = data::page_open($page,'w');
	if (! -w OUT) {
		print "ERR(open to write)<BR>\n";
		return;
	}


	print "delete old text<BR>\n" if $f && $FORM{mode} ne 'add';

	*IN = data::page_tmp();

	if ($text && $entry eq '') {
		print OUT $text;
		print OUT "\n";
		$text = '';
	}

	$_='';
	my $ent='';
	while (<IN>) {
		if (/^\[([^\]]+)\]\s*$/) {
			my $oent=$ent;
			$ent = $1;
			$ent=~s/#.*$//;
			if ($oent eq $entry && $FORM{mode} eq 'add') {
				print OUT "*$FORM{title}\n" if $FORM{title};
				print OUT $text;
				print OUT "\n$t";
				$text = '';
			}
			if ($text ne '' && $f==0 && (length($entry) <= length($ent) && $entry gt $ent )) {
				print OUT "[$entry$timestamp]\n";
				print OUT "*$FORM{title}\n" if $FORM{title};
				print OUT $text;
				print OUT "\n$t";
				$text = '';
			}
		}
		if ($text ne '' && $ent eq $entry && $FORM{mode} ne 'add') {
			print OUT "[$entry$timestamp]\n";
			print OUT $text;
			print OUT "\n$t";
			$text = '';
		}
		print OUT if $ent ne $entry || $FORM{mode} eq 'add';
	}

	if ($text ne '') {
		print OUT "[$entry$timestamp]\n" if !$f || $FORM{mode} ne 'add';
		print OUT "*$FORM{title}\n" if $FORM{title};
		print OUT $text;
		print OUT "\n$t";
		$text = '';
	}
	close(IN);
	close(OUT);

	data::page_set_time($page,$tim) if $FORM{NOUPDATE}==1 && $tim;

	if (data::page_size($page)==0) {
		data::page_remove($page);
	}

	print "... OK\n";

	return 1;
}

sub save
{
	my @lines = split(/\r?\n/,$FORM{text});
	my $text = '';
	my $ent = $entry;
	my $d;
	my $timestamp=$cfg{DIARY_MODE}?('#'.time()):'';
	$cfg{TEXT_DIR}.='/' if $cfg{TEXT_DIR}=~/[^\/]$/;

	foreach (@lines) {
		chomp;
		if (/^\&time$/) {
			my ($ss,$mm,$hh,$d,$m,$y,$w)=gmtime();
			$_.= sprintf("(%04d-%02d-%02dT%02d:%02d:%02dZ)",$y+1900,$m+1,$d, $hh,$mm,$ss);
		}
		if (/^\[([^\]]+)\]\s*$/) {
			$d=$1;
			$d=~s/#.*$//;
			if ($cfg{DIARY_MODE} && $ent=~/(\d\d+-\d\d)-\d\d/) {
				$page = $page_dir.$1;
			}
			write_entry($page,$ent,$text,$timestamp) if $text ne '';

			$text="";
			$ent=$d;
			next;
		}
		$text .= "$_\n";
	}

	if ($cfg{DIARY_MODE} && $ent=~/(\d\d+-\d\d)-\d\d/) {
		$page = $page_dir.$1;
	}
	write_entry($page,$ent,$text,$timestamp);
}


sub print_data
{
	my ($page,$entry) = @_;
	my $entryflag = ($entry ne '')?1:0;
	my $f=0;

	*IN = data::page_open($page);
	while (<IN>) {
		if ($entryflag) {
			if (/^\[([^#\]]+).*\]\s*$/) {
				$entryflag=0 if($1 eq $entry);
			}
			next;# if $entryflag;
		}

		if (/^\[([^\]]+)\]\s*$/) {
			$ent = $1;
			$ent=~s/#.*$//;
			last if ($entry ne '' && $entry ne $ent);
			print;
			next;
		}
		$f = 1;
		s/</\&lt;/g;
		print;
	}
	close(IN);

	if (!$f) {
#		print "New entry\n";
	}
}

1;
