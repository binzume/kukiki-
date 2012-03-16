#///////////////////////////////////////////////////////////////////////////
#   data access
#

package data;

$file_conf = 'kukiki.conf';
$tmp_page = 'tmp';


#///////////////////////////////////////////////////////////////////////////
#   Page access
#
sub page_check
{
	my ($page) = @_;
	$page=~s/[^\/]+\/\.\.\//\//g;
	$page=~s/^\///;
	return '' if $page=~/\.\./;
	return '' if $page=~/[<>\|\*\?]/;
	$page;
}

sub page_exist
{
	my ($page) = @_;
	$page = page_check($page);
	return 0 if !$page;
	return -f "$main::cfg{TEXT_DIR}${page}index.txt" if $page=~/\/$/;
	-f "$main::cfg{TEXT_DIR}$page.txt";
}

sub page_size
{
	my ($page) = @_;
	$page = page_check($page);
	return 0 if !$page;
	return -s "$main::cfg{TEXT_DIR}${page}index.txt" if $page=~/\/$/;
	-s "$main::cfg{TEXT_DIR}$page.txt";
}

sub page_time
{
	my ($page) = @_;
	$page = page_check($page);
	return 0 if !$page;
	(stat("$main::cfg{TEXT_DIR}$page.txt"))[9];
}

sub page_set_time
{
	my ($page,$t) = @_;
	$page = page_check($page);
	return 0 if !$page;
	utime ($t,$t,"$main::cfg{TEXT_DIR}$page.txt");
}

sub page_remove
{
	my ($page) = @_;
	$page = page_check($page);
	return 0 if !$page;
	unlink "$main::cfg{TEXT_DIR}$page.txt";
}

sub page_open
{
	local ($page,$mode) = @_;
	local *PAGE;
	$page = page_check($page);
	return 0 if !$page;
	my $file = "$main::cfg{TEXT_DIR}$page.txt";
	if ($mode eq 'w') {
		my $directory=$page;
		$directory=~s/\/[^\/]*$//;
		my $dir='';
		my $um = umask(0);
		for (split /\//,$directory) {
			$dir.='/' if $dir;
			$dir.=$_;
			mkdir($cfg{TEXT_DIR}.$dir,0775) if (!-d $cfg{TEXT_DIR}.$dir);
		}
		umask($um);
		$file =(-f $file)?'+< '.$file:'> '.$file;
		open(PAGE,$file);
		flock(PAGE,2);
		truncate(PAGE, 0);
		seek(PAGE, 0, 0);
	} else {
		open(PAGE,'< '.$file);
	}
	*PAGE;
}

sub page_tmp
{
	local ($mode) = @_;
	page_open($tmp_page,$mode);
}

sub page_tmp_copy
{
	my ($page) = @_;
	$page = page_check($page);
	return 0 if !$page;
	local *TMP;
	my $file = "$main::cfg{TEXT_DIR}$page.txt";

	# copy to tmp.txt
	if (!open(OUT,"> $file_tmp")) {
		return 0;
	}
	open(IN,$file);
	while(<IN>){
		print OUT;
	}
	close(IN);
	close(OUT);

	open(TMP, $file_tmp);
	*TMP;
}

sub close_data
{
	local (*IN) = @_;
	close(IN);
}

sub dir_exist
{
	my ($page) = @_;
	$page = page_check($page);
	return 0 if !$page;
	-d "$main::cfg{TEXT_DIR}$page";
}

#///////////////////////////////////////////////////////////////////////////
#   Config access
#

sub set_dir
{
	my ($directory,$nocheck) = @_;
	if ($nocheck) {
		$file_conf = $directory?($main::cfg{TEXT_DIR} . $directory . '/kukiki.conf'):('kukiki.conf');
		return;
	}
	$file_conf = 'kukiki.conf';
	my $d=$main::cfg{TEXT_DIR};
	for ('',split/\//,$directory) {
		$d.=$_.'/' if $_;
		$file_conf=$d.'kukiki.conf' if -f $d.'kukiki.conf';
		#print "+ " if -f $d."kukiki.conf";
		#print $d."kukiki.conf<br>\n";
	}
}

sub print_msg
{
	my $m = $_[0];
	open(IN,$file_conf) || return;
	while(<IN>){
		if ($_=~/^\[$m\]\s*$/) {
			last;
		}
	}
	while(<IN>){
		last if /^\[.+]\s*$/ ;
		s/\${(.+?)}/defined($msgvar{$1})?$msgvar{$1}:(defined($main::cfg{$1})?$main::cfg{$1}:'${$1}')/eg;
		if (s/(<\w+\s+href=["'])\-/\1$main::prefix$main::page\/-/ig) {
		}elsif (s/(<\w+\s+href=["'])\?/\1\?/ig) {
		}elsif (/<\w.+href=[\"\'][^\.\/].*/i && !/<\w.+href=[\"\']\w+:/i) {
			s/(<\w[^>]+href=[\"\'])/\1$main::curdir/i;
		}elsif (/<\w.+src=[\"\'][^\.\/].*/i && !/<\w.+src=[\"\']\w+:/i) {
			s/(<\w[^>]+src=[\"\'])/\1$main::curdir/i;
		}
		print;
	}
	close(IN);
}

#
#  conf_read(hashref,section)
sub conf_read
{
	my ($cfg,$section) = @_;
	
	open(IN,$file_conf) || return;
	my ($key,$value);
	while(<IN>){
		last if (/^\[([^\]]*)\]\s*$/ && $1 eq $section);
	}
	while(<IN>){
		last if /^\[/;
		chomp;
		($key,$value)=split(/=/,$_,2);
		$$cfg{$key}=$value;
	}
	close(IN);
}

sub conf_read_text
{
	my ($section) = @_;
	my $text;
	
	open(IN,$file_conf) || return;
	my ($key,$value);
	while(<IN>){
		last if (/^\[([^\]]*)\]\s*$/ && $1 eq $section);
	}
	while(<IN>){
		last if /^\[/;
		$text.=$_;
	}
	close(IN);
	return $text;
}

sub conf_write
{
	my ($cfg,$section) = @_;

	# copy to temporary
	open(OUT,"> $main::cfg{TEXT_DIR}$tmp_page.txt");
	return 0 if !-w OUT;
	open(IN,$file_conf);
	while (<IN>) {
		print OUT;
	}
	close(IN);
	close(OUT);

	open(IN,"$main::cfg{TEXT_DIR}$tmp_page.txt");
	open(OUT,"> $file_conf");
	return 0 if !-w OUT;
	my $f=1;
	while (<IN>) {
		if (/^\[(.*)\]/){
			$s=$1;
			if ($f && $s eq $section) {
				print OUT "[$section]\n";
				$_&&print OUT "$_=$$cfg{$_}\n" foreach keys %$cfg;
				$f=0;
			}
		}
		print OUT if $s ne $section;
	}
	close(IN);
	if ($f) {
		print OUT "\n[$section]\n";
		print OUT "$_=$$cfg{$_}\n" foreach keys %$cfg;
	}
	close(OUT);
	1;
}

sub conf_get_key
{
	my ($section,$key) = @_;
	
	open(IN,$file_conf) || return '';
	while(<IN>){
		last if (/^\[$section\]\s*$/);
	}
	my ($k,$v);
	while(<IN>){
		last if /^\[/;
		chomp;
		($k,$v)=split(/=/,$_,2);
		if ($k eq $key) {
			close(IN);
			return $v;
		}
	}
	close(IN);
	return '';
}

sub conf_set_key
{
	my ($section,$key,$value) = @_;

	# copy to temporary
	open(OUT,"> $main::cfg{TEXT_DIR}$tmp_page.txt");
	return 0 if !-w OUT;
	open(IN,$file_conf);
	while (<IN>) {
		print OUT;
	}
	close(IN);
	close(OUT);

	open(IN,"< $main::cfg{TEXT_DIR}$tmp_page.txt");
	open(OUT,"> $file_conf");
	my $s='';
	my $f=1;
	while (<IN>) {
		if (/^\[(.*)\]/){
			if ($f && $s eq $section) { # add data to tail of section
				print OUT "$key=$value\n";
				$f=0;
			}
			$s=$1;
		}
		if ($s eq $section && /^(.*)=/) {
			if ($1 eq $key) {
				$_="$key=$value\n";
				$f=0;
			}
		}
		print OUT;
	}
	close(IN);
	if ($f) {
		if ($s ne $section) {
			print OUT "[$section]\n";
		}
		print OUT "$key=$value\n";
	}
	close(OUT);
}

sub conf_del_key
{
	my ($section,$key) = @_;

	# copy to temporary
	open(OUT,"> $main::cfg{TEXT_DIR}$tmp_page.txt");
	open(IN,$file_conf);
	while (<IN>) {
		print OUT;
	}
	close(IN);
	close(OUT);

	open(IN,"< $main::cfg{TEXT_DIR}$tmp_page.txt");
	open(OUT,"> $file_conf");
	my $s='';
	my $f=0;
	while (<IN>) {
		if (/^\[(.*)\]/){
			$s=$1;
		}
		if ($s eq $section && /^(.*)=/ && $1 eq $key) {
			$f=1;
			next;
		}
		print OUT;
	}
	close(IN);
	close(OUT);
	return $f;
}
1;
