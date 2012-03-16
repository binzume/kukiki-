#!/usr/bin/perl
#        Kukiki
#                       ver 0.9.3 2008-11-25


BEGIN{
	$dir_modules = './modules';
	unshift @INC,$dir_modules;
	umask(0010);
}

@default_modules = ('misc.pm');

# Set default config
$cfg{STYLE} = 'wiki';
$cfg{TOP_HEADLINE} = 2;
$cfg{PARAGRAPH_LINK} = 0;
$cfg{EDIT_TEXT} = 'Edit';
$cfg{WEEKSTR} = 'Sun,Mon,Tue,Wed,Thu,Fri,Sat';
$cfg{LOGFILE} = 'kukiki.log';
$cfg{RSS_STR} = '${DATE}';

$cgi_name = $ENV{SCRIPT_NAME};
$cgi_path = $ENV{SCRIPT_NAME};
$user='';
$request_url = "http://$ENV{SERVER_NAME}$ENV{'REQUEST_URI'}";
$suffix='.html';

%module_block = ( );
%module_inline = ( );
@filter_inline = ( );

	if ((!$ENV{'PATH_INFO'}) && (!$ARGV[0])) {
		print "Location: $request_url/\n\n";
		exit(0);
	}

	if ($ENV{'PATH_INFO'}=~/^\/(.*)/ || $ARGV[0] eq '') {
		$page = $1;
		@path = split(/\//,$1);
		push @path,'' if $ENV{'PATH_INFO'}=~/\/$/;
		$curdir = '../' x $#path;
		$curdir.= '../' if !$ENV{REDIRECT_URL} && !$ENV{SCRIPT_URL};
		$prefix = '../' x $#path;
		if (substr($ENV{REDIRECT_URL} || $ENV{SCRIPT_URL},-length($ENV{PATH_INFO})) eq $ENV{PATH_INFO}) {
			$cgi_path=substr($ENV{REDIRECT_URL} || $ENV{SCRIPT_URL},0,-length($ENV{PATH_INFO})) || '/';
		}
		$option = $ENV{QUERY_STRING};
	} else {
		$page = $ARGV[0];
		@path = split(/\//,$ARGV[0]);
		push @path,'' if $ENV{'PATH_INFO'}=~/\/$/;
		$curdir = '';
		$prefix = $cgi_path.'?';
		$option = $ENV{QUERY_STRING};
	}
	$top_url = "http://$ENV{SERVER_NAME}$cgi_path";

	$page=~s/[<>\"\%]/_/g;

	if ($page=~s/^-(\w+)$// || $page=~s/\/-(\w+)$//) {
		$mode=$1;
	} elsif ($option =~/^(\w+)($|&)/) {
		$mode=$1;
	}
	if ($page=~s/list\.rdf$//) {
		$mode='rss';
	} elsif ($page=~s/\.rss$//) {
		$mode='rss';
		$page=~s/\/index$/\//
	} elsif ($page=~s/\.atom$//) {
		$mode='atom';
		$page=~s/\/index$/\//
	} else {
		$page=~s/\.php$//;
		$page=~s/\.html?$//;
	}

	#$mode='test';
	# Debug mode
	if ($mode eq 'test' || $ARGV[0] eq 'test') {
		$mode='test';
		open(STDERR, ">&STDOUT");
		$| = 1;
		test();
	}


require('data.pm');
require('context.pm');

	data::conf_read(\%cfg,'CONFIG');
	$cfg{TEXT_DIR}.='/' if $cfg{TEXT_DIR}=~/[^\/]$/;
	$cfg{DATA_DIR}.='/' if $cfg{DATA_DIR}=~/[^\/]$/;

	# $page_dir $page $entry
	$page_dir='';
	$page_name = '';
	$entry='';
	$article='';
	if ($page=~/^(.+):(\w+)$/) {
		$page=$1;
		$article=$2;
	}

	data::set_dir($page);
	data::conf_read(\%cfg,'CONFIG');
	$cfg{TEXT_DIR}.='/' if $cfg{TEXT_DIR}=~/[^\/]$/;
	$cfg{DATA_DIR}.='/' if $cfg{DATA_DIR}=~/[^\/]$/;
	@week = split(/,/,$cfg{WEEKSTR});
	$diary_mode = $cfg{DIARY_MODE};

	if ($page=~/^(.*\/)([^\/]*)$/) {
		$page_dir = $1;
		$page_name = $2;
	}
	$page=get_page_path('/'.$page);
	if ($page=~/^(.+)~(.+)$/) {
		$page=$1;
		$entry=$2;
	}

	if ($mode && !data::page_exist($page)) {
		my $p=get_page_path('/'.$page.'/');
		$page=$p if data::page_exist($p);
	}
	if ($page=~/^(.*\/)([^\/]*)$/ || $page=~/^()([^\/]*)$/) {
		$page_dir = $1;
		$page_name = $2;
	}
	$entry_ = $entry;

	$file_tb = $cfg{TEXT_DIR} . $page.'.tb';
	$title=$cfg{TITLE};
	$cfg{SITE_TITLE}=$cfg{TITLE};
	$cfg{PAGE_TITLE}=$page_name;

	$context = Context->new;
	$context->{page} = $page;
	$context->{page_dir} = $page_dir;
	$context->{page_name} = $page_name;
	$context->{user} = $user;
	%{$context->{conf}} = %cfg;


	if ($mode eq 'test') {
		print "text_dir: '$main::cfg{TEXT_DIR}'\n";
		print "page: '$page' ".(data::page_exist($page)?'OK.':'NG!')."\n";
		print "page_dir: $page_dir\n";
		print "page_name: $page_name\n";
		print "entry: $entry\n";
	}

	# module startup
	require $_ for @default_modules;
	if (-f "modules/mod_$mode.pm") {
		require "mod_$mode.pm" && ($module=1);
		if ($module && defined &{"mod_${mode}::start"}) {
			&{"mod_${mode}::start"}() || exit(0);
		}
	}

	read_var($context);
	if (-f 'modules/mod_login.pm') {
		require 'mod_login.pm';
		mod_login::start($context);
		$user=$mod_login::user;
	}

	if ($module && defined &{"mod_${mode}::print_page"}) {
		&{"mod_${mode}::print_page"}($context);
		exit(0);
	}


	# Send respons header
	if (data::page_exist($page)) {
		$t = data::page_time($page);
		$t = (stat($file_tb))[9] if $t < (stat($file_tb))[9];
		$t = (stat($data::file_conf))[9] if $t < (stat($data::file_conf))[9];
		#print "Last-Modified: ".rfc822_date($t)."\n" if !$cfg{DIARY_MODE};
		# title
		*IN=data::page_open($page);
		if ($article) {
			$ent = ''; $ano=0;
			while (<IN>) {
				chomp;
				if (/^\[([\w\-]+)(#\d*)?]$/) {
					$ent=$1;
					$ano=0;
				}
				if ($ent eq $entry && /^\*([^\*].*)/) {
					$ano++;
#						print "\n\n".$ent . $_;
					if ('A'.$ano eq $article) {
						$cfg{PAGE_TITLE} = $1;
						$cfg{PAGE_TITLE} =~s/^\s*\[.*\]//;
						$title = $cfg{PAGE_TITLE}.' - '.$cfg{SITE_TITLE};
						last;
					}
				}
			}
		} else {
			$_=<IN>;
			if (/^\&title:(.+)$/ || /^\*([^\*].*)$/) {
				$cfg{PAGE_TITLE} = $1;
				$title = $cfg{PAGE_TITLE}.' - '.$cfg{SITE_TITLE};
			} elsif (/^\&redirect:(.+)$/) {
				print "Location: $1\n\n";
				exit(0);
			}
		}
		close(IN);
	} else {
		if ($ENV{HTTP_USER_AGENT}=~/Googlebot/) {
			print "Location: $cfg{URL}\n\n";
			exit(0);
		}
		print "Status: 404 Not Found\n";
	}

	if ($mode eq 'atom') {
		$mode = '';
		if ($ARGV[0] =~/^\w+$/) {
			$mode = $ARGV[0];
		}
		&print_atom($page, $mode);
		exit(0);
	}elsif ($mode eq 'rss') {
		&print_rss($page);
		exit(0);
	}

	#print "X-Application-Dummy: aaaa\n";
	print "Content-Type: text/html\n";
	print "\n";
	$cfg{TITLE} = $title if $title;
	$cfg{PAGE} = $page;
	$cfg{PAGE_DIR} = $page_dir;
	$cfg{PAGE_NAME} = $page_name;
	$cfg{USER} = $user;
	open(HTML, "styles/$cfg{STYLE}.html");
	while (<HTML>) {
		#s/<title>.*<\/title>/<title>$title<\/title>/i if ($title ne '');
		s/\${(\w+)}/$cfg{$1}/g;
		if (/<!--\s+#TEXT\s+-->/) {
			print_html($page,$entry);
		} elsif (/<!--\s+#IF\s+(\w+)\s+-->/) {
			if ($1 eq 'login' && !$user) {
				while (<HTML>) {
					last if /<!--\s+#ENDIF\s+-->/;
				}
			}
		} elsif (/<!--\s+#TEXT:([\w-\/]+)\s+-->/) {
			my $t = $cfg{DIARY_MODE};
			$cfg{DIARY_MODE} = 0;
			print_html(get_page_path($1),'');
			$cfg{DIARY_MODE} = $t;
		} elsif (/<!--\s+#CONFIG:([\w-]+)=(.*)\s+-->/) {
			$cfg{$1}=$2;
		} elsif (/<!-- #PRINT:(\w+)\s+-->/) {
			data::print_msg($1) if $user;
		} elsif (/<!-- #MOD:(\w+)\s+-->/) {
			call_module($1);
		} elsif (/<!-- #\&(.+)\s+-->/) {
			call_module($1);
		} else {
			s/(<\w.+)(src|href)=\"([^\"]+)\"/$1.$2.'="'.url_conv($3).'"'/egx;
			print;
		}
	}
	close(HTML);
	&access_log if -f $cfg{LOGFILE};
exit(0);


#---------------------------------------------------------------------------
#    Sub
#
#//----------------------------------------------- Read variables

sub url_conv{
	my $t=$_[0];
	return $t if $t=~/^\w+:/ || $t=~/^\?/;
	return $page_name.'/'.$t if $t=~/^\-/;
	$curdir.'styles/'.$t;
}

sub rfc822_date
{
	my ($y,$m,$d,$hh,$mm,$ss);
	if (@_==1) {
		($ss,$mm,$hh,$d,$m,$y,$w)=gmtime($_[0]) ;
		$y+=1900;
	} else {
		($y,$m,$d,$hh,$mm,$ss) = @_;
		$w=get_week($y,$m,$d);
		$m--;
	}
	$w=('Sun','Mon','Tue','Wed','Thu','Fri','Sat')[$w];
	$m=('Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec')[$m];

	sprintf('%s, %02d %s %d %02d:%02d:%02d GMT',$w,$d,$m,$y, $hh,$mm,$ss);
}

sub get_week {
	my($day, $year, $month) = @_;
	if($month < 3){
		$year--;
		$month += 12;
	}
	int ($year + int($year/4) - int($year/100) + int($year/400) + int((13*$month+8)/5) + $day) % 7;
}

sub read_var {
	my $context = shift;
	my @pairs;
	my $form;
	@pairs = split(/&/,$ENV{QUERY_STRING});
	foreach $pair (@pairs) {
		my ($name, $value) = split(/=/, $pair);
		$value =~ tr/+/ /;
		$value =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
		$context->{params}{$name} = $value;
	}


	if ($ENV{REQUEST_METHOD} eq 'POST') {
		read(STDIN, $form, $ENV{'CONTENT_LENGTH'});
		@pairs = split(/&/,$form);
		foreach $pair (@pairs) {
			my ($name, $value) = split(/=/, $pair);
			$value =~ tr/+/ /;
			$value =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
			$context->{form}{$name} = $value;
		}
		%FORM = %{$context->{form}};
	}
}

sub get_week {
	my($day, $year, $month) = @_;

	if($month < 3){
		$year--;
		$month += 12;
	}
	int ($year + int ($year/4) - int ($year/100) + int ($year/400) + int ((13*$month+8)/5) + $day) % 7;
}

sub call_module
{
	my $cmd=$_[0];
	my $prm;
	if ($cmd=~/^(\w+)\((.*)\)$/) {
		$cmd=$1;
		$prm=$1;
	}
	return if $cmd!~/^\w+$/;

	if (-f "modules/mod_$cmd.pm") {
		require "mod_$cmd.pm";
		&{"mod_${cmd}::print_html"}($prm);
	}elsif (-f "modules/$cmd.pm") {
		require "$cmd.pm";
		&{"${cmd}::print_html"}($yy,$mm,$dd);
	} elsif (defined $module_block{$cmd}) {
		$module_block{$cmd}->($prm);
	}
}

#---------------------------------------------------------------------------
#    Wiki_modoki to HTML
#
sub print_html
{
	local ($page,$entry) = @_;
	my $entryflag = ($entry ne '')?1:0;
	my $f=0;

	# comment count
	$use_paragraph_a = $cfg{PARAGRAPH_LINK};
	$comment_flag=0;
	if ($diary_mode) {
		$comment_flag=1;
		%comment_cnt={};
		open(IN,$file_tb);
		while (<IN>) {
			$comment_cnt{$ent}++ if /^[CT]/;
			if (s/^-//) {
				chomp;
				$ent = $_;
				$comment_cnt{$ent} = 0;
			}
		}
		close(IN);
	}

	*IN=data::page_open($page);

	txt2html_init();
	local $tagmode=0;
	$ano=$use_paragraph_a?1:0;
	while (<IN>) {
		if ($entryflag) {
			if (/^\[([^\]#]+).*\]\s*$/) {
				if($1 eq $entry){
					$entryflag=0;
				}
			}
			next if $entryflag;
		}
		if (/^\[([^\[\]#]+).*\]\s*$/) {
			my $t=$1;
			$t=~s/#.*$//;
			entry_tail() if $ent || $f;
			last if ($entry ne '' && $entry ne $t);
			$ent = $t;
			$entry=$ent if $ent eq 'INDEX';
			$ano=$use_paragraph_a?1:0;

			print "<div class='entry'>\n" if $ent;
			# for diary
			if ($cfg{DIARY_MODE} && $ent=~/(\d\d+)-(\d\d)-(\d\d)/) {
				$cyear=$1; $cmonth=$2; $cday=$3;
				my $ahref="$page_dir$1-$2#$3";  # "$ent#A0";
				my $aname=$entry eq '' ? $cday : 'A0';
				$_ = "<h2><a name=\"${aname}\" href=\"$prefix$ahref\">$ent ($week[&get_week($1,$2,$3)])</a>";
				$_.= "[<a href='$prefix$page_dir$ent?edit'>$cfg{EDIT_TEXT}</a>]" if $user;
#				$_.= "[<a href='$cgi_name/$page_dir$ent?edit'>$cfg{EDIT_TEXT}</a>]" if $user;
				$_.= "</h2>\n";
			} else {
				$_="<hr>\n";
			}
		}else {
			$_=txt2html($_);
			$_='' if $article && $ano>0 && $article ne 'A'.($ano-1);
		}
		$f=1 if /[^\s]/;
		print;
	}
	close(IN);

	if ($f) {
		entry_tail();
	} else {
		data::print_msg('ARTICLE_NOTFOUND');
		if (!$cfg{DIARY_MODE} || $entry) {
			my $t = "$page_name";
			$t.="~$entry" if $entry;
			$t = $entry if $cfg{DIARY_MODE};
			print "[<a href='$t?edit'>$cfg{EDIT_TEXT}</a>]" if $user;
		}
	}

	if ($diary_mode &&  -x "mod_tb.pl" && -w $file_tb && $entry ne '') {
		open(CMD,"./mod_tb.pl __mode=module '$ARGV[0]' |");
		print while(<CMD>);
		close(CMD);
	}
	$f;
}


sub entry_tail{
	&txt2html_flush;
	if (@note) {
		my $i=1;
		print "<hr>\n";
		print "<ul class='note'>\n";
		for (@note){
			print "<li><a name='note_${ent}_$i'>*$i</a> : $_</li>\n"; $i++;
		}
		print "</ul>\n";
		@note=();
		$note_count=0;
	}
	if ($cfg{DIARY_MODE} || $cfg{EDIT_TEXT} && $user) {
		print "<div class=right><small>";
		print "[<a href='$prefix$ent#tb'>Comment/Trackback(".(0+$comment_cnt{$ent}).")</a>]" if $comment_flag && -x 'mod_tb.pl';
		#if (!$cfg{DIARY_MODE} && !$ent && $user) {
		if (!$ent && $user) {
			$ent='/'.$ent if $ent;
			print "[<a href='$prefix$page${ent}?edit'>$cfg{EDIT_TEXT}</a>]";
			#print "[<a href='$cgi_name/$page/${ent}?edit'>$cfg{EDIT_TEXT}</a>]";
		}
		print "</small></div>\n";
		print "</div>\n" if $ent;
	}
	$ent='';
}

sub get_week
{
	my($year,$month,$day) = @_;
	if($month < 3){
		$year--;
		$month += 12;
	}
	($year + int($year/4) - int($year/100) + int($year/400) + int((13*$month+8)/5) + $day) % 7;
}

sub txt2html_init
{
	$note_count = 0;
	$ent="";
	$ctag="";
	%localconf=();
}

sub txt2html_flush
{
	print "$ctag\n" if $ctag ne "";
	print pop(@tag_stack),"\n" while(@tag_stack);
	print "$ctagl\n" if $ctagl ne "";
	$tagmode='';
	$ctag='';
	$ctagl='';
	@list_nest=();
}

sub put_html
{
	print @_;
}

sub txt2html
{
	$_ = $_[0];
	chomp;

	# module block (&module{～&})
	#if (s/^&([\]\)\}])//) { # end block
	if (@modterm && $_ eq $modterm[$#modterm]) { # end block
		$#modterm--;
		my $t = $ctag?$ctag."\n":'';
		$ctag='';
		$t.="$ctagl\n" if $ctagl ne "";
		$ctagl='';
		$_=pop(@tag_stack);
		$tagmode='';
		return $t.&{"${_}::finish"}() if defined &{"${_}::finish"};
		return  $t.$_."\n";
	} elsif (/^&\s*(\w+)/ && defined $module_inline{$1}) { # inline
	} elsif (s/^&\s*(\w+)// && !defined $module_inline{$1}) { # block
		# &module:class(data)
		my $tag = $1;
		my $prm = '';
		my $text = '';
		my $name = '';
		my $attr = '';
		my $multiline=0;

		if (s/([\(\{\[<]+)$//) {
			$multiline = 1;
			my $cl=reverse $1;
			$cl=~tr/\(\{\[</\)\}\]>/;
			$cl='&'.$cl if length($cl)<2;
			push(@modterm,$cl);
		}
		$prm = $1 if (s/^\(([^\)]*)\)//);
		$text=$1 if /^:(.*)/ || /^\[(.*)\]/ || /^\{(.*)\}/;

		$_ = $ctag?$ctag."\n":'';
		$ctag='';

		if (-f "modules/filter_$tag.pm") {
			$name = "filter_$tag";
			require "modules/$name.pm";
			my $s= &{"${name}::start"}($prm);
			return $s."\n".&{"${name}::conv"}($text)
				."\n".&{"${name}::finish"}() if !$multiline;
			push(@tag_stack,$name);
			return $s;
		} elsif (-f "modules/mod_$tag.pm") {
			$name = "mod_$tag";
			require "modules/$name.pm";
			if ( $multiline && defined &{"${name}::start"}) {
				push(@tag_stack,$name);
				return &{"${name}::start"}($prm);
			}
			my $s=&{"${name}::print_html"}($prm);
			return '';
		} elsif (defined $module_block{$tag}) {
			$module_block{$tag}->($prm);
			return '';
		}

		$attr.= " class='$prm'" if $prm ne '';
		if ($tag eq 'CENTER') {
			$name = 'div';
			$attr.= ' align="center"';
			#$attr.= ' style="text-align:center;"';
		} elsif ($tag eq 'RIGHT') {
			$name = 'div';
			$attr.= ' align="right"';
			#$attr.= ' style="text-align:center;"';
		} elsif ($tag eq 'html') {
			$tagmode=$tag;
		} elsif ($tag eq 'block') {
			$name = 'div';
		} elsif ($tag eq 'quote') {
			$name = 'blockquote';
		} elsif ($tag eq 'plain') {
			$name = 'pre';
			$tagmode='plain';
		} elsif ($tag eq 'title') {
			return $_;
		} elsif ($tag eq 'set') { # setting
			$localconf{$1}=$2 if($text=~/(\w+)\s*=\s*(.+)/);
			return $_;
		} else {
			return "$_$text" if !$multiline;
			push(@tag_stack,"($name)");
			return "$_($name$attr)";
		}

		if ($name) {
			return "$_<$name$attr>" . inline_conv($text) . "</$name>\n" if !$multiline;

			# multi line
			push(@tag_stack,"</$name>");
			return "$_<$name$attr>\n";
		}
		if ($multiline) {
			push(@tag_stack,'');
			return $_;
		}
		return "$_$text\n";
	}

	my $no_tag=s/^\\\\//;

	return $_."\n" if $tagmode eq 'html';
	return &{"$tag_stack[$#tag_stack]::conv"}($_) if defined &{"$tag_stack[$#tag_stack]::conv"};

	s/&/&amp;/g;
	s/</&lt;/g;
	s/>/&gt;/g;
	s/"/&quot;/g;
	s/(\w)\@(\w)/\1&#64;\2/g;

	if ($tagmode eq 'plain'){
		s/^([^\"\']*)(https?:\/\/\w[\w\.\/\?\=~\%-]+)/\1<a href=\"\2\">\2<\/a>/gi; # URL
		return $_."\n";
	}

	my $endblock=0;
	my $tag='';
	my @tmp=();
	s/{{(\\+)(.*?)\1}}/(push@tmp,$2),'<\\>'/egx if !$no_tag;

	if ($no_tag) {
	} elsif ($_ eq '') {
		$endblock=1;
	} elsif (/^----+$/) { # HR
		$endblock=1;
		$_ = "<hr>";
	} elsif (/^([\-\+]+)(.+)/) { # LIST
		$endblock=1;
		$_=$2;

		my $t='',$i;
		my @list_nest2 = @list_nest;
		@list_nest = split(//,$1);
		for ($i=0;$i<@list_nest;$i++) {
			last if $list_nest2[0] ne $list_nest[$i];
			shift @list_nest2;
		}
		$t.= ($_ eq '-')?"</li></ul>":"</li></ol>" foreach reverse(@list_nest2);
		if ($i<@list_nest) {
			for (;$i<@list_nest;$i++) {
				$t.=($list_nest[$i] eq '-')?"<ul>":"<ol>";
			}
		} else {
			$t.="\t</li>";
		}
		$t.="\n" if $t ne '';
		$_ = "$t\t<li>\n\t\t$_";

		$ctagl='';
		$ctagl.= ($_ eq '-')?"\t</li>\n</ul>":"\t</li>\n</ol>" foreach reverse(@list_nest);
	} elsif (/^(\|)(.*)\|$/ || /^(,)(.*)/) { # table
		$_='';
		if ($ctag ne '</table>') {
			$endblock=1;
			$_="<table>\n";
		}
		my $t = "";
		for(split(/\Q$1/,$2)) {
			my $tt=(s/^\*//)?'th':'td';
			$t.="<$tt";
			$t.= /^\s.*\s$/&&' style="text-align:center">'
				|| /^\s/&&' style="text-align:right">'
				|| /\s$/&&' style="text-align:left">'
				|| ">";
			$t.= "$_</$tt>";
		}
		$_.="<tr>$t</tr>";
		$tag='</table>';
	} elsif (/^\&gt;(.*)/) { # blockquote
		$_='';
		if ($ctag ne '</blockquote>') {
			$endblock=1;
			$_="<blockquote>\n";
		}
		$_.= "$1<br>";
		$tag='</blockquote>';
	} elsif (/^(\*+)(.+)/) { # H[1-6]
		$endblock=1;
		$n=length($1)+$cfg{TOP_HEADLINE};
		if ($ano && length($1)==1) {
			my $aname=$entry eq '' ? $cday : '';
			$_ = "<h$n><a name='${aname}A$ano' href='$prefix$page_dir$ent:A$ano'>*</a>$2</h$n>\n";
			#$_.='<div class="fb"><iframe src="http://www.facebook.com/plugins/like.php?href=http%3A%2F%2Fwww.binzume.net%2Fdiary%2F'.$ent.'%3AA'.$ano.'&amp;layout=standard&amp;show_faces=false&amp;width=450&amp;action=like&amp;font&amp;colorscheme=light&amp;height=35" scrolling="no" frameborder="0" style="border:none; overflow:hidden; width:450px; height:35px;" allowTransparency="true"></iframe></div>';
			$ano++;
		} else {
			$_ = "<h$n>$2</h$n>";
		}
		$tag='';
	} elsif (s/^\/\/\!//) {
		return '';
	} elsif (s/^\/\/\s*//) {
		$_ = "<!-- $_ -->\n" if $_;
		return $_;
	}

	if ($localconf{p} ne 'off' && !$endblock && !$tagmode
	  && (!$no_tag && s/^~([^~])/\1/ || $_ && $ctag eq '' && $ctagl eq '')) {
		$endblock=1;
		$_ = "<p>\n".$_;
		$tag='</p>';
	}

	if ($endblock) {
		$_= "$ctag\n".$_ if $ctag;
		$ctag=$tag;
	}
	if ($_ eq '') {
		$_.= "$ctagl\n" if $ctagl;
		$ctagl='';
		@list_nest=();
		return $_."\n";
	}

	return $_."\n" if $no_tag;

	s/~~$/<div style='clear:both'><\/div>/;
	s/~$/<br>/;

	# inline
	inline_conv($_);
	s/<\\>/shift@tmp/eg;
	return $_;
}

sub inline_conv {
	$_ = $_[0];
	# inline
	if(@filter_inline){my $t=$_;for(@filter_inline) {$t=$_->($t);}$_=$t;}
	s/==(.+?)==/<del>\1<\/del>/g;
	s/'''(.+?)'''/<i>\1<\/i>/g;
	s/''(.+?)''/<strong>\1<\/strong>/g;
	s/__(.+?)__/<u>\1<\/u>/g;
	s/\[\[([^\[].*?)\]\]/&wiki_link($1)/eg;
	s/\[\[([^\[].*?)\]\]/&wiki_link($1)/eg;
	s/^([^\"\']*)(https?:\/\/\w[\w\.\/\?\=~\%#-]+)/\1<a href=\"\2\">\2<\/a>/gi; # URL
	s/{{([^\|]+)\|(.+?)}}/inline_element($1,$2)/eg;
	s/{{br}}/<br>/gi;
	s/{{(NAME:.+?)}}/inline_element($1,'*')/egi;
	s/{{NOTE:(.+)?}}/(push@note,$1),"<a class='note_link' href='#note_${ent}_".(0+@note)."'>*".(0+@note)."<\/a>"/gei;
	s/&amp;(\w+)\(([^\)]+)\){(.*?)};/(defined $module_inline{$1})?$module_inline{$1}->($3,$2):$&;/egi;

	$_."\n";
}

sub inline_element {
	my ($style,$text)=@_;
	my @styles=split(/,/,$style);
	my @cl=();
	my $a='';

	for (@styles){
		if (/COLOR:([\w\d\#]+)$/i) {
			$a.="<span style='color:$1'>";
			push @cl,'</span>';
		} elsif(/SIZE:([\d\.]+)$/i) {
			$a.="<span style='font-size:$1em'>";
			push @cl,'</span>';
		} elsif(/NAME:([\w\d]+)$/i) {
			$a.="<a name='$1'>";
			push @cl,'</a>';
		} elsif(/^([ubi]|kbd)$/i) {
			$a.=lc "<$1>";
			push @cl,lc "</$1>";
		} elsif($_ eq '^') {
			$a.='<sup>';
			push @cl,'</sup>';
		} elsif($_ eq '_') {
			$a.= '<sub>';
			push @cl,'</sub>';
		} elsif(/(\w+)/i) {
			$a.="<span class='$1'>";
			push @cl,'</span>';
		} elsif(/style:(.+)/i) {
			$a.="<span style='$1'>";
			push @cl,'</span>';
		}
	}
	$a.=$text;
	$a.=$_ for reverse @cl;
	$a;
}

sub wiki_link
{
	my ($link) = @_;
	my $opt='';
	local $text;
	$link =~s/^([^\|]+)\|/$text=$1;''/e; #[[text|URL]]
	$link =~s/\s+(.+)/$text=$1;''/e; #[[URL text]]
	$text.=wiki_link($1) if ($link =~s/,t:([^\s,]+)$//i);
	$opt=" class='$1'" if ($link =~s/,(\w+)$//);
	$text = $link if !$text;
	#$link =~s/&/&amp;/;
	return "<a href=\"$page/$1\"$opt>$text<\/a>" if $link =~/^:([\w-]*)$/;
	return "<a href=\"$1\"$opt>$text<\/a>" if $link =~/^(\w+:\/\/.+)$/;
	return "<a href=\"$1\"$opt>$text<\/a>" if $link =~/^(mailto:.+)$/;
	return "<a href=\"http://twitter.com/$1\"$opt>$1<\/a>" if $link =~/^t:(.+)$/;
	return "<a href=\"mailto:$link\">$text<\/a>" if $link =~/^[^\/\|\<\>]+(\@|\&#64;)[^\/\|\<\>]+$/;
	if ($diary_mode) {
		return "<a href=\"$prefix$page_dir$1$2#$3\">$text<\/a>" if $link =~/^(\d+-\d+-)(\d+)(A\d+)?$/;
	}

	# 拡張子付き
	if ($link =~/^:(.+)$/ || $link =~/^([^\-\.][^\.]*)$/) {
		my $l=$1;
#		return "<a href=\"".get_path(get_page_path($l))."\">$text<\/a>"
		return "<a href=\"".get_path($l)."\"$opt>$text<\/a>"
			if $l=~/^[#\?\/]/ || $link=~/^:/;
		return "<a href=\"".get_path("$prefix$page/$1")."\"$opt>$text<\/a>"
			if data::page_exist($page.'/'.$1);
		if ($cfg{DIARY_MODE} && conv_time($link,$cyear,$cmonth,$cday)) {
			return "<a href=\"$prefix$page_dir".sprintf("%04d-%02d#%02d",$yy,$mm,$dd)."\">$text<\/a>";
		}
		my $l2=get_page_path($l);
		$l2=~s/\/index$/\//;
		return "<a href=\"".get_path($l2)."\"$opt>$text<\/a>" if $l2;
		return "<strong>$text(Page Not found:$l)<\/strong>" if $link =~/^:/;
	}
	if ($link =~/^(!?)([^\.\/][\w\-\/]*\.[\w\.]+)$/ ) {
		my $f = get_file_path($2);
		return "<strong>$text(Data Not found:$2)<\/strong>" if !$f;
		return "<img src=\"$curdir$f\" ALT=\"$text\"$opt>" if  $1 eq '' && $f=~/\.(gif|png|jpg)$/i;
		return "<a href=\"$curdir$f\">$text<\/a>";
	}
	if ($link =~/^([\w\-\/]*\.[\w\.]+)$/ ) {
		my $f = get_file_path($1);
		return "<a href=\"$curdir$f\"$opt>$text<\/a>" if $f;
	}

	return "<a href=\"$curdir$1\"$opt>$text<\/a>" if $link =~/^([^\]\|:]+\.\w+)$/;
	return "<strong>$text(Not found:$link)<\/strong>";
}

# For diary
sub conv_time
{
	($s,$yy,$mm,$dd)=@_;
	if (!defined($WORD_CNT)) {
		open(KEY ,'styles/diaryword.txt');
		$WORD_CNT = 0;
		while (<KEY>) {
			next if /^#/;
			chomp;
			if (/^(.*):(.*)$/) {
				$WORD{$1} = $2;
				$WORD_CNT++;
			}
		}
		close(KEY);
	}
	return if $WORD_CNT<=0;

	my @month_d=(31,31,29,31,30,31,30,31,31,30,31,30,31);
	my %V=('tY'=>'yy' , 'tM'=>'mm' , 'tD'=>'dd' , 'tW'=>'wd');

	my $i=0;
	my $count=0;
	while ($s ne "") {
		# sentens:16words word:20byte
		last if $i++>16;
		if ($s=~/^(\d+)/) {
			$num=$1;
			$s=~s/^\d+/{#}/;
		}

		$n=0;
		$len=0;
		while(++$n<20 && $n<=length($s)) {
			$len=$n if exists $WORD{substr($s,0,$n)};
		}
		if($len>0) {
			$count++;
			$t=substr($s,0,$len);
			if($WORD{$t}=~/^(\w+)([\-\+\=])(.*)$/){
				$v=$1;
				$e=$2;
				$o=$3;
				$o=$num if ($o eq "%1");
				if(exists $V{$v}) {
					#print "C:$v $e $o\n";
					${$V{$v}} = 0+$o if $e eq '=';
					${$V{$v}}+= 0+$o if $e eq '+';
					${$V{$v}}-= 0+$o if $e eq '-';
					if($v eq 'tW') {
						# week day
						$ty = $yy;
						$tm = $mm;
						if ($mm < 3){
							$ty--;
							$tm += 12;
						}
						$wd= ($ty + int($ty/4) - int($ty/100) + int($ty/400) +  (13*$tm+8)/5 +$dd) % 7;
						$v="tD";
						$dd+=$o-$wd+1;
					}
					if($V{$v} eq 'dd') {
						while($dd<1){
							$dd+=$month_d[$mm-1];
							$mm--;
							if($mm<1) {$mm=12; $yy--;}
						}
						while($dd>$month_d[$mm]){
							$dd-=$month_d[$mm];
							$mm++;
							if($mm>12) {$mm=1; $yy++;}
						}
					}
					if($V{$v} eq 'mm') {
						if ($mm>12){
							$yy+=int(($mm-1)/12);
							$mm-=int(($mm-1)/12)*12;
						}
						if ($mm<1){
							$yy+=int(($mm-1)/12)-1;
							$mm-=int(($mm-1)/12)*12-12;
						}
					}
				}
			}
		}else{
			$len=1;
		}
		$s=substr($s,$len);
	}
	return if !$count;
	($yy,$mm,$dd);
}

#---------------------------------------------------------------------------
#        Atom
#

sub print_atom
{
	my ($page,$atom_mode) = @_;
	my ($ss,$mm,$hh,$d,$m,$y,$w)=gmtime(data::page_time($page));
	my $date = sprintf("%04d-%02d-%02dT%02d:%02d:%02dZ",$y+1900,$m+1,$d, $hh,$mm,$ss);

	print "Content-Type: application/xml\n";
	print "\n";
	print "<?xml version=\"1.0\" encoding=\"$cfg{CODE_SET}\"?>\n";
	print "<feed xmlns=\"http://www.w3.org/2005/Atom\">\n";
	print " <title>$cfg{TITLE}</title>\n";
	print " <subtitle>$cfg{COMMENT}</subtitle>\n";
	print " <generator uri='http://binzume.net/' version='2.8.3'>kukiki-</generator>\n";
	print " <id>$cfg{URL}</id>\n";
	print " <link rel='self' type='application/atom+xml' href='$request_url'/>\n";
	print " <link href=\"$cfg{URL}\"/>\n";
	print " <author><name>$cfg{AUTHOR}</name></author>\n" if $cfg{AUTHOR};
	print " <updated>$date</updated>\n";

	$ano=0;
	$n=0;
	*IN=data::page_open($page);
	my $title='';
	my $lv=$cfg{DIARY_MODE}?1:2;
	my ($link,$desc);

	my $p=sub{
		if ($title) {
			if ($atom_mode eq 'full') {
				$content = '<p>'.inline_conv($desc).'</p>';
			}
			$desc=substr($desc,0,250).'...' if (length($desc)>200);
			$desc=~s/</&lt;/g;
			$desc=~s/>/&gt;/g;
			print " <entry>\n";
			print "  <title>$title</title>\n";
			print "  <link href=\"$top_url/$link\"/>\n";
			print "  <id>$top_url/$link</id>\n";
			print "  <updated>$date</updated>\n";
			if ($atom_mode eq 'full' && $content) {
				print "<content type='html' xml:base='$top_url/$link'><![CDATA[";
				print $content;
				print "]]></content>";
			} else {
				print "  <summary><![CDATA[$desc]]></summary>\n" if $desc;
			}
			print " </entry>\n";
			$title='';
		}
	};

	$maxentrys = 5;
	if ($atom_mode eq 'full') {
		$maxentrys = 10;
	}
	

	while(<IN>){
		s/{{[^\|]*\|(.+?)}}/\1/g;
		if(/^\[([\w\-#]+)\]/){
			$p->();
			last if ++$n > $maxentrys;
			$ent=$1;
			my $t=0;
			$t = $1 if $ent=~s/#(\d+)$//;
			$d = $1 if $ent=~/\d+-\d\d-(\d\d)/;
			$title = $cfg{RSS_STR};
			$title=~s/\${DATE}/$ent/;
			$link="$page#$d";
			if ($t) {
				my ($ss,$mm,$hh,$d,$m,$y,$w)=gmtime($t);
				$date=sprintf("%04d-%02d-%02dT%02d:%02d:%02dZ",$y+1900,$m+1,$d, $hh,$mm,$ss);
			} elsif ($ent=~/^(\d+)-(\d+)-(\d+)$/) {
				$date=$ent."T00:00:00Z";
			}
			$desc = '';
			$ano=1;
		} elsif (/^(\*+)(.+)/ && length($1)<=$lv) {
			if ($atom_mode eq 'simple') {
				$title.= ",$2" if length($title."|$2")<60 ;
			} else {
				$p->();
				$title = "- $2";
				$link = "$page#${d}A$ano";
				$desc = '';
				$ano++;
			}
		} elsif (/^\&rss\((\d+)\)/) {
			$lv=$1;
		} elsif (/^\&time\(([\w\.\-+:]+)\)/) {
			$date=$1;
		} else {
			chomp;
			if ($atom_mode eq 'full') {
				$desc.="</p>\n<p>" if $_ eq '' && $desc ne '';
			}
			s/^\&[\w{\[\]\}\(\)]+//g;
			s/\&/\&amp;/g;
			s/^\\\\//;
			s/^\/\/.*//;
			if ($atom_mode eq 'full') {
				$desc.=$_;
			} else {
				$desc.=$_ if(length($desc)<200);
			}
		}
	}
	$p->();
	close(IN);

	print "</feed>\n";
}


#---------------------------------------------------------------------------
#        RSS
#

sub print_rss
{
	my $page = $_[0];
	get_last() if $cfg{DIARY_MODE};

	print "Content-Type: application/xml\n";
	print "\n";

	print "<?xml version=\"1.0\" encoding=\"$cfg{CODE_SET}\" ?>\n";
	print "<rss version=\"2.0\">\n";
	print " <channel>\n";
	print "  <title>$cfg{TITLE}</title>\n";
	print "  <link>$cfg{URL}</link>\n";
	print "  <description>$cfg{COMMENT}</description>\n";

	$ano=0;
	$n=0;
	$date="0000-00-00";
	*IN=data::page_open($page);
	my $title='';
	my $lv=$cfg{DIARY_MODE}?1:2;
	my ($link,$desc);
	while(<IN>){
		if(/^\[([\w\-]+)\]/){
			if ($title) {
				$desc=substr($desc,0,200).'...' if(length($desc)>200);
				print " <item>\n";
				print "  <title>$title</title>\n";
				print "  <link>$top_url/$link</link>\n";
				print "  <description>$desc</description>\n";
				print " </item>\n";
				$title='';
			}
			last if ++$n>5;
			$ent=$1;
			$ent=~s/#.*$//;
			$d = $1 if $ent=~/\d+-\d\d-(\d\d)/;
			my $title = $cfg{RSS_STR};
			$title=~s/\${DATE}/$ent/;
			print " <item>\n";
			print "  <title>$title</title>\n";
			print "  <link>$top_url/$page#$d</link>\n";
			print "  <description>Diary</description>\n";
			if ($ent=~/^(\d+)-(\d+)-(\d+)$/) {
				#print "  <dc:date>$ent</dc:date>\n";
				print "  <pubDate>".rfc822_date($1,$2,$3,8,0,0)."</pubDate>\n";
			}
			print " </item>\n";
			$ano=1;
		} elsif (/^(\*+)(.+)/ && length($1)<=$lv) {
			if ($title) {
				$desc=substr($desc,0,200).'...' if(length($desc)>200);
				print " <item>\n";
				print "  <title>$title</title>\n";
				print "  <link>$top_url/$link</link>\n";
				print "  <description>$desc</description>\n";
				print " </item>\n";
				$title='';
			}
			$title = "- $2";
			$link = "$page#${d}A$ano";
			$desc = '';
			$ano++;
		} elsif (/^\&rss\((\d+)\)/) {
			$lv=$1;
		} else {
			chomp;
			s/\&/\&amp;/;
			$desc.=$_ if(length($desc)<200);
		}
	}
	if ($title) {
		$desc=substr($desc,0,200).'...' if(length($desc)>200);
		print " <item>\n";
		print "  <title>$title</title>\n";
		print "  <link>$top_url/$link</link>\n";
		print "  <description>$desc</description>\n";
		print " </item>\n";
		$title='';
	}
	close(IN);

	print " </channel>\n";
	print "</rss>\n";
}

#---------------------------------------------------------------------------
#   insider module?  for diary
#

sub get_path
{
	my ($page2) = @_;
	my $p = $page2;
	return $p if $p=~/^[\?#]/;
	$page2=~s/[^\/]+$//;
	my @a=split(/\//,$page2);
	my @b=split(/\//,$page_dir);
	while(@a>0 && ($a[0] eq $b[0])){
		$p=~s/^[^\/]+\///;
		shift @a; shift @b;
	}
	my $l= '../'x(0+@b).$p;
	$l = '../'.$l if $ENV{'PATH_INFO'} =~/\/-$mode$/;
	$l = 'index' if !$l;
	$l.=$suffix if $l!~/\/$/ && $l!~/\.\w+$/  && $l!~/[\?\#]/;
	$l=~s/\/\//\//;
	$l;
}

sub get_page_path
{
	my ($path) = @_;
	my $p=$path;

	$path=$page_dir.$path if !($path=~s/^\///);

	if (!$path || $path=~/\/$/){
		if ($cfg{DIARY_MODE}) {
			get_last();
			$path.=sprintf('%04d-%02d',$last_year,$last_month);
		} else {
			$path.='index';
		}
	} elsif ($cfg{DIARY_MODE} && !data::page_exist($path)) {
		$path=~s/(\d+-\d+)(-\d+)$/\1~\1\2/;
	} elsif (!data::page_exist($path) && data::page_exist($cfg{INCLUDE_PATH}.$p)) {
		$path = $cfg{INCLUDE_PATH}.$p;
	}

	$path=~s|/[^/]+/\.\./|/|g;
	$path=~s|/\./|/|g;
	$path=~s|^[\./]||g;

	$path='' if $path=~/\.\./;
	$path;
}

sub get_file_path
{
	my ($file) = @_;
	my $f='';
	if (!($file=~s/^\///)) {
		$f = "$cfg{DATA_DIR}$page/$ent/$file" if $ent ne '';
		$f = "$cfg{DATA_DIR}$page/$file" if !-f $f;
		$f = "$cfg{DATA_DIR}$page_dir$file" if !-f $f;
		$f = "$cfg{DATA_DIR}common/$file" if !-f $f;
	}
	$f = "$cfg{DATA_DIR}$file" if !-f $f;
	return '' if !-f $f;
	$f =~s|/[^/]+/\.\./|/|g;

	$f;
}

sub get_title
{
	my ($page) = @_;
	my $p=$page;
	$page .= 'index' if $page=~/\/$/;
	return '' if (!data::page_exist($page));
	local *TITLE=data::page_open($page);
	$_=<TITLE>;
	close(TITLE);
	return $1 if (/^\&title:(.+)$/);
	return $1 if (/^\*([^\*].*)$/);
	return $1 if ($p=~/\/([^\/]+)$/);
	return $1 if ($p=~/\/([^\/]+)\/$/);
	return 'Untitled';
}


sub get_last
{
	my ($sec,$min,$hour,$cur_d,$cur_m,$cur_y,$wday) = localtime();
	$cur_y+=1900;
	$cur_m++;
	my ($st_y,$st_m) = split(/-/,$cfg{DIARY_START});
	$st_y=int($st_y);
	$st_m=int($st_m);
	$st_y = $cur_y-3 if !$st_y;

	$y=$cur_y; $m=$cur_m;
	$last_month=$m;
	$last_year=$y;
	while ($y*12+$m >= $st_y*12+$st_m) {
		if(data::page_exist($page_dir.sprintf('%04d-%02d',$y,$m))){
			$last_month=$m;
			$last_year=$y;
			last;
		}
		if (--$m<1) {$m=12;$y--;}
	}
	close(IN);
}

#---------------------------------------------------------------------------
#   access log
#
sub access_log {
	return if !(-f $cfg{LOGFILE});
	return if (index($ENV{HTTP_REFERER},$cfg{URL})==0);

	$log_mode=3;
	my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst)
		= localtime(time);
	$mon++;
	$year+=1900;
	$date = sprintf("%04d-%02d-%02dT%02d:%02d",
		$year, $mon , $mday,  $hour, $min);

	my $host=$ENV{REMOTE_ADDR};
	$host="*$ENV{REMOTE_HOST}" if $ENV{REMOTE_HOST} ne "";
	$host="*$ENV{HTTP_X_FORWARDED_FOR}($ENV{REMOTE_ADDR})" if $ENV{HTTP_X_FORWARDED_FOR} ne "";

	open(LOG, ">> $cfg{LOGFILE}");
	if (!flock(LOG, 2)) {
		printf("lock error.");
		close(LOG);
		return;
	}

	print LOG "[$date] $ENV{PATH_INFO} Host:$host $ENV{HTTP_REFERER}\n";
	if( ($log_mode&2) && $ENV{HTTP_USER_AGENT} ne "") {
		print(LOG "\t$ENV{HTTP_USER_AGENT}\n");
	}
	close(LOG);

}

#------------------------------- Send mail
sub snd_mail{
	my ($to,$from) = @_;
	my $msg = "";
	$msg .= "To: $to\n";
	$msg .= "From: $from\n";
	$msg .= "Subject: $subject\n";
	$msg .= "\n";
	$msg .= $message;
	open(OUT, "| $sendmail $to");
	print OUT $msg;
	close(OUT);
}


sub test
{
	print "Content-Type: text/plain\n";
	print "Pragma: no-cache\n";
	print "Cache-Control: no-cache\n";
	print "\n";
	print "test start.\n";

	print "data module = $dir_modules/data.pm ... ";
	print "".(-f "$dir_modules/data.pm"?"OK":"NG!").".\n";

	print "modules directry = $dir_modules ... ";
	print "".(-d $dir_modules?"OK":"NG!").".\n";
	print "\n\nEnv.\n";
	print "$_ = $ENV{$_}\n" for(keys %ENV);

	print "\nEND of test.\n\n";
}
