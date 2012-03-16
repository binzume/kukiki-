#
#    設定モジュール
#                           2007-02-12

package mod_config;
use data;

$flag_auth = 1; # 認証が必要(1) 不要(0)
$flag_config_dir = 1; # ディレクトリごとの設定を許可
$flag_mkdir = 1; # ディレクトリ作成を許可
$use_md5 = 1;

$cgi_name = $ENV{SCRIPT_NAME};

sub print_page
{
	$context = $main::context;
	%FORM = %main::FORM;
	@path = @main::path;
	%cfg = %main::cfg;
	@week = @main::week;

	$prefix = $main::prefix;
	$page = $main::page;
	$dir = $main::page_dir;
	$entry = $main::entry;

	$cfg{TEXT_DIR} = '.'  if $cfg{TEXT_DIR} eq '';

	# 認証
	if ($flag_auth && $context->{user} eq '') {
		$data::msgvar{PAGE} = "編集ログイン";
		print "Content-type: text/html\n";
		print "\n";
		data::print_msg('HTML_HEADER');
		mod_login::print_html();
		data::print_msg('HTML_FOOTER');
		return;
	}
	$user = $context->{user};

	#///////////////////////////////////////////////////////////////////
	# ここからは認証済み
	#

	print "Content-type: text/html\n";
	print "\n";

	$data::msgvar{PAGE} = "設定変更";
	data::print_msg('HTML_HEADER');
	my $mode = $context->{params}{mode};

	print "<h1>設定変更</h1>\n";

	print "<div class='confmenu'>\n";

	print "&nbsp;<a href='?'>戻る</A>\n";
	if ($mode eq '' || $mode eq 'global') {
		print "| <span class='selected'>グローバル設定</span>\n";
	} else {
		print "| <a href='?config'>グローバル設定</a>\n";
	}
	if ($mode eq 'dir') {
		print "| <span class='selected'>ディレクトリ設定</span>\n";
	} else {
		print "| <a href='?config&mode=dir'>ディレクトリ設定</a>\n";
	}
	if ($mode eq 'user') {
		print "| <span class='selected'>ユーザ管理</span>\n";
	} else {
		print "| <a href='?config&mode=user'>ユーザ管理</a>\n";
	}
	if ($mode eq 'module') {
		print "| <span class='selected'>モジュール設定</span>\n";
	} else {
		print "| <a href='?config&mode=module'>モジュール設定</a>\n";
	}
	print "</div>\n";


	if ($ARGV[0]=~/^module-(\w+)$/) {
		module_config($1);
	} elsif ($mode eq 'module') {
		module_list();
	} elsif ($mode eq 'dir') {
		edit_dir();
	} elsif ($mode eq 'user') {
		edit_user();
	} else {
		edit_global();
	}


	data::print_msg('HTML_FOOTER');
}



#///////////////////////////////////////////////////////////////////////////
#   グローバル設定
#

sub edit_global
{
	data::set_dir('', 1);
	if ($FORM{module} eq 'mod_config' && $FORM{mode} eq 'conf') {
		if(save_conf()) {
			print "設定を保存しました\n";
		} else {
			print "設定の保存に失敗しました\n";
		}
	}

	my %CFG;
	data::conf_read(\%CONF,'CONFIG');


	print "<form method=POST action='?config'>\n";
	print "<input type=hidden name='module' value='mod_config'>\n";
	print "<input type=hidden name='mode' value='conf'>\n";

	print "<h2>一般</h2>\n";

	print "<ul>\n";

	print "<li>タイトル：\n";
	print "<input type=text size=32 name='TITLE' value=\"$CONF{TITLE}\"></li>\n";

	print "<li>コメント：\n";
	print "<input type=text size=40 name='COMMENT' value=\"$CONF{COMMENT}\"></li>\n";

	print "<li>作者名：\n";
	print "<input type=text size=32 name='AUTHOR' value=\"$CONF{AUTHOR}\"></li>\n";

	print "<LI>トップURL：\n";
	print "<input type=text size=40 name='URL' value=\"$CONF{URL}\"></li>\n";

	print "<LI>スタイル：\n";
	opendir(INDIR,'styles');
	my @files = readdir(INDIR);
	closedir(INDIR);

	print "<select name='STYLE'>\n";
	for (@files) {
		if (/^(.*)\.html$/) {
			print "  <option value='$1' ".($1 eq $CONF{STYLE} ?'selected="selected"':'').">$1</option>\n";
		}
	}
	print "</select>\n";

	print "<LI>文字コード：\n";
	print "<input type=text size=32 name='CODE_SET' value=\"$CONF{CODE_SET}\"></li>\n";

	print "</ul>\n";

	print "<h2>パスワード変更:$user</h2>\n";
	print "<ul>\n";
	print "	<li>パスワード：<input type=text size=32 name='pass'></li>\n";
	print "	<li>確認：<input type=text size=32 name='pass2'></li>\n";
	print "</ul>\n";

	print "<h2>日記用</h2>\n";

	print "<ul>\n";

	print "<LI>日記拡張機能：\n";
	$CONF{DIARY_MODE}=2 if !defined($CONF{DIARY_MODE});
	print "<INPUT TYPE=radio NAME=DIARY_MODE VALUE=0".(($CONF{DIARY_MODE}==0)?' CHECKED':'').">無効\n";
	print "<INPUT TYPE=radio NAME=DIARY_MODE VALUE=1".(($CONF{DIARY_MODE}==1)?' CHECKED':'').">有効\n";

	print "<LI>日記の開始日付(YYYY-MM-DD)：\n";
	print "<INPUT type=text name=DIARY_START SIZE=32 VALUE=\"$CONF{DIARY_START}\">\n";

	print "<LI>曜日リスト：\n";
	print "<INPUT type=text name=WEEKSTR SIZE=32 VALUE=\"$CONF{WEEKSTR}\">\n";

	print "</ul>\n";

	print "<input class=button type=submit value=\"設定\">\n";

	print "</form>\n";
}

#///////////////////////////////////////////////////////////////////////////
#   ディレクトリ設定
#
sub edit_dir
{
	data::set_dir($main::page_dir, 1);
	my %CFG;
	data::conf_read(\%CONF,'CONFIG');

	if ($FORM{module} eq 'mod_config' && $FORM{mode} eq 'conf') {
		if(save_conf()) {
			print "設定を保存しました\n";
		} else {
			print "設定の保存に失敗しました\n";
		}
	}

	print "ディレクトリ:". $main::page_dir. "\n";

	print "<form method=POST action='?config&mode=dir'>\n";
	print "<input type=hidden name='module' value='mod_config'>\n";
	print "<input type=hidden name='mode' value='conf'>\n";

	print "<h2>一般</h2>\n";

	print "<ul>\n";

	print "<li>タイトル：\n";
	print "<input type=text size=32 name='TITLE' value=\"$CONF{TITLE}\"></li>\n";

	print "<li>コメント：\n";
	print "<input type=text size=40 name='COMMENT' value=\"$CONF{COMMENT}\"></li>\n";

	print "<li>作者名：\n";
	print "<input type=text size=32 name='AUTHOR' value=\"$CONF{AUTHOR}\"></li>\n";

	print "<LI>トップURL：\n";
	print "<input type=text size=40 name='URL' value=\"$CONF{URL}\"></li>\n";

	print "<LI>スタイル：\n";
	opendir(INDIR,'styles');
	my @files = readdir(INDIR);
	closedir(INDIR);

	print "<select name='STYLE'>\n";
	for (@files) {
		if (/^(.*)\.html$/) {
			print "  <option value='$1' ".($1 eq $CONF{STYLE} ?'selected="selected"':'').">$1</option>\n";
		}
	}
	print "</select>\n";

	print "<LI>文字コード：\n";
	print "<input type=text size=32 name='CODE_SET' value=\"$CONF{CODE_SET}\"></li>\n";

	print "</ul>\n";


	print "<h2>日記用</h2>\n";

	print "<ul>\n";

	print "<LI>日記拡張機能：\n";
	$CONF{DIARY_MODE}=2 if !defined($CONF{DIARY_MODE});
	print "<INPUT TYPE=radio NAME=DIARY_MODE VALUE=0".(($CONF{DIARY_MODE}==0)?' CHECKED':'').">無効\n";
	print "<INPUT TYPE=radio NAME=DIARY_MODE VALUE=1".(($CONF{DIARY_MODE}==1)?' CHECKED':'').">有効\n";
	print "<INPUT TYPE=radio NAME=DIARY_MODE VALUE=2".(($CONF{DIARY_MODE}==2)?' CHECKED':'').">親に従う\n";

	print "<LI>日記の開始日付(YYYY-MM-DD)：\n";
	print "<INPUT type=text name=DIARY_START SIZE=32 VALUE=\"$CONF{DIARY_START}\">\n";

	print "<LI>曜日リスト：\n";
	print "<INPUT type=text name=WEEKSTR SIZE=32 VALUE=\"$CONF{WEEKSTR}\">\n";

	print "</ul>\n";

	print "<input class=button type=submit value=\"設定\">\n";

	print "</form>\n";
}

sub edit_user
{
	data::set_dir('', 1);

	my %users;
	data::conf_read(\%users,'USERS');

	my $action = $context->{form}{action};
	if ($action eq 'add_user') {
		if (!$context->{form}{user}=~/^[\w_]+$/) {
			print "ERROR:ユーザー名が不正です\n";
			return 0;
		}
		if (data::conf_get_key('USERS',$context->{form}{user})) {
			print "ERROR:既に存在します\n";
			return 0;
		}
		if ($context->{form}{passwd} ne $context->{form}{passwd2}) {
			print "ERROR:パスワードが一致しません\n";
			return 0;
		}

		my @s = ( 'A'..'Z', 'a'..'z','0'..'9', '.','/' );
		my $s = $s[int(rand(64))].$s[int(rand(64))];
		if ($use_md5) {
			$s='$1$';
			$s.=$s[int(rand(64))] for(1..8);
		}
		data::conf_set_key('USERS',$context->{form}{user},crypt($context->{form}{passwd},$s));
		print "NOTICE:ユーザを追加しました．\n";
	}

	if ($action eq 'remove_user') {
		my $u = $context->{form}{username};
		print "<h2>USER: $u</h2>";
		print "本当に削除しますか？";
		print "<form method='POST' action='?config&mode=user'>\n";
		print "<input type='hidden' name='action' value='remove_user_ok'>\n";
		print "<input type='hidden' name='username' value='$u'>\n";
		print " <input class=button type='submit' value='削除'>\n";
		print "</form>\n";
		return 0;
	}
	if ($action eq 'remove_user_ok') {
		my $u = $context->{form}{username};
		delete $users{$u};
		data::conf_del_key('USERS',$u);
		print "NOTICE:ユーザを削除しました．\n";
	}

	if ($context->{params}{username}) {
		my $u = $context->{params}{username};
		print "<h2>USER: $u</h2>";
		print "<form method='POST' action='?config&mode=user'>\n";
		print "<input type='hidden' name='action' value='remove_user'>\n";
		print "<input type='hidden' name='username' value='$u'>\n";
		print " <input class=button type='submit' value='削除'>\n";
		print "</form>\n";

		return 0;
	}

	print "<h2>users</h2>";
	print "<ul>\n";
	for (keys %users) {
		my ($u,$p) = split(/,/,$_);
		print " <li><a href='?config&mode=user&username=$u'>$u</a></li>\n";
	}
	print "</ul>\n";


	print "<h2>add user</h2>";
	print "<form method='POST' action='?config&mode=user'>\n";
	print "<input type='hidden' name='action' value='add_user'>\n";
	print "<ul>\n";
	print "	<li>ユーザー：<input type='text' size=32 name='user'></li>\n";
	print "	<li>パスワード：<input type='text' size=32 name='passwd'></li>\n";
	print "	<li>確認：<input type='text' size=32 name='passwd2'></li>\n";
	print "</ul>\n";
	print " <input class=button type='submit' value='追加'>\n";
	print "</form>\n";
}


sub module_list
{
	opendir(DIR, './modules');
	@files = readdir(DIR);
	closedir(DIR);

	print "<h2>モジュール一覧</h2>\n";

	print "<ul>\n";
	for (@files) {
		next if /^\./ || !/\.pm$/;
		print "<li>$_</li>\n";
	}
	print "</ul>\n";
}

sub module_config
{
	my $mod = $_[0];
	my $f=0;
	if (-f "modules/mod_$mod.pm") {
		require "mod_$mod.pm" && ($f=1);
		if (!$f || !defined @{"mod_${mod}::CONFIG"}) {
			print "モジュールが見つかりません\n";
			return;
		}
		@CONFIG = @{"mod_${mod}::CONFIG"};
		$modname=${"mod_${mod}::MODNAME"};
	}

	my %CONF;
	data::conf_read(\%CONF,$modname);
	
	my $i;
	print "<form method='POST' action='?config'>\n";
	print "<input type='hidden' name='module' value='mod_config'>\n";
	print "<input type='hidden' name='mode' value='module-$mod'>\n";
	print "<ul>\n";
	for ($i=0;$i<@CONFIG;$i+=3) {
		print "<li>$CONFIG[$i+2]：\n";
		if ($CONFIG[$i+1] eq 'bool') {
			print "<input type='radio' name='$CONFIG[$i]' value='0'".(($CONF{$CONFIG[$i]}==0)?' CHECKED':'').">無効\n";
			print "<input type='radio' name='$CONFIG[$i]' value='1'".(($CONF{$CONFIG[$i]}==1)?' CHECKED':'').">有効\n";
			print "<input type='radio' name='$CONFIG[$i]' value='2'".(($CONF{$CONFIG[$i]}==2)?' CHECKED':'').">デフォルト\n";
		}elsif ($CONFIG[$i+1] eq 'int') {
			print "<input type='text' name='$CONFIG[$i]' size=10 value='$CONF{$CONFIG[$i]}'>\n";
		}elsif ($CONFIG[$i+1] eq 'str') {
			print "<input type='text' name='$CONFIG[$i]' size=32 value='$CONF{$CONFIG[$i]}'>\n";
		}
	}
	print "</ul>\n";
	print "<input class='button' type='submit' value=\"設定\">\n";
	print "</form>\n";

}

sub save_conf()
{
	if ($FORM{pass}) {
		if ($FORM{pass} ne $FORM{pass2}) {
			print "ERROR:パスワードが一致しません\n";
			return 0;
		}
		my @s = ( 'A'..'Z', 'a'..'z','0'..'9', '.','/' );
		my $s = $s[int(rand(64))].$s[int(rand(64))];
		if ($use_md5) {
			$s='$1$';
			$s.=$s[int(rand(64))] for(1..8);
		}
		data::conf_set_key('USERS',$user,crypt($FORM{pass},$s));
		print "NOTICE:パスワードを変更しました．\n";
	}


	$FORM{TITLE}=~s/[\0-\x1f]//g;
	$FORM{COMMENT}=~s/[\0-\x1f]//g;
	$FORM{AUTHOR}=~s/[\0-\x1f]//g;
	$FORM{CODE_SET}=~s/[^\w-]//g;
	$FORM{DIARY_START}=~s/[^\w-]//g;
	$FORM{URL}=~s/[\0-\x1f]//g;
	$CONF{TITLE} = $FORM{TITLE} if $FORM{TITLE};
	$CONF{AUTHOR} = $FORM{AUTHOR} if $FORM{AUTHOR};
	$CONF{CODE_SET} = $FORM{CODE_SET} if $FORM{CODE_SET};
	$CONF{URL} = $FORM{URL} if $FORM{URL};
	$CONF{COMMENT} = $FORM{COMMENT} if $FORM{COMMENT};
	$CONF{DIARY_START} = $FORM{DIARY_START};
	delete $CONF{DIARY_START} if !$FORM{DIARY_START};
	$CONF{STYLE} = $FORM{STYLE};
	delete $CONF{"STYLE"} if !$FORM{STYLE} || $FORM{STYLE} eq 'format.html';
	data::conf_write(\%CONF,'CONFIG');
}

1;
