#あ
#    掲示板モジュール
#                           2007-05-05

package mod_bbs;
#use strict;
use data;

our $MODNAME = 'BBS';
our $NAME = '掲示板モジュール';
our $VERSION = '0.01';
our @CONFIG   = (
	ENABLE_WIKI => 'bool', 'WIKI記法',
	ENABLE_RES  => 'bool',  '返信機能',
	INDEX_COUNT => 'int',  'インデックスの数',
	PASSWD      => 'str',  '投稿パスワード',
);

# Load config
%bbs_conf = (
	ENABLE_WIKI => 1,
	ENABLE_RES => 1,
	INDEX_COUNT => 4,
	PASSWD => '',
#	MAX_MESSAGE => 100,
);
data::conf_read(\%bbs_conf,'BBS');




sub print_html {
	%cfg = %main::cfg;
	my ($file,$num,$skip,$passwd)=split(/,/,@_[0]);
	$data_file=$file;
	$skipline=$skip;
	$passwd=$bbs_conf{PASSWD} if !$passwd;
	if (!$file) {
		print "<strong>Error: データ名が指定されていません</strong>\n";
		return;
	}
	$file = main::get_page_path($file);
	#$file=~s/\/[^\/]+\/\.\./\//g;
	#if ($file=~/^[\.\/]/ || $file=~/[\|\>\<\0]/ ) {
	if (! $file) {
		print "<strong>Error: ファイル「$data_file」にアクセスできません</strong>\n";
		return;
	}

	$target=0;
	if ($bbs_conf{ENABLE_RES} && ($ARGV[0] =~/^(\d+)$/ || $main::FORM{res} =~/^(\d+)$/)) {
		$target = $1;
	}

	# Post a message
	POST: {
		last POST if $main::FORM{module} ne 'mod_bbs';
		$main::FORM{text}=~s/^\s+//;
		$main::FORM{text}=~s/\s+$//;
		$main::FORM{text}=~s/</\&lt;/g;
		last POST if !$main::FORM{text};
		$main::FORM{name}=~s/[\{\[]//g;
		$main::FORM{name}=~s/^\s+//;
		$main::FORM{name}=~s/\s+$//;
		$main::FORM{name}=~s/[\'\"]//g;
		$main::FORM{mail}=~s/^\s+//;
		$main::FORM{mail}=~s/\s+$//;
		$main::FORM{mail}=~s/[\'\"]//g;
		$main::FORM{subject}=~s/^\s+//;
		$main::FORM{subject}=~s/\s+$//;
		$main::FORM{subject}=~s/[\'\"]//g;
		$main::FORM{passwd}=~s/[\'\"]//g;
		if($passwd && $passwd ne $main::FORM{passwd}){
			print "<strong>エラー：パスワードが違います．注意書きを見てください</strong>\n";
			last POST;
		}
		if (!$main::FORM{name}) {
			print "<strong>エラー：名前が入力されていません</strong>\n";
			last POST;
		}
		if (!$main::FORM{res} && !$main::FORM{subject}) {
			print "<strong>エラー：題名が入力されていません</strong>\n";
			last POST;
		}
		if ($main::FORM{mail} && $main::FORM{mail}!~/^\w[^\|\{]*\@\w[^\|\{]*\.[^\|\{]*\w$/) {
			print "<strong>エラー：メールアドレスが不正</strong>\n";
			last POST;
		}
		post($file,$target);
		$main::FORM{text}='';
		$target=0;
	}


	if ($target) {
		print_message($file,0);
		print_form($passwd);
	} else {
		print_form($passwd);
		print_message($file,$num);
	}
}

sub print_form
{
	my $passwd=$_[0];
	my $sbj='';
	$main::FORM{subject} = "Re: $subject" if $target && !$main::FORM{subject};
print <<END_OF_DATA;
		<form method=POST action='$cgi_name$ENV{'PATH_INFO'}'>
		<input type='hidden' name='module' value='mod_bbs'>
		<input type='hidden' name='res' value='$target'>
		<div class="bbs_form">$sbj
			題名：<input type='text' name='subject' size='40' value='$main::FORM{subject}'><br>
			名前：<input type='text' name='name' size='20' value='$main::FORM{name}'> <br />
			<TEXTAREA class=input name=text rows=6 cols=60>$main::FORM{text}</TEXTAREA><br>
END_OF_DATA
			print "<input type='checkbox' name='wiki' value='1'>wiki有効\n" if $bbs_conf{ENABLE_WIKI};
			print " **投稿パスワード：<input type='text' name='passwd' value='$main::FORM{passwd}' size='10' class='input'>**" if $passwd;
print <<END_OF_DATA;
			<input class='button' type='submit' value="投稿">
		</div>
		</form>
END_OF_DATA
}

sub print_message
{
	my ($file,$num)=@_;
	&main::txt2html_flush; # avoid bug
	main::txt2html_init();
	$n=0;
	$id=0;
	my $nest=0;
	$subject=0;

	*IN=data::page_open($file);
	my $i;
	for ($i=0;$i<$skipline;$i++){$_=<IN>;}
	while(<IN>) {
		chomp;
		$nest++ if /^\&.*{$/;
		$nest-- if /^\&}/;
		if ($target && $id<=0) {
			if (/^\/\/ID:(\d+)/ && $1==$target) {
				$id=$1; $nest=0;
			} else {
				next;
			}
		}
		if (/^\/\/ID:\d/) {
			if ($n++ && $id && !$nest || $num && $n>$num) {
				&main::txt2html_flush;
				print main::txt2html("[[全て表示|$data_file]]") if !$target;
				last;
			}
		}
		$subject=$1 if !$subject && /\{\{subject\|(.+?)\}\}/;
		print main::txt2html($_);
	}
	close(IN);
	&main::txt2html_flush;
}

sub post
{
	my ($file,$target)=@_;
	my $id=0;

	@text=split/\n/,$main::FORM{text};
	($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst)
			= localtime(time);
	@week = split(/,/,$cfg{WEEKSTR});
	$date = sprintf("%04d-%02d-%02d(%s) %02d:%02d",
			$year+1900, $mon +1 , $mday, $week[$wday], $hour, $min);

	$from= $main::FORM{name};
	$from = "[[$from|$main::FORM{mail}]]" if $main::FORM{mail};

	my @index;

	*IN=data::page_open($file);
	*OUT=data::page_tmp('w');
	while(<IN>) {
		$id=$1 if /^\/\/ID:(\d+)/ && $id<$1;
		if (/^\/\/BBS_INDEX/) {
			print OUT;
			while(<IN>) {
				last if !/^\-/;
				push @index,$_;
			}
		}
		print OUT;
	}
	close(IN);
	close(OUT);

	$id++;

	unshift @index,"-$date No.$id $main::FORM{subject} from $from\n";
	@index = @index[0..($bbs_conf{INDEX_COUNT}-1)]if @index>=$bbs_conf{INDEX_COUNT};

	*IN=data::page_tmp();
	*OUT=data::page_open($file,'w');


	my $tmp='';
	my $f=0;
	my $d=0;
	while(<IN>) {
		if (/^\/\/BBS_INDEX/) {
			print OUT;
			print OUT for @index;
			next;
		}
		$f=1 if /^\/\/ID:(\d+)/ && $1==$target;
		$f=1 if !$target && /^\/\/ID:\d+/;
		$d-- if $f && /^\&}/;
		$d++ if $f && /^\&.*{$/;
		if ($f && !$d && (!$target || /^\&}/)) {
			$tmp=$_;
			print OUT "//ID:$id\n";
			print OUT "&block(bbs_entry){\n";
			print OUT "**{{msgid|No.$id}} {{subject|$main::FORM{subject}}} 投稿者：{{from|$from}} - $date";
			if ($target) {
				print OUT "\n";
			} else {
				print OUT " ([[返信|:?$id]])\n";
			}
		
			if ($bbs_conf{ENABLE_WIKI} && $main::FORM{wiki}=='1') {
				for(@text){
					s/^\*/ \*/;
					s/^\&/ \&/;
					print OUT "$_\n";
				}
			} else {
				print OUT "&plain{\n";
				for(@text){
					print OUT "\\\\$_\n";
				}
				print OUT "&}\n";
			}
			print OUT "&}\n";
			print OUT "\n";
			$_=$tmp;
			$f=0;$target=-1;
		}
		print OUT;
	}

	close(IN);
	close(OUT);
}

1;
