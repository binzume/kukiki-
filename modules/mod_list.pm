#
#    ファイル一覧 module
#                           2007-01-16

package mod_list;

$cgi_name = $ENV{'SCRIPT_NAME'};
$prefix=$main::prefix;

%ignore=('./modules'=>1, './styles'=>1);

sub print_html {
	my ($num,$sort,$view) = split/,/,$_[0];
	$curdir=$main::curdir;
	$txtdir = $main::cfg{TEXT_DIR};
	$txtdir =~s/\/$//;
	$txtdir = '.' if !$txtdir;
	$curdir =~s/^\.\.\///;
	@target = ('');
	@list=();
	while(@target) {
		$dir = pop @target;
		$dir =~s/^\///;
		next if $ignore{$dir};
		$d = $txtdir.($dir?'/'.$dir:'');
		opendir(INDIR,$d);
		@files = readdir(INDIR);
		closedir(INDIR);
		for (@files) {
			next if /^\./;
			if (-d $txtdir.'/'.$dir.'/'.$_) {
				push @target,$dir.'/'.$_;
				next;
			}
			next if /^tmp\./;
			#next if /^[\d-]+\./;
			if (/(.*)\.txt$/) {
				$t=$1;
				$dir='.' if !$dir;
				push @list,"$dir/$t";
			}
		}
	}
	if ($sort eq 'name') {
		@list = sort @list;
	} elsif ($sort eq 'time') {
		for (@list) {
			$h{$_}=(stat $txtdir.'/'.$_.'.txt' )[9];
		}
		@list = sort {$h{$b} <=> $h{$a}} @list;
	}
	$n=0;
	print "<div class='recent'>\n";
	for (@list) {
		last if $num && ++$n>$num;
		/([^\/]*)$/;
		$title=$1;
		open(IN,$txtdir.'/'.$_.'.txt');
		$s=<IN>;
		close(IN);
		$title=$1 if $s=~/^\&title:(.*)/;
		$u="$curdir$_";
		$u=~s/\/\//\//g;
		$u=main::get_path($u);
		print "<a href='$u'>$title</a><br>\n";
	}
	print "</div>\n";
}
1;
