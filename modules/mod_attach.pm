#	ファイル添付プラグイン
#                           2007-01-09

package mod_attach;
use data;
use CGI;

$cgi_name = $ENV{'SCRIPT_NAME'};
$prefix=$main::prefix;
$flag_auth = 1;

$BUFSIZE = 2048;
data::conf_read(\%cfg,'CONFIG');
$cfg{DATA_DIR}.='/' if $cfg{DATA_DIR}=~/[^\/]$/;

sub start{
	$q = new CGI;

	# POST優先
	if ($q->param('passwd')) {
		$main::FORM{module}='mod_login';
		$main::FORM{user} = $q->param('user');
		$main::FORM{passwd} = $q->param('passwd');
	}


	require 'mod_login.pm';
	mod_login::start();
	$user=$mod_login::user;

	# 認証が必用
	if ($flag_auth && $user eq '') {
		print "Content-type: text/html\n";
		print "\n";
		print "auth err\n";
		return;
	}

	if ($ENV{REQUEST_METHOD} eq 'GET') {
		$data::msgvar{PAGE} = "ファイルアップロード";
		print "Content-type: text/html\n";
		print "\n";
		data::print_msg('HTML_HEADER');
		print "<h1>添付ファイル</h1>";
		print "[<a href='?'>戻る</a>]<br />";
		print_html();
		data::print_msg('HTML_FOOTER');
		return;
	}

	print "Content-type: text/html\n\n";
	save("filename1");
	save("filename2");
	save("filename3");
	print "<a href='$ENV{HTTP_REFERER}'>戻る</a>\n";
	return 0;
}

sub save(){
	# アップロード実行
	$file = $q->param($_[0]);
	return if !$file;
	
	my $directory=$q->param('directory');
	$directory=~s/[\|\?\*]//g;
	$directory=~s/\.\.//g;
	$directory=~s/^\///g;
	$dir='';
	my $um = umask(0);
	for (split /\//,$directory) {
		$dir.='/' if $dir;
		$dir.=$_;
		mkdir $cfg{DATA_DIR}.$dir,0775 if (!-d $cfg{DATA_DIR}.$dir);
	}
	umask($um);
	my $file2=$file;
	$file2=~s/[\|\?\*]//g;
	$file2=~s/^.*[\/\\]//g;

	$filename = $cfg{DATA_DIR}.$directory.'/'.$file2;
	$filename=~s/\/\//\//g;
	
	print "Uploding $filename...<BR>";
	
	open(OUT, "> $filename") || print "open() FAIL!<br>\n";
	while($l=read($file, $buffer, $BUFSIZE)) {
		print OUT $buffer;
		$file_size+=$l;
	}
	$file_size=int($file_size*10/1024)/10;
	print "$file_size(KB) OK. <br>\n";
}

sub print_html
{
	$main::page=~s/\/$//;
	if ($main::entry) {
		$main::page.='/'.$main::entry;
		$main::entry='';
	}
	if (-f $cfg{DATA_DIR}.$main::page) {
		file_info($main::page);
		return;
	}

	my $post_to = '-attach';
	print "<h2>ファイルアップロード</h2>";
	print "<form method='POST' enctype='multipart/form-data' action='$post_to'>\n";
	print "<input type='hidden' name='module' value='mod_attach'>\n";

	print "FILE1 <input class='input' type='file' name='filename1' size=32><BR>\n";
	print "FILE2 <input class='input' type='file' name='filename2' size=32><BR>\n";

	print "Directory: \n";
	print "<select name='directory'>\n";
	$dir='';
	print "  <option value='$main::page_dir$main::page_name'>$main::page_dir$main::page_name</option>\n";
	print "  <option value='$main::page_dir'>$main::page_dir</option>\n";
	print "  <option value='common'>common</option>\n";
	print "</select>\n";

	print "<input class='button' type='submit' value='upload'>\n";
	print "</form>\n";

	print "<hr>\n";
	file_list();
}


sub file_list
{
	my $dir = '';
	for (split/\//,$main::page) {
		$dir.='/' if $dir;
		last if !-d $cfg{DATA_DIR}.$dir.$_;
		$dir.=$_;
	}
	print "file list $dir<BR>\n";
	$dir=$cfg{DATA_DIR}.$dir;
	opendir(INDIR,$dir);
	my @files = readdir(INDIR);
	closedir(INDIR);
	for (@files) {
		next if /^\./;
		next if -d $dir.'/'.$_;
		print "[<a href='$main::curdir$dir/$_'>$_</a>";
		print "(<a href='$main::prefix$dir/$_/-attach'>info</a>)] \n";
	}
	print "<br>\n";
	for (@files) {
		next if $_ eq '.';
		print "[<a href='$main::prefix$dir/$_/-attach'>$_</a>] \n" if -d $dir.'/'.$_;
	}
}

sub file_info
{
	my $file = $_[0];
	return if $file =~/\.\./;
	return if $file =~/^\//;
	return if $file =~/[<>\|\?\*]/;
	my $size = -s $main::cfg{DATA_DIR}.$file;
	my ($sec,$min,$hour,$d,$m,$y,$wday)
		= localtime((stat("$main::cfg{DATA_DIR}$file"))[9]);
	my $time = sprintf('%04d-%02d-%02dT%02d:%02d:%02d',$y+1900,$m+1,$d, $hour,$min,$sec);

	print "<h2>$file</h2>\n";
	if ($ARGV[0] eq 'remove') {
		unlink $main::cfg{DATA_DIR}.$file;
		print "Removed.\n";
	} else {
		print "<ul>\n";
		print "<li><a href='$main::curdir$main::cfg{DATA_DIR}$file'>$file</a><li>\n";
		print "<li>Size：$size</li>\n";
		print "<li>Time：$time</li>\n";
		print "<li><a href='$main::prefix$file/-attach?remove'>Remove!</a></li>\n";
		print "</ul>\n";
	}
}

1;
