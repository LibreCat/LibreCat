#!/usr/bin/env perl

use Dancer;
use FindBin qw($Bin);

BEGIN {
    if (config->{environment} eq 'development') {
        set appdir => "$Bin/..";
        set upload_dir => "$Bin/../uploads";
        set tmp_dir => "$Bin/../tmp";
    }
}

use App;

dance;
