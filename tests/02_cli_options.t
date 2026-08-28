#!/usr/bin/perl

use strict;
use warnings;
use File::Spec;
use File::Basename qw(dirname);
use File::Temp qw(tempdir);
use Test::More;

my $script_dir = dirname(File::Spec->rel2abs(__FILE__));
my $ytmove_path = File::Spec->catfile(dirname($script_dir), 'ytmove.pl');

subtest 'Missing Arguments Validation' => sub {
    my $output = `perl "$ytmove_path" 2>&1`;
    my $exit_code = $? >> 8;
    isnt($exit_code, 0, 'Exits with non-zero status when missing required options');
    like($output, qr/Both -s .* and -d .* options are required/i, 'Logs missing required options warning');
};

subtest 'Non-existent Source Directory' => sub {
    my $tmp_dest = tempdir(CLEANUP => 1);
    my $non_existent_src = File::Spec->catdir($tmp_dest, 'no_such_source_folder');

    my $output = `perl "$ytmove_path" -s "$non_existent_src" -d "$tmp_dest" 2>&1`;
    my $exit_code = $? >> 8;
    isnt($exit_code, 0, 'Exits with non-zero status when source dir does not exist');
    like($output, qr/Source directory .* does not exist/i, 'Error message mentions missing source directory');
};

subtest 'Non-existent Destination Directory' => sub {
    my $tmp_src = tempdir(CLEANUP => 1);
    my $non_existent_dest = File::Spec->catdir($tmp_src, 'no_such_dest_folder');

    my $output = `perl "$ytmove_path" -s "$tmp_src" -d "$non_existent_dest" 2>&1`;
    my $exit_code = $? >> 8;
    isnt($exit_code, 0, 'Exits with non-zero status when destination dir does not exist');
    like($output, qr/Destination directory .* does not exist/i, 'Error message mentions missing destination directory');
};

subtest 'Help Option (-h)' => sub {
    my $output = `perl "$ytmove_path" -h 2>&1`;
    like($output, qr/Usage:/i, 'Prints usage synopsis on -h');
    like($output, qr/--source/i, 'Prints options documentation on -h');
};

done_testing();
