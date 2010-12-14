#!/usr/bin/env perl
package main;
use strict;

use Template::Tiny;

our $config = {};
{
	open my $fh, '<', 'lacuna.conf';
	while (my $line = <$fh>) {
		chomp $line;
		$line =~ s/#.*//g;
		my ($k, $v) = split /=/, $line, 2;
		for ( $k, $v ) {
			s/^\s+//;
			s/\s+$//;
		}
		if ($k) {
			$config->{lc $k} = $v;
		}
	}

	for my $key ( keys %ENV ) {
		if ($key =~ /^LACUNA_(.*)$/i) {
			$config->{lc $1} = $ENV{$key};
		}
	}
}

my $template = Template::Tiny->new;
sub process {
	my $input = shift;
	my $config = shift;
	my $output;
	$template->process(\$input, $config, \$output);
	return $output;
}

if (! caller) {
	my $input = do { local $/; <> };
	print process($input, $config);
}

1;

