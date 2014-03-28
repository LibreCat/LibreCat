#!/usr/bin/env perl

use Dancer;

#use App;

set environment => "development";

load_app 'App', prefix => '/myPUB';

dance;
