#
#    êFÅX
#                           2008-11-23

package misc;
#use strict;
use data;

BEGIN {
	$::module_block{nicovideo} = \&nicovideo_html;
	$::module_block{archive} = \&archive_html;
	$::module_block{navi} = \&navi_html;
	$::module_inline{font} = \&font_html;
	$::module_inline{ruby} = \&ruby_html;
}


# nicovideo
sub nicovideo_html{
	my @prm = split(/\,/,$_[0]);
	::put_html "<div class='nicovideo'>\n";
	::put_html "<iframe width='312' height='176' src='http://ext.nicovideo.jp/thumb/$prm[0]'";
	::put_html " scrolling='no' style='border:solid 1px #CCC;' frameborder='0'>\n";
	::put_html " <a href='http://www.nicovideo.jp/watch/$prm[0]'> nicovideo:$prm[0] </a>\n</iframe>\n";
	::put_html "</div>\n";
}


# Diary archive
sub archive_html
{
	my $prm = $_[0];
	my ($sec,$min,$hour,$cur_d,$cur_m,$cur_y,$wday) = localtime();
	$cur_y+=1900;
	$cur_m++;

	my $oy=0;
	my ($sy,$sm) = split(/-/,$::cfg{DIARY_START});
	$sy=int($sy);
	$sm=int($sm);

	my $y=$cur_y;
	my $m=1;

	my $last_month=0;
	print "<div class='archive'>\n";
	while ($y >= $sy) {
		if (data::page_exist($::page_dir.sprintf("%04d-%02d",$y,$m))) {
			if ($oy!=$y) {
				$oy=$y;
				if ($prm eq 'small') {
					::put_html "\n<h4>$y</h4>\n";
				} else {
					::put_html "<br>\n$y :";
				}
			}
			if ($prm eq 'small' && $last_month<=6 && $m>6) {
				::put_html "<br>\n";
			}
			$last_month=$m;
			::put_html "[<a href='".$::prefix.$::page_dir.sprintf("%04d-%02d' title='%04d-%02d'>%02d</a>]",$y,$m,$y,$m,$m);
		}
		if (++$m>12) {$m=1;$y--;}
	}
	::put_html "</div>\n";
}


sub navi_html
{
	return if ($::page eq 'index');
	my @p = map {$_.'/'} split(/\//,$::page_dir);
	pop @p if $::page_name eq 'index';
	::put_html "<div class='navi'>\n";
	::put_html "<a href='$::cfg{URL}'>$::cfg{SITE_TITLE}</a>\n";
	my $d='';
	for (@p) {
		next if !$_;
		$d.=$_;
		my $t = ::get_title($d);
		my $l = ::get_path($d);
		::put_html "/ <a href='$l'>$t</a>\n" if $t;
	}
	::put_html "/ $cfg{PAGE_TITLE}" if $::cfg{PAGE_TITLE} && $::cfg{PAGE_TITLE} ne 'index';
	::put_html "\n</div>\n";
}

# font(inline)
sub font_html
{
	my $text = $_[0];
	my @prms=split(/,/,$_[1]);
	my $style='';
	for (@prms) {
		if (/^([\d\.]+)(px|mm|cm|em|)$/) {
			my $u=$2 || 'em';
			$style.="font-size:$1$u;";
		}elsif ($_ eq 'italic') {
			$style.="font-style:$_;";
		}elsif ($_ eq 'bold') {
			$style.="font-weight:$_;";
		}elsif (/^\w+$/) {
			$style.="color:$_;";
		}
	}
	"<span style='$style'>".$text.'</span>';
}
sub ruby_html
{
	"<ruby><rb>$_[0]</rb><rp>(</rp><rt>$_[1]</rt><rp>)</rp></ruby>";
}


1;

