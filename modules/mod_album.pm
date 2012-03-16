#
#    アルバムモジュール
#                           2007-12-10

package mod_album;
use data;
use GD;

$directory='album';

$thumb = '_thumb_';
$thumb_w = 160;
$thumb_h = 120;




# 認証が必要(1) 不要(0)
$flag_auth = 1;

sub print_page
{
	$user=$mod_login::user;
	%FORM = %main::FORM;
	%cfg = %main::cfg;

	$prefix = $main::prefix;
	$page = $main::page;
	$page_dir = $main::page_dir;
	$entry = $main::entry;

	$cfg{TEXT_DIR} = '.'  if $cfg{TEXT_DIR} eq '';

	# 認証
	if ($flag_auth && $user eq '') {
		mod_login::print_page();
		return;
	}

	#///////////////////////////////////////////////////////////////////
	# ここからは認証済み
	#

	print "Content-type: text/html\n";
	print "Pragma: no-cache\n";
	print "Cache-Control: no-cache\n";
	print "\n";

	$data::msgvar{TITLE} = "アルバム";
	data::print_msg('HTML_HEADER');

	print_photos('');

	data::print_msg('HTML_FOOTER');
}

sub print_html
{
	my $dir = $_[0];
	my $file = main::get_file_path($_[0]);
	$prefix = $main::prefix;
	if ($dir=~/^\//  || $dir=~/\.\./ ) {
		print "mod_album: ERR\n";
		return;
	}
	if ($file) {
		my $f='',$d='';
		if ($file=~/^(.*)\/([^\/]+)$/) {
			$d=$1;
			$f=$2;
		} else {
			$f=$file;
		}
		my $tf = get_thumb($d,$f);
		print "<a href='$prefix$file'><img src='$prefix$tf'></a>\n";
	} else {
		print_photos($dir);
	}
}

sub print_photos
{
	my $dir=$directory.($_[0]?'/'.$_[0]:'');
	opendir(DIR,$dir);
	my @files=readdir(DIR);
	closedir(DIR);
	for (@files) {
		next if /^[\._]/i;
		next if !/\.jpe?g$/i;
		my $tf = get_thumb($dir,$_);
		print "<a href='$prefix$dir/$_'><img src='$prefix$tf'></a>\n";
	}
}

sub get_thumb
{
	my ($dir,$file)=@_;
	my $tf=$dir.'/'.$thumb.$file;
	return $tf if -f $tf;

	open (IMG, $dir.'/'.$file);
	my $org_image = newFromJpeg GD::Image(\*IMG);
	my ($w,$h) = $org_image->getBounds();
	$tx=0; $ty=0;
	if ($thumb_w * $h/$w > $thumb_h) {
		$tw = $thumb_h * $w/$h;
		$th = $thumb_h;
		$tx = ($thumb_w-$tw)/2;
	} else {
		$tw = $thumb_w;
		$th = $thumb_w * $h/$w;
		$ty = ($thumb_h-$th)/2;
	}
	$thumb_image = new GD::Image($thumb_w, $thumb_h);
	$thumb_image->copyResized($org_image,
		$tx,$ty,
		0,0,
		$tw,$th,
		$w,$h );
	binmode(*thumb_image);
	open(THM,'> '.$tf);
	print THM $thumb_image->jpeg();
	close(THM);
	close(IMG);

	$tf;
}

1;
