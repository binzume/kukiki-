#あ
#    includeモジュール
#                           2007-05-05

package mod_include;
use data;

$mod_name='mod_include';

sub print_html {
	my ($file,$start,$count)=split(/,/,@_[0]);
	if (!$file) {
		print "<strong>$mod_name: ファイル名が指定されていません</strong>\n";
		return;
	}
	my $page = main::get_page_path($file);
	if (! $file || !data::page_exist($page)) {
		print "<strong>$mod_name: ファイル「$file」にアクセスできません</strong>\n";
		return;
	}

	main::txt2html_flush(); # avoid bug
	main::txt2html_init();

	my $b=$main::page_dir;
	if ($page=~/^(.*\/)([^\/]*)$/ || $page=~/^()([^\/]*)$/) {
		$main::page_dir=$1;
	}

	*IN=data::page_open($page);
	my $i;
	for ($i=0;$i<$start;$i++){$_=<IN>;}
	$i=0;
	while(<IN>) {
		last if ($count && $i++ > $count);
		chomp;
		$_=main::txt2html($_)."\n";
		print ;
	}
	close(IN);
	&main::txt2html_flush;
	$main::page_dir=$b;
}

1;
