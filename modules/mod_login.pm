#
#    ログインモジュール
#                           2007-01-01

package mod_login;
use data;

$default_user='admin'; # デフォルトユーザー
$user = ''; # ユーザー

sub start{
	my $context = shift;
	my $f=0;
	if ($main::FORM{module} eq 'mod_login') {
		$user = $main::FORM{user};
		$passwd = $main::FORM{passwd};
		$f=1;
	} else {
		&get_cookie;
		($user, $passwd) = split(/:/,$COOKIE{user},2);
	}
	if ($ARGV[0] eq 'logout') {
		$user='';
		$passwd = '';
		$f=1;
	}

	# 認証
	$user =~s/[^\w\.#\@-]//g;
	$user_tmp = $user;

	if ($user && auth($user,$passwd)!=1) {
		$user = '';
		$passwd = '';
		$f=1;
	}
	$context->{user} = $user;

	&set_cookie if $f;
	1;
}

sub print_html {
	my $context = $main::context;
	print "<div class='module login'>\n";
	if ($user) {
		print "\n\tUser:$user\n";
		print "\t<a href='?logout'>[LOGOUT]</a>\n";
	} elsif ($main::mode eq 'login' || $ARGV[0] eq 'logout' || $context->{params}{mode} eq 'login') {
		print "<strong>\nAuth Error ($user_tmp)\n</strong>\n" if $user_tmp;
		print_login();
	} else {
		print "\t[<a href='?mode=login' rel='nofollow'>ログイン</a>]\n";
	}
	print "</div>\n";
}

sub print_page {
	my $context = shift;
	print "Content-type: text/html\n";
	print "Pragma: no-cache\n";
	print "Cache-Control: no-cache\n";
	print "\n";

	print "&nbsp;[<a href='$main::curdir'>トップ</A>]\n";
	print "&nbsp;[<a href='".main::get_path($main::page)."'>戻る</A>]\n";

	$data::msgvar{PAGE} = "ログイン";
	data::print_msg('HTML_HEADER');


	if ($user) {
		print "\n\tUser:". $context->{user} ."\n";
		print "\t<a href='?logout'>[LOGOUT]</a>\n";
	} else {
		print "<strong>\nAuth Error ($user_tmp)\n</strong>\n" if $user_tmp;
		print_login();
	}

	data::print_msg('HTML_FOOTER');
}

#///////////////////////////////////////////////////////////////////////////
#   認証
#
sub auth
{
	my ($user,$pass) = @_;

	data::set_dir('');
	my $dat = data::conf_get_key('USERS',$user);
	data::set_dir($main::page_dir);
	$dat=~s/^\s+//;
	$dat=~s/\s+$//;
	if ($dat ne '') {
		if ($dat eq '' || $dat eq crypt($pass,$dat)) {
			return 1;
		} else {
			return 0;
		}
	}
	return -1;
}


#///////////////////////////////////////////////////////////////////////////
#   ログイン画面
#
sub print_login
{
	print "<H3>ログイン</H3>";
	print "<form method=POST action='?mode=login'>\n";
	print "<input type=hidden name=module value=mod_login>\n";

	print "USER:<br> <input class='input' type='text' name=user value='$default_user' size=20><BR>\n";
	print "PASSWD:<br> <input class='input' type='password' name='passwd' size=20><BR>\n";

	print "<input type='submit' value='LOGIN' class='button'><BR>\n";
	#print "<input type='checkbox' name='autologin' value=1>セッションを保持\n";
	print "</FORM>\n";
}

#///////////////////////////////////////////////////////////////////////////
#   ログアウト画面
#
sub print_logout
{
	print "ログアウトしました．<a href='$main::cgi_path'>戻る</a>\n";
}


#///////////////////////////////////////////////////////////////////////////
# Get cookie
sub get_cookie
{
	foreach(split(/[\;']/,$ENV{'HTTP_COOKIE'})) {
		($name, $value) = split(/=/);
		$name =~ s/\s//g;
		$COOKIE{$name} = $value;
	}
}
# Set cookie
sub set_cookie
{
	($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdat) = gmtime(time+3600*12);
	$cookie_expire = sprintf("%s,%02d %s %04d %02d:%02d:02d GMT",
				("Sun","Mon","Tue","Wed","Thu","Fri","Sat")[$wday],
				$mday,
				("Jan","Feb","Mar","Apr","May","Jun",
				 "Jul","Aug","Sep","Oct","Nov","Dec")[$mon],
				$year + 1900,
				$hour,
				$min,
				$sec);
#	print "Set-Cookie: user=$user:$passwd; path=$cgi_name; expires=0\n";
	print "Set-Cookie: user=$user:$passwd; path=$main::cgi_path\n";
}
1;

