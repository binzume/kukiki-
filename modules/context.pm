#
# コンテキスト
#
# 1リクエスト内で情報を取り回す用
#
# @author kawahira[at]binzume.net
# @since 2010-09-26
#

package Context;

sub new{
	my $pkg = shift;
	my $hash = {
		page=>undef,  # ページ
		page_dir=>undef, # ページがあるディレクトリ
		params=>undef, # GETで渡されたパラメータ
		form=>undef, # POSTで渡されたデータ
		conf=>undef,
		user=>undef,
	};
	bless $hash,$pkg;
}

sub set_page{
	my $self = shift;
	my $setpage = shift;
	$self->{page} = $setpage if $setpage;
	return $self->{page};
}

sub page{
	my $self = shift;
	return $self->{page};
}

1;
