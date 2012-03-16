#!/usr/local/bin/perl
#      GDフィルタ
#                       ver 0.82 v2007-04-08
package filter_gd;
use GD;
use Digest::MD5;

$test_case = "&gd(w=320,h=240)\n{\ncolor red\nciricle 100,100,50\n}\n";
$font_file="/usr/local/share/ipa-ttfonts/fonts/ipagp.ttf";

sub start
{
	$_=$_[0];

	$height = (/h=(\d+)/)?$1:100;
	$width  = (/w=(\d+)/)?$1:100;;
	# 新しいイメージを作成
	$im = new GD::Image($width,$height);
	
	# いくつかの色を確保
	$c{white} = $im->colorAllocate(255,255,255);
	$c{black} = $im->colorAllocate(0,0,0);       
	$c{red}  = $im->colorAllocate(255,0,0);      
	$c{blue} = $im->colorAllocate(0,0,255);
	$color=$c{black};
	$px=0;
	$py=0;
	$font_size=16;

	$ctx = Digest::MD5->new;
	$ctx->add($_);

	'';
}

sub finish
{
	$file="cache/".$ctx->hexdigest.".png";
	if (!-f $file) {
		open(OUT,">$file");
		binmode(OUT);
		print OUT $im->png;
		close(OUT);
	}
	return "<img src='/$file'>\n";
}



sub conv
{
	$_ = $_[0];
	s/\/\/.*$//; # comment
	s/\s\s+/ /g;
	s/^ //g;
	s/ $//g;

	$ctx->add($_);
	if (/^color (.+)/) {
		$color=$c{$1} if (defined $c{$1});
	}elsif (/^pos (\d+),(\d+)/) {
		$px=$1; $py=$2;
	}elsif (/^font size (\d+)/) {
		$font_size=$1;
	}elsif (/^point (\d+),(\d+)/) {
		$im->setPixel($1,$2,$color);
	}elsif (/^line (\d+),(\d+),(\d+),(\d+)/) {
		$im->line($1,$2,$3,$4,$color);
	}elsif (/^rectangle (\d+),(\d+),(\d+),(\d+)/) {
		$im->rectangle($1,$2,$3,$4,$color);
	}elsif (/^rectanglef (\d+),(\d+),(\d+),(\d+)/) {
		$im->filledRectangle($1,$2,$3,$4,$color);
	}elsif (/^circle (\d+),(\d+),(\d+)/) {
		$im->arc($1,$2,$3,$3,0,360,$color);
	}elsif (/^fill (\d+),(\d+)/) {
		$im->fill($1,$2,$color);
	}elsif (/^print (.+)$/) {
		$py+=$font_size;
		$im->stringFT($color,$font_file,$font_size,0,$px,$py,$1);
	}
	'';
}


1;
