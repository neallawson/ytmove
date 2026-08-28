#!/usr/bin/perl

use strict;
use warnings;
use File::Spec;
use File::Basename qw(dirname);
use Test::More;

# Locate ytmove.pl relative to this test file
my $script_dir = dirname(File::Spec->rel2abs(__FILE__));
my $ytmove_path = File::Spec->catfile(dirname($script_dir), 'ytmove.pl');

require $ytmove_path;

subtest 'Bracketed ID Extraction' => sub {
    my ($id, $src) = extract_youtube_id('Video Title [dQw4w9WgXcQ].mp4');
    is($id, 'dQw4w9WgXcQ', 'Extracted bracketed ID');
    is($src, 'bracket', 'ID source is bracket');

    ($id, $src) = extract_youtube_id('[dQw4w9WgXcQ].m4a');
    is($id, 'dQw4w9WgXcQ', 'Extracted bare bracketed ID');

    ($id, $src) = extract_youtube_id('[1080p] My Video [abc12345678].mkv');
    is($id, 'abc12345678', 'Extracted last bracketed 11-char token when multiple brackets present');
};

subtest 'Dash Suffix ID Extraction' => sub {
    my ($id, $src) = extract_youtube_id('Artist - Song Title-xyz98765432.mp4');
    is($id, 'xyz98765432', 'Extracted dash suffix ID');
    is($src, 'dash', 'ID source is dash');

    ($id, $src) = extract_youtube_id('Track-a_b-c123456.webm');
    is($id, 'a_b-c123456', 'Extracted dash suffix ID containing hyphens and underscores');
};

subtest 'URL Parameter ID Extraction' => sub {
    my ($id, $src) = extract_youtube_id('https://www.youtube.com/watch?v=dQw4w9WgXcQ');
    is($id, 'dQw4w9WgXcQ', 'Extracted ID from simple URL query param');
    is($src, 'url', 'ID source is url');

    ($id, $src) = extract_youtube_id('https://youtube.com/watch?feature=shared&v=abc12345678&t=120');
    is($id, 'abc12345678', 'Extracted ID from URL query param with multiple parameters');
};

subtest 'Raw ID Extraction' => sub {
    my ($id, $src) = extract_youtube_id('dQw4w9WgXcQ');
    is($id, 'dQw4w9WgXcQ', 'Extracted raw 11-char ID');
    is($src, 'raw', 'ID source is raw');

    ($id, $src) = extract_youtube_id('  abc12345678  ');
    is($id, 'abc12345678', 'Extracted raw ID after trimming whitespace');
};

subtest 'Invalid and Edge Cases' => sub {
    my ($id, $src) = extract_youtube_id(undef);
    is($id, undef, 'Undef input returns undef ID');
    is($src, 'none', 'ID source is none');

    ($id, $src) = extract_youtube_id('');
    is($id, undef, 'Empty input returns undef ID');

    ($id, $src) = extract_youtube_id('   ');
    is($id, undef, 'Whitespace input returns undef ID');

    ($id, $src) = extract_youtube_id('Just Some Video Title.mp4');
    is($id, undef, 'Title without matching ID format returns undef');

    ($id, $src) = extract_youtube_id('Video [TooLongID123456].mp4');
    is($id, undef, 'Bracketed token of wrong length (not 11 chars) ignored');

    ($id, $src) = extract_youtube_id('ShortID-1234.mp4');
    is($id, undef, 'Dash suffix of wrong length ignored');
};

done_testing();
