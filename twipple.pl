#!/usr/bin/env perl
use strict;
use warnings;

use Path::Tiny;
use Furl;
use WWW::Mechanize;
use WWW::Mechanize::AutoPager;
use Web::Query;
use DateTime::Format::Strptime;
use Log::Minimal;

my $screen_name = shift or die "usage: perl $0 twipleid";

my $f = Furl->new;
my $base = 'http://p.twpl.jp/show/orig/';
my $dir = path('twipple_photo', $screen_name);
$dir->mkpath unless -d $dir;

my $mech = WWW::Mechanize->new;
$mech->autopager->add_site(
    url         => 'http://p.twipple.jp/user/.+',
    nextLink    => 'id("nextFoot")//a[contains(text(),"next")]',
    pageElement => 'id("mypage")',
);

my $fmt = '%b %d, %Y at %I:%M %p %Z';
my $strp = DateTime::Format::Strptime->new(
    pattern   => $fmt,
    locale    => 'en_US',
    time_zone => 'Asia/Tokyo',
    on_error  => 'croak',
);

my $res = $mech->get("http://p.twipple.jp/user/$screen_name/detail");
store($res);

while (my $link = $mech->next_link()) {
    sleep 5;
    my ($n) = ($link =~ m!/(\d+)!);
    infof $link;
    my $res = $mech->get($link);
    store($res, $n);
}

sub store {
    my ($res, $n) = @_;

    $n //= 1;

    my $content = $res->content;

    wq($content)
        ->find('.photoList')
        ->each(sub {
            my $i = shift;
            my ($photo_id) = ($_->attr('id') =~ /\Apic_thumb_(\w+)\z/);

            my $date = $_->find('.photoDetail > span:nth-child(2)')->text();
               $date =~ s/\A\s*|\s*\z//g;
            my $dt = $strp->parse_datetime($date);

            my $uri = $base . $photo_id;

            infof '%s %s', $dt->datetime, $uri;

            my $fres = $f->get($uri);

            if ($fres->is_success) {
                my $fh = $dir->child($dt->ymd('-') . '-' . $dt->hms('-') . '_' . $photo_id . '.jpg')->openw;
                binmode $fh;
                print $fh $fres->body;
                close $fh;
            }
        });
}
