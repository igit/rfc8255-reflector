#!/usr/bin/perl -W

#
# First written by Alexandre SIMON (https://github.com/igit) 
# during the #IETFHackathon [1] of the #IETF101 [2].
# [1] : https://trac.ietf.org/trac/ietf/meeting/wiki/101hackathon
# [2] : https://www.ietf.org/how/meetings/101/
#
# Please refer to https://github.com/igit/rfc8255-reflector/blob/master/README.md
# to see details and howto use it
#

use strict;
use MIME::Parser;
use MIME::Entity;
use Encode qw(:all);
use LWP::UserAgent;
use URI::Encode qw(uri_encode);
use JSON;



###############################################################################
##### CONFIG
###############################################################################

my $DEBUG    = 1;
my $LOG_FILE = "/tmp/rfc8255-reflector.log";
my $MIME_Parser_tempdir = "/tmp";
my $SEND_RESPOND_METHOD = "sendmail"; # sendmail | smtp


###############################################################################
##### MAIN
###############################################################################

logme("\n\n\n>> ###############################################################################\n");
logme(">> New script call...\n\n");


###### Parse email from STDIN
my $parser = new MIME::Parser; $parser->output_under($MIME_Parser_tempdir);
my $in = $parser->parse(\*STDIN);

logme(">> Original mail :\n");
logme($in->stringify);


##### Skip bounced mail
if($in->head->get('From') =~ /(mailer-daemon|postmaster|^$|^<>$)/i) {
    my $from = $in->head->get('From');
    chomp $from;
    logme("\n\n>> Skipping mail >> From: ".$from."\n");
    exit(0);
}


##### extract languages from To: field
my $sl  = "en";
my $tls = [];

if($in->head->get('To') =~ /(?:^|<)[^\+]+(\+.+)*\@.+(?:>|$)/) {
    foreach my $plus (split /\+/,$1) {
	if($plus=~/^sl_(.+)$/) {
	    $sl = $1;
	}

	if($plus=~/^tl_(.+)$/) {
	    push @{$tls}, $1;
	}
    }
}

if(scalar(@{$tls}) == 0) {
    $tls = [ "fr" ];
}
logme("\n\n>> Extracted languages from To: => \$sl=$sl \$tls=".(join ",", @{$tls})."\n");


##### find one text/plain part
my $BODY = undef;
my $CONTENT_TYPE = undef;
if(($in->parts == 0) && ($in->head->get('Content-Type') =~ /text\/plain/)) {
    $BODY = decode_body($in->head->get('Content-Type'), $in->body);
    $CONTENT_TYPE = $in->head->get('Content-Type');
} else {

    for(my $i=0 ; $i<$in->parts ; $i++) {
	my $part = $in->parts($i);
	if($part->head->get('Content-Type') =~ /text\/plain/) {
	    $BODY = decode_body($part->head->get('Content-Type'), $part->body);
	    $CONTENT_TYPE = $part->head->get('Content-Type');
	    last;
	}
    }

}

if(not defined $BODY) {
    $BODY = [ "No text plain found in original email.\n",
	      "Please retry.\n"];
    $CONTENT_TYPE = "text/plain; charset=utf-8\n";
}


##### build top part and "preface"
my $top = MIME::Entity->build(
    Type    => 'multipart/multilingual',
    From    => $in->head->get('From'),
    To      => $in->head->get('From'),
    Subject => $in->head->get('Subject'),
    );


$top->attach(
    # first part is the "preface"
    Type  => 'text/plain; charset=utf-8',
    Data  => encode_body('utf-8', $BODY)
    );


$top->attach(
    # original message
    Type                       => 'message/rfc822',
    'Content-Language'         => $sl,
    'Content-Translation-Type' => 'original',
    Data                       => [ "Content-Type: text/plain; charset=utf-8\n",
				    "From: ".$in->head->get('From'),
				    "Subject: ".$in->head->get('Subject'),
				    "\n",
				    @{encode_body('utf-8',$BODY)}
    ]);


##### try to translate it
foreach my $tl (@{$tls}) {
    my $tmp_subject = $in->head->get('Subject'); $tmp_subject =~ s/\n//g; $tmp_subject = decode("MIME-Header", $tmp_subject);
    my $translated_subject = translate( $sl, $tl, $tmp_subject);
    my $translated_body    = translate( $sl, $tl, (join "", @{$BODY}));

    if(defined $translated_subject && defined $translated_body) {

	logme("\n\n>> Translated subject from $sl to $tl :\n");
	logme(encode_utf8 $translated_subject);

	logme("\n\n>> Translated body from $sl to $tl :\n");
	logme(encode_utf8 $translated_body);

	## translated
	$top->attach(
	    Type                       => 'message/rfc822',
	    'Content-Language'         => $tl,
	    'Content-Translation-Type' => 'automated',
	    Data                       => [ "Content-Type: text/plain; charset=utf-8\n",
					    "From: ".$in->head->get('From'),
					    "Subject: ".encode("MIME-Header",$translated_subject)."\n",
					    "\n",
					    map { encode_utf8 $_."\n" } split /\n/, $translated_body
	    ]);
    }
}


##### last part is "The Language-Independent Message Part"
my $ascii_art = <<'END_ART';
        __..._   _...__
    _..-"      `Y`      "-._
    \           | Multi-    /
    \\  RFC8255 | lingual  //
    \\\         | E-mail  ///
     \\\ _..---.|.---.._ ///
      \\`_..---.Y.---.._`//
       '`               `'

END_ART

$top->attach(
    # language-independent
    Type                       => 'message/rfc822',
    'Content-Language'         => 'zxx',
    'Content-Translation-Type' => 'human',
    Data                       => [ "Content-Type: text/plain; charset=utf-8\n",
				    "\n",
				    (map { encode_utf8 $_."\n" } split /\n/, $ascii_art)
    ]);


##### translated email is completed
logme("\n\n>> Translated mail :\n");
logme($top->stringify);


##### send translated mail to original sender
logme("\n\n>> Sending translated mail to ".$top->head->get('To'));
if($SEND_RESPOND_METHOD eq "smtp") {
    $top->smtpsend();
} else {
    $top->send();
}


###### clean MIME::Parser files
$parser->filer->purge();


###### Job's done. By-bye.
exit(0);




###############################################################################
##### FUNCTIONS
###############################################################################

sub translate {
    my $sl   = shift; # source language
    my $tl   = shift; # to language
    my $text = shift; # text to translate

    my $ua = LWP::UserAgent->new; $ua->agent('');

    ## look there for Google transalte APIt options https://stackoverflow.com/questions/26714426/what-is-the-meaning-of-google-translate-query-params
    my $uri = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=$sl&tl=$tl&dt=t&ie=utf-8&oe=utf-8&q=".uri_encode($text,{encode_reserved=>1});
    my $response = $ua->get($uri);

    if($response->is_success) {
	logme(">> Got response !\n");
	my @lines = ();
	foreach my $r (@{(decode_json $response->decoded_content)->[0]}) {
	    push @lines, $r->[0];
	}
	return (join "", @lines);
    }
    else {
	logme(">> Something go wrong with Google translate : ".$response->status_line."\n");
    }

    return undef;
} ## sub translate


sub decode_body {
    my $content_type = shift;
    my $body = shift;
    my $charset = "utf-8";

    if($content_type=~/charset=(.+)(^| |;|\n)/) {
	$charset = $1;
    }

    my $ret = [];
    foreach my $line (@{$body}) {
	push @{$ret}, (decode($charset,$line));
    }

    return $ret;
} ## sub decode_body


sub encode_body {
    my $content_type = shift;
    my $body = shift;
    my $charset = "utf-8";

    if($content_type=~/charset=(.+)(^| |;|\n)/) {
	$charset = $1;
    }

    my $ret = [];
    foreach my $line (@{$body}) {
	push @{$ret}, (encode($charset,$line));
    }

    return $ret;
} ## sub encode_body


sub logme {
    my $t = shift;
    if($DEBUG) {
	open  LOG, ">>$LOG_FILE";
	print LOG $t;
	close LOG;
    }
} ## logme
