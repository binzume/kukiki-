#!/usr/local/bin/perl
#      C言語フィルタ
#                       ver 0.82 v2006-11-25
package filter_source;

#%keywords = (
#	'int' => 2,
#);

$key_c = 'void,int,char,float,double,long,short,signed,unsigned,volatile,'
	.'static,auto,for,if,else,do,while,continue,break,return,typedef,enum,struct';
$key_cpp = $key_c.',class,public,private,protected,namespace,using,bool,new,delete';

$key_perl = 'for,foreach,if,else,elsif,do,while,next,last,return,sub,my,qw,local,require,use';
$key_rb = 'class,def,if,else,unless,do,next,begin,end,ensure,new,attr_accessor,return,require,require_relative';
$key_go = 'package,import,var,type,for,if,else,continue,break,return,func,switch,case';
$key_php = 'for,foreach,if,else,elseif,do,while,continue,break,return,catch,try,global,public,private,function,switch,case';


@styles = (
	'color:green', # comment
	'color:#800', # string
	'color:blue;font-weight:bold;',
	'color:blue',
);

sub start
{
	$lang = $_[0]=~/lang=(\w+)/ ? $1:'cpp'; # default : C++
	$comment=0;
	%keywords = {};
	if ($lang eq 'c') {
		$keywords{$_} = 2 foreach (split(/,/,$key_c));
	} elsif ($lang eq 'cpp') {
		$keywords{$_} = 2 foreach (split(/,/,$key_cpp));
	} elsif ($lang eq 'rb') {
		$keywords{$_} = 2 foreach (split(/,/,$key_rb));
	} elsif ($lang eq 'perl') {
		$keywords{$_} = 2 foreach (split(/,/,$key_perl));
	} elsif ($lang eq 'go') {
		$keywords{$_} = 2 foreach (split(/,/,$key_go));
	} elsif ($lang eq 'php') {
		$keywords{$_} = 2 foreach (split(/,/,$key_php));
	}
	return "<pre style='color:black;'>\n";
}

sub finish
{
	return "</pre>\n";
}


sub lang_c
{
	my $a=$_[0];

	if (defined($keywords{$a})) {
		$a = "<span style='$styles[$keywords{$a}]'>$a</span>";
	} elsif ($a =~/^\d/) {
		$a = "<span style='$styles[1]'>$a</span>";
	} elsif ($a eq '/*') {
		$a ="<span style='$styles[0]'>".$a if ($comment==0);
		$comment=1;
	} elsif ($a eq '*/') {
		$a =$a."</span>" if ($comment) ;
		$comment=0;
	} elsif ($a =~/^\"/) {
		$a = "<span style='$styles[1]'>$a</span>";
	} elsif ($a =~/^\/\//) {
		$a = "<span style='$styles[0]'>$a</span>";
	} elsif ($a eq '<') {
		$a='&lt;';
	}
	$a;
}

sub lang_perl
{
	my $a=$_[0];

	if (defined($keywords{$a})) {
		$a = "<span style='$styles[$keywords{$a}]'>$a</span>";
	} elsif ($a =~/^\d/) {
		$a = "<span style='$styles[1]'>$a</span>";
	} elsif ($a =~/^\"/ || $a =~/^\'/) {
		$a = "<span style='$styles[1]'>$a</span>";
	} elsif ($a =~/^\#/ || $a =~/^\/\//) {
		$a = "<span style='$styles[0]'>$a</span>";
	} elsif ($a eq '<') {
		$a='&lt;';
	}
	$a;
}


sub conv
{
	$_ = $_[0];

	s/\t/    /g;
	s/</&lt;/g;
	if ($lang eq 'c' || $lang eq 'cpp') {
		if (/^\s*\#/) {
			return "<span style='$styles[3]'>$_</span>\n";
		} else {
			s/(\w+|\/\*|\*\/|\".+?[^\\]\"|\/\/.*|<)/lang_c($1)/eg;
		}
	} elsif ($lang eq 'perl' || $lang eq 'rb'  || $lang eq 'php' || $lang eq 'go') {
		s/(\d*\.\d\w*|\w+|[\$\@\%].\w*|([\"\'])(?:[^\1\\]|(?:\\.))*?\2|\#.*||\/\/.*|<)/lang_perl($1)/eg;
		#s/(#.*)/<span style='$styles[0]'>\1<\/span>/g; # comment
	}

	$_."\n";
}


1;
