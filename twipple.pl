#!/usr/bin/env perl
use strict;
use warnings;

use 5.16.0;
#use Perl6::Say;
use YAML;

use Path::Class;
use Furl;
use WWW::Mechanize;
use WWW::Mechanize::AutoPager;
use HTML::TreeBuilder::XPath;
use HTML::Selector::XPath qw(selector_to_xpath);
use Log::Minimal;
$Log::Minimal::COLOR = 1;
$Log::Minimal::AUTODUMP = 1;

my $screen_name = shift or die "usage: perl $0 twipleid";

my $f = Furl->new;
my $base = 'http://p.twpl.jp/show/orig/';
my $dir = dir('twipple', $screen_name);
$dir->mkpath unless -d $dir;

my $mech = WWW::Mechanize->new;
$mech->autopager->add_site(
    url         => 'http://p.twipple.jp/user/.+',
    nextLink    => 'id("nextFoot")//a[contains(text(),"next")]',
    pageElement => 'id("mypage")',
);

my $xpath = selector_to_xpath('div.photoList');

my $res = $mech->get("http://p.twipple.jp/user/$screen_name/detail");
store($res);

while (my $link = $mech->next_link()) {
    my ($n) = ($link =~ m!/(\d+)!);
    say $link;
    my $res = $mech->get($link);
#    store($res, $n);
}

sub store {
    my ($res, $n) = @_;

    $n //= 1;

    my $subdir = $dir;#->subdir($n);
    $subdir->mkpath unless -d $subdir;

    my $content = $res->content;
    my $tree = HTML::TreeBuilder::XPath->new;
    $tree->parse($content);
    $tree->eof;
    my @nodes = $tree->findnodes($xpath);

    for my $tr (@nodes) {
        my ($id) = ($tr->attr('id') =~ /pic_(\w+)/);

        my $uri = $base . $id;

        my $fres = $f->get($uri);

        if ($fres->is_success) {
            my $fh = $subdir->file("$id.jpg")->openw;
            binmode $fh;
            print $fh $fres->body;
            close $fh;
        }
    }
}
