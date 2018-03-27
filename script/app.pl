#!/usr/bin/env perl

use Catmandu::Sane;
use Path::Tiny;
use lib path(__FILE__)->parent->parent->child('lib')->stringify;
use Mojolicious::Commands;

Mojolicious::Commands->start_app('LibreCat::Application');
