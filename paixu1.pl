#!/usr/bin/perl
use warnings;
use diagnostics;
use strict;
use 5.010;

sub by_number{
	if($a gt $b){
		1;
	}
	elsif($a lt $b){
		-1;

	}else{
		0;
	}

}
my @dai_pai = qw{ bob alicy lili jianhua};

my @mynumber = sort by_number @dai_pai;

say "@mynumber";



