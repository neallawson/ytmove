#!/usr/bin/perl

use strict;
use warnings;
use File::Spec;
use File::Basename qw(dirname basename);
use File::Temp qw(tempdir);
use Test::More;

my $script_dir = dirname(File::Spec->rel2abs(__FILE__));
my $ytmove_path = File::Spec->catfile(dirname($script_dir), 'ytmove.pl');

# 1. Setup temporary source and destination directories
my $src_dir  = tempdir(CLEANUP => 1);
my $dest_dir = tempdir(CLEANUP => 1);

# 2. Populate source directory with mock files
my @mock_files = (
    'Track 1 [dQw4w9WgXcQ].mp4',
    'Track 1 [dQw4w9WgXcQ].m4a',
    'Artist - Track 2-xyz98765432.mkv',
    'Unrelated File.txt',
);

foreach my $file (@mock_files) {
    my $path = File::Spec->catfile($src_dir, $file);
    open(my $fh, '>', $path) or die "Cannot create mock file $path: $!";
    print $fh "dummy content for $file\n";
    close($fh);
}

# 3. Create input list with comments, blank lines, valid IDs, multiple matched files, and unmatched lines
my $input_content = <<"EOF";
# Top comment line
  
dQw4w9WgXcQ
https://www.youtube.com/watch?v=xyz98765432
notfound123
InvalidLineNoID
# Bottom comment line
EOF

# 4. Pipe input into ytmove.pl
my $cmd = "perl \"$ytmove_path\" -s \"$src_dir\" -d \"$dest_dir\"";
open(my $pipe, '|-', $cmd) or die "Cannot open pipe to ytmove.pl: $!";
print $pipe $input_content;
close($pipe);
my $exit_code = $? >> 8;

is($exit_code, 0, 'ytmove.pl executed successfully');

# 5. Assert file movements
ok(-f File::Spec->catfile($dest_dir, 'Track 1 [dQw4w9WgXcQ].mp4'), 'Moved mp4 file to destination');
ok(-f File::Spec->catfile($dest_dir, 'Track 1 [dQw4w9WgXcQ].m4a'), 'Moved m4a file to destination');
ok(-f File::Spec->catfile($dest_dir, 'Artist - Track 2-xyz98765432.mkv'), 'Moved mkv file to destination');

ok(! -f File::Spec->catfile($src_dir, 'Track 1 [dQw4w9WgXcQ].mp4'), 'Removed mp4 file from source');
ok(! -f File::Spec->catfile($src_dir, 'Track 1 [dQw4w9WgXcQ].m4a'), 'Removed m4a file from source');
ok(! -f File::Spec->catfile($src_dir, 'Artist - Track 2-xyz98765432.mkv'), 'Removed mkv file from source');

ok(-f File::Spec->catfile($src_dir, 'Unrelated File.txt'), 'Unrelated file remained in source');

# 6. Locate log file in source directory
opendir(my $dh, $src_dir) or die "Cannot open source directory: $!";
my ($log_file) = grep { /^ytmove_log_.*\.txt$/ } readdir($dh);
closedir($dh);

ok($log_file, 'Log file created in source directory');

my $log_path = File::Spec->catfile($src_dir, $log_file);
open(my $log_fh, '<', $log_path) or die "Cannot open log file $log_path: $!";
my @log_lines = <$log_fh>;
close($log_fh);
chomp @log_lines;

# 7. Assertions on log file contents and line counts
# Total lines expected: 11 lines (Header: 4, Index: 1, Status entries: 5, Summary: 1)
is(scalar(@log_lines), 11, 'Log file contains exactly 11 lines');

my @moved_lines    = grep { /\] MOVED:/ } @log_lines;
my @not_found_lines = grep { /\] NOT FOUND:/ } @log_lines;
my @warn_lines      = grep { /\] WARN:/ } @log_lines;
my @summary_lines   = grep { /\] === Summary:/ } @log_lines;

is(scalar(@moved_lines), 3, 'Log file has 3 MOVED status lines corresponding to each moved file');
is(scalar(@not_found_lines), 1, 'Log file has 1 NOT FOUND status line for unmatched YouTube ID');
is(scalar(@warn_lines), 1, 'Log file has 1 WARN status line for unparseable input line');
is(scalar(@summary_lines), 1, 'Log file contains 1 summary line');

# Total status lines = moved (3) + not_found (1) + warn (1) = 5
my $status_lines_count = @moved_lines + @not_found_lines + @warn_lines;
is($status_lines_count, 5, 'Log file has exactly 5 status lines covering all matching files and active inputs');

# Verify summary footer counters
like($summary_lines[0], qr/Lines processed:\s*4/, 'Summary correctly reports 4 lines processed');
like($summary_lines[0], qr/Files moved:\s*3/, 'Summary correctly reports 3 files moved');
like($summary_lines[0], qr/Unmatched\/Errors:\s*2/, 'Summary correctly reports 2 unmatched/errors');

done_testing();
