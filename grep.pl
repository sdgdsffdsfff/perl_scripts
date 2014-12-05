#!/usr/bin/perl
use warnings;
use diagnostics;
use strict;
use 5.010;

=pod
sub digit_sum_is_odd{
	my $input = shift;
	my @digits = split;
	my $sum;
	$sum += $_ for @digits;
	return $sum % 2;
}
=cut

my @nums = qw{ 11 14 16 8 24};
my @new = grep {
	my $input = shift;
	my @digits = split;
	my $sum;
	$sum += $_ for @digits;
	$sum % 2;
	}@nums;
say "@new";

