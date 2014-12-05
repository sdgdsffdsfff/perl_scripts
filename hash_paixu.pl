#!/usr/bin/perl
use warnings;
use diagnostics;
use strict;
use 5.010;


my %score =(
	"bob" => "59",
	"ali" => "60",
	"lucy" => "79"
	);

sub by_hash{
	$score{$b} <=> $score{$a};
}


my @new_list = sort by_hash keys %score;
say "@new_list";

