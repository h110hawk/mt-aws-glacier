#!/usr/bin/perl

# mt-aws-glacier - Amazon Glacier sync client
# Copyright (C) 2012-2013  Victor Efimov
# http://mt-aws.com (also http://vs-dev.com) vs@vs-dev.com
# License: GPLv3
#
# This file is part of "mt-aws-glacier"
#
#    mt-aws-glacier is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    mt-aws-glacier is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

use strict;
use warnings;
use utf8;
use Test::More tests => 580;
use Test::Deep;
use lib qw{.. ../..};
use Journal;
use Test::MockModule;

my $rootdir = 'root_dir';

my $data_sample = 	{
	archive_id => "HdGDbije6lWPT8Q8S3uOWJF6Ou9MWRlrfMGDr6TCrhXuDqJ1pzwKR6XV4l1IZ-VrDd2rlLxDFACqnuJouYTzsT5zd6s2ZEAHfRQFriVbjpFfJ1uWruHRRXIrFIma4PVuz-fp9_pBkA",
	job_id => "HdGDbije6lWPT8Q8S3uOWJF6777MWRlrfMGDr688888888888zwKR6XV4l1IZ-VrDd2rlLxDFACqnuJouYTzsT5zd6s2ZEAHfRQFriVbjpFfJ1uWruHRRXIrFIma4PVuz-fp9_pBkA",
	size => 7684356,
	'time' => 1355666755,
	mtime => 1355566755,
	relfilename => 'def/abc',
	treehash => '1368761bd826f76cae8b8a74b3aae210b476333484c2d612d061d52e36af631a',
};



#
# kinda unit test
#
test_all_ok($data_sample);

#
# that's looks more like integration tests
#

# mtime formats

for my $mtime (qw/1355566755 -1969112106 +1355566755 -1 0 +0 -0 1/) {
	test_all_ok($data_sample, mtime => $mtime);
}

for my $mtime (qw/z тест 1111111111111111111111111111111111111111111111111111111111111 1+1/, '1,1', '1.1') {
	test_all_fails_for_create_A($data_sample, mtime => $mtime);
}

# time formats
for my $time (qw/1355566755 0 1/) {
	test_all_ok($data_sample, time => $time);
}

for my $time (qw/z тест 1111111111111111111111111111111111111111111111111111111111111 1+1/, '1,1', '1.1') {
	test_all_fails_for_create_A($data_sample, time => $time);
	test_all_fails_for_create_07($data_sample, time => $time);
	test_all_fails_for_delete($data_sample, time => $time);
	test_all_fails_for_retrieve($data_sample, time => $time);
}

# relfilename formats

for my $relfilename ('0', 'тест', 'тест/тест', 'a/b/c/d/e') {
	test_all_ok($data_sample, relfilename => $relfilename);
}

sub test_all_ok
{
	my ($data_sample, %override) = @_;
	my $data;
	%$data = %$data_sample;
	@$data{keys %override} = values %override;
	
	
	#
	# Test parsing line of Journal version 'A'
	#
	
	# CREATED /^A\t(\d+)\tCREATED\t(\S+)\t(\d+)\t(\d+)\t(\S+)\t(.*?)$/
	{
			my $J = Journal->new(journal_file=>'x', root_dir => $rootdir);
	
			my ($args, $filename);
			
			(my $mock = Test::MockModule->new('Journal'))->
				mock('_add_file', sub {	(undef, $filename, $args) = @_;	});
			
			$J->process_line("A\t$data->{time}\tCREATED\t$data->{archive_id}\t$data->{size}\t$data->{mtime}\t$data->{treehash}\t$data->{relfilename}");
			ok($args);
			ok( $args->{$_} eq $data->{$_}, $_) for qw/archive_id size time mtime treehash/;
			ok( $J->absfilename($filename) eq File::Spec->rel2abs($data->{relfilename}, $rootdir));
			is_deeply($J->{used_versions}, {'A'=>1});
	}
	
	# DELETED /^A\t(\d+)\tDELETED\t(\S+)\t(.*?)$/
	{
			my $J = Journal->new(journal_file=>'x', root_dir => $rootdir);
	
			my ($filename);
			
			(my $mock = Test::MockModule->new('Journal'))->
				mock('_delete_file', sub {	(undef, $filename) = @_;	});
			
			$J->process_line("A\t$data->{time}\tDELETED\t$data->{archive_id}\t$data->{relfilename}");
			ok(defined $filename);
			ok($filename eq $data->{relfilename});
			is_deeply($J->{used_versions}, {'A'=>1});
	}

	#  RETRIEVE_JOB
	{
			my $J = Journal->new(journal_file=>'x', root_dir => $rootdir);
	
			my ($time, $archive_id, $job_id);
			
			(my $mock = Test::MockModule->new('Journal'))->
				mock('_retrieve_job', sub {	(undef, $time, $archive_id, $job_id) = @_;	});
			
			$J->process_line("A\t$data->{time}\tRETRIEVE_JOB\t$data->{archive_id}\t$data->{job_id}");
			
			ok(defined($time) && $archive_id && $job_id);
			ok($time == $data->{time});
			ok($archive_id eq $data->{archive_id});
			ok($job_id eq $data->{job_id});
			is_deeply($J->{used_versions}, {'A'=>1});
	}

	#
	# Test parsing line of Journal version '0'
	#
	
		
	# CREATED /^(\d+)\s+CREATED\s+(\S+)\s+(\d+)\s+(\S+)\s+(.*?)$/
	{
			my $J = Journal->new(journal_file=>'x', root_dir => $rootdir);
	
			my ($args, $filename);
			
			(my $mock = Test::MockModule->new('Journal'))->
				mock('_add_file', sub {	(undef, $filename, $args) = @_;	});
			
			$J->process_line("$data->{time} CREATED $data->{archive_id} $data->{size} $data->{treehash} $data->{relfilename}");
			ok($args);
			ok( $args->{$_} eq $data->{$_}, $_) for qw/archive_id size time treehash/;
			ok( $J->absfilename($filename) eq File::Spec->rel2abs($data->{relfilename}, $rootdir));
			
			is_deeply($J->{used_versions}, {'0'=>1});
	}
	
	# DELETED /^\d+\s+DELETED\s+(\S+)\s+(.*?)$/
	{
			my $J = Journal->new(journal_file=>'x', root_dir => $rootdir);
	
			my ($filename);
			
			(my $mock = Test::MockModule->new('Journal'))->
				mock('_delete_file', sub {	(undef, $filename) = @_;	});
			
			$J->process_line("$data->{time} DELETED $data->{archive_id} $data->{relfilename}");
			ok(defined $filename);
			ok($filename eq $data->{relfilename});
			is_deeply($J->{used_versions}, {'0'=>1});
	}
	
	#  RETRIEVE_JOB
	{
			my $J = Journal->new(journal_file=>'x', root_dir => $rootdir);
	
			my ($time, $archive_id, $job_id);
			
			(my $mock = Test::MockModule->new('Journal'))->
				mock('_retrieve_job', sub {	(undef, $time, $archive_id, $job_id) = @_;	});
			
			$J->process_line("$data->{time} RETRIEVE_JOB $data->{archive_id}");
			
			ok(defined($time) && $archive_id);
			ok($time == $data->{time});
			ok($archive_id eq $data->{archive_id});
			ok(! defined $job_id);
			is_deeply($J->{used_versions}, {'0'=>1});
	}
	
}


sub test_all_fails_for_create_A
{
	my ($data_sample, %override) = @_;
	my $data;
	%$data = %$data_sample;
	@$data{keys %override} = values %override;
	
	
	#
	# Test parsing line of Journal version 'A'
	#
	
	# CREATED /^A\t(\d+)\tCREATED\t(\S+)\t(\d+)\t(\d+)\t(\S+)\t(.*?)$/
	{
			my $J = Journal->new(journal_file=>'x', root_dir => $rootdir);
	
			my $called = 0;
			
			(my $mock = Test::MockModule->new('Journal'))->
				mock('_add_file', sub {	$called = 1 });
			
			$J->process_line("A\t$data->{time}\tCREATED\t$data->{archive_id}\t$data->{size}\t$data->{mtime}\t$data->{treehash}\t$data->{relfilename}");
			ok(! $called);
			is_deeply($J->{used_versions}, {});
	}
	
	
}

sub test_all_fails_for_create_07
{
	my ($data_sample, %override) = @_;
	my $data;
	%$data = %$data_sample;
	@$data{keys %override} = values %override;
	

	#
	# Test parsing line of Journal version '0'
	#
	
		
	# CREATED /^(\d+)\s+CREATED\s+(\S+)\s+(\d+)\s+(\S+)\s+(.*?)$/
	{
			my $J = Journal->new(journal_file=>'x', root_dir => $rootdir);
	
			my $called = 0;
			
			(my $mock = Test::MockModule->new('Journal'))->
				mock('_add_file', sub {	$called = 1});
			
			$J->process_line("$data->{time} CREATED $data->{archive_id} $data->{size} $data->{treehash} $data->{relfilename}");
			ok(! $called);
			is_deeply($J->{used_versions}, {});
	}
	
}

sub test_all_fails_for_delete
{
	my ($data_sample, %override) = @_;
	my $data;
	%$data = %$data_sample;
	@$data{keys %override} = values %override;
	
	
	# DELETED /^A\t(\d+)\tDELETED\t(\S+)\t(.*?)$/
	{
			my $J = Journal->new(journal_file=>'x', root_dir => $rootdir);
	
			my $called = 0;
			
			(my $mock = Test::MockModule->new('Journal'))->
				mock('_delete_file', sub {	$called = 1});
			
			$J->process_line("A\t$data->{time}\tDELETED\t$data->{archive_id}\t$data->{relfilename}");
			ok (! $called);
			is_deeply($J->{used_versions}, {});
	}

	#
	# Test parsing line of Journal version '0'
	#
	
	
	# DELETED /^\d+\s+DELETED\s+(\S+)\s+(.*?)$/
	{
			my $J = Journal->new(journal_file=>'x', root_dir => $rootdir);
	
			my $called = 0;
			
			(my $mock = Test::MockModule->new('Journal'))->
				mock('_delete_file', sub {	$called = 1 });
			
			$J->process_line("$data->{time} DELETED $data->{archive_id} $data->{relfilename}");
			ok(! $called);
			is_deeply($J->{used_versions}, {});
	}
}

sub test_all_fails_for_retrieve
{
	my ($data_sample, %override) = @_;
	my $data;
	%$data = %$data_sample;
	@$data{keys %override} = values %override;
	
	
	# DELETED /^A\t(\d+)\tDELETED\t(\S+)\t(.*?)$/
	{
			my $J = Journal->new(journal_file=>'x', root_dir => $rootdir);
	
			my $called = 0;
			
			(my $mock = Test::MockModule->new('Journal'))->
				mock('_retrieve_job', sub {	$called =1 });
			
			$J->process_line("A\t$data->{time}\tRETRIEVE_JOB\t$data->{archive_id}\t$data->{job_id}");
	
			ok (!$called);		
			is_deeply($J->{used_versions}, {});
	}

	#
	# Test parsing line of Journal version '0'
	#
	
	
	# DELETED /^\d+\s+DELETED\s+(\S+)\s+(.*?)$/
	{
			my $J = Journal->new(journal_file=>'x', root_dir => $rootdir);
	
			my $called = 0;
			
			(my $mock = Test::MockModule->new('Journal'))->
				mock('_retrieve_job', sub {	$called =1 });
			
			$J->process_line("$data->{time} RETRIEVE_JOB $data->{archive_id}");
			
			ok (!$called);		
			is_deeply($J->{used_versions}, {});
	}
}

1;

