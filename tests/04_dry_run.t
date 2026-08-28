#!/usr/bin/perl

use strict;
use warnings;
use File::Spec;
use File::Basename qw(dirname);
use File::Temp qw(tempdir);
use Test::More;

my $script_dir = dirname(File::Spec->rel2abs(__FILE__));
my $ytmove_path = File::Spec->catfile(dirname($script_dir), 'ytmove.pl');

subtest 'Dry-Run Mode (-n)' => sub {
    my $src_dir  = tempdir(CLEANUP => 1);
    my $dest_dir = tempdir(CLEANUP => 1);

    my $filename = 'DryRun Test [dQw4w9WgXcQ].mp4';
    my $src_file = File::Spec->catfile($src_dir, $filename);
    open(my $fh, '>', $src_file) or die "Cannot create mock file $src_file: $!";
    print $fh "content\n";
    close($fh);

    my $cmd = "perl \"$ytmove_path\" -s \"$src_dir\" -d \"$dest_dir\" -n 2>&1";
    open(my $pipe, '|-', $cmd) or die "Cannot open pipe to ytmove.pl: $!";
    print $pipe "dQw4w9WgXcQ\n";
    close($pipe);

    # File should remain in source and NOT be in dest
    ok(-f $src_file, 'File remains in source folder during dry-run');
    ok(! -f File::Spec->catfile($dest_dir, $filename), 'File is NOT copied to destination folder during dry-run');

    # Inspect log file
    opendir(my $dh, $src_dir) or die "Cannot open source directory: $!";
    my ($log_file) = grep { /^ytmove_log_.*\.txt$/ } readdir($dh);
    closedir($dh);

    ok($log_file, 'Log file created during dry-run');
    my $log_path = File::Spec->catfile($src_dir, $log_file);
    open(my $log_fh, '<', $log_path) or die "Cannot open log file: $!";
    my @lines = <$log_fh>;
    close($log_fh);

    my @dry_run_lines = grep { /DRY-RUN: Would move/ } @lines;
    is(scalar(@dry_run_lines), 1, 'Log file contains DRY-RUN status entry');
};

subtest 'Verbose Mode (-v)' => sub {
    my $src_dir  = tempdir(CLEANUP => 1);
    my $dest_dir = tempdir(CLEANUP => 1);

    my $filename = 'Verbose Test [xyz98765432].mkv';
    my $src_file = File::Spec->catfile($src_dir, $filename);
    open(my $fh, '>', $src_file) or die "Cannot create mock file $src_file: $!";
    print $fh "content\n";
    close($fh);

    my $cmd = "perl \"$ytmove_path\" -s \"$src_dir\" -d \"$dest_dir\" -v";
    open(my $pipe, '|-', $cmd) or die "Cannot open pipe: $!";
    print $pipe "xyz98765432\n";
    close($pipe);

    ok(-f File::Spec->catfile($dest_dir, $filename), 'File moved to destination in verbose mode');
};

done_testing();
