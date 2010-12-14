use strict;
use warnings;
use Plack::Builder;
use Plack::Request;
use Plack::Util;
use URI;

require 'preprocess.pl';
my $config = $main::config;

my $file_serve = builder {
	enable sub {
		my $app = shift;
		return sub {
			my $res = $app->(@_);
			Plack::Util::response_cb($res, sub {
				my $res = shift;
				Plack::Util::header_set($res->[1], 'Pragma', 'no-cache');
				Plack::Util::header_set($res->[1], 'Cache-control', 'no-cache');
			});
		};
	};
	enable sub {
		my $app = shift;
		return sub {
			my $env = shift;
			my $req = Plack::Request->new($env);
			my $code_root = $req->base;
			$code_root->path($code_root->path . 'code/');
			my $res = $app->($env);
			Plack::Util::response_cb($res, sub {
				my $res = shift;
				my $h = Plack::Util::headers($res->[1]);
				return sub {
					my $chunk = shift;
					return unless defined $chunk;
					local $config->{code_root} = $code_root->as_string;
					local $config->{rpc_root} = $env->{'lacuna.rpc.root'}
						if $env->{'lacuna.rpc.root'};
					return main::process($chunk, $config);
				};
			});
		};
	};
	enable 'Static',
		path => sub { s{^/code/}{} },
		root => 'code/',
	;
	enable 'Static',
		path => sub { s{^/(?:index.html)?$}{/html/index.html} },
	;
	sub { [ 404, [], ['not found'] ] };
};

if ($config->{rpc_proxy}) {
	require Plack::App::Cascade;
	require Plack::App::Proxy;
	Plack::App::Cascade->new(apps => [
		builder {
			enable sub {
				my $app = shift;
				return sub {
					my $env = shift;
					my $req = Plack::Request->new($env);
					$env->{'lacuna.rpc.root'} = $req->base->as_string;
					$app->($env);
				};
			};
			$file_serve;
		},
		builder {
			enable sub {
				my $app = shift;
				return sub {
					my $env = shift;
					my $req = Plack::Request->new($env);
					$env->{'plack.proxy.url'}
						= URI->new_abs($req->path, URI->new_abs($config->{rpc_root}, $req->uri))->as_string;
					$app->($env);
				};
			};
			Plack::App::Proxy->new;
		},
	]);
}
else {
	$file_serve;
}

