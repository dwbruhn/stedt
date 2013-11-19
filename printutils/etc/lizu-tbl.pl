#!/usr/bin/perl

# lizu-tbl.pl
# by Dominic Yu
# 2008.12.07
# ----------
# This generates a document extracting
# ZMYYC and TBL (and others) from the database.

use strict;
use utf8;
use Encode;
#use SyllabificationStation;

use DBI;

my %lgs;
%lgs = (
	8 => 'Q',
	9 => 'PML',
	10 => 'PMJ',
	11 => 'rG',
	12 => 'DF',
	13 => 'QY',
	14 => 'ẐB',
	15 => 'MÑ',
	16 => 'GQ',
	17 => 'ŜX',
	18 => 'LS',
	46 => 'NŹ',
);

my $lgids = join ' OR ', map {'lgid=' . (1800+$_) } (5,6,7,8,9,10,11,12,13,44,52,53);

binmode(STDOUT, ":utf8");

my @roots;
@roots = split /\n/, <<'EOF';
*-a
AXE
BAMBOO
BEE
BITTER
BORROW, LEND
BUCKWHEAT
CARRY ON BACK
CHILD
CHIN
CHINESE
COME
CROW
DITCH
EAR
EARTH
GROUND
EAT
EDGE
ENEMY
FIELD
FISH
FIVE
FORGET
FULL, SATIATED
GNAW
GOD, DEITY
GOOD
HAMMER
HOT
HUNDRED
I / ME
ILL / SICK
LAUGH
LISTEN
LOVE
MEAT, FLESH
MONTH
MOON
MOTHER
NEGATIVE
NEGATIVE IMPERATIVE
NOSE
PAIN, ACHE
PATCH
PUT, PLACE
RABBIT
REST
SALT
SINEW
SNOW
FROST
SON
SOUL, SPIRIT
SPARROW
STRENGTH
TIGER
TONGUE
TROUSERS, PANTS
TRUNK, BOX
*-wa
CATTLE (COMMON)
FOX
HANDSPAN
HOOF
RAIN
TOOTH
WEAR/PUT ON
*-i
CATCH
COUNT
DEW
EARTH
PERSON
RED
WOMAN
*-u
ELBOW
GHOST, DEMON
GRANDFATHER
MAD PERSON
SOUL, SPIRIT
WHITE
WHO
*-ey
FIRE
FRUIT
KNOW
LADDER
NEAR
ROPE
*-ow
NIT
THORN
*-əy
BOW (WEAPON)
COMB N.
DEER
DIE
DUNG, MANURE
EXCREMENT
FOOT
FLEA
FOUR
GRASS
HEAVY
LIQUOR
MELT
ROT, SPOIL
SKIN
STAR
DAY (24 HOURS)
SUN
UNTIE
WASH (CLOTHES)
WIND
*-wəy
BLOOD
DAUGHTER-IN-LAW
DOG
FAR
SWEAT
*-əw
BREAST
FINGER
GREEN
HORN
INSECT, WORM
MUSHROOM
NINE
PIGEON
PRICE
RAT, MOUSE
SKY
SMOKE
STEAL
SWEET
WEEP
*-ay
BRAN
EXCHANGE
EXIST, BE PRESENT
FLAT, LEVEL(LAND)
LEFT
STING  (V.)
TAIL
*-aw
HEAD
*-ar
FROST
LOUSE
*-ur
SOUR
*-al
FROG
*-ul
HAIR/FUR
HAIR OF HEAD
SILVER
SNAKE
*-aŋ
CHEST (BODY)
CLASSIFIER FOR TREES
DEAF PERSON
DREAM
EAGLE
HORSE
PINE
SHEEP
GOAT, SHEEP (GENERIC)
WAIT
YOU (SG.)
*-an
GARLIC
MEDICINE
STRAIN/FILTER (TEA)
*-am
BEAR N.
BELLY
BRIDGE
DARE
EAR (OF GRAIN-PRODUCING PLANT)
FATHOM=6 FEET
FLY (V.)
GARDEN (VEGETABLE)
IRON
OTTER
SMELL V.
STINKY
WHITE
*-iŋ
FLUTE
HEART
LONG
NAME
PUS
WOOD
FIREWOOD
*-in
COOKED/RIPE
LIVER
WEIGH V.T.
*-im
CLOUD
FOG
HOUSE
RAW
SET (OF THE SUN)
*-uŋ/*-oŋ
ACRE
ESCAPE
MAGGOT
STONE, ROCK
THOUSAND
WING
*-um
MORTAR
PAIR
PILLOW
THREE
USE
WARM (ONESELF) NEAR FIRE
*-en
CLAW
FINGERNAIL
*-ak
ANT
BLACK
BOWL
BRANCH
CHICKEN
COOK, BOIL (RICE)
DEEP
DESCEND
DRIP / DROP (N.)
LEAK
DROP, FALL
EARLY
MORNING
EXPENSIVE
EYE
HAND
JUMP
LEAF
LICK
NIGHT
PIG
PUSH
RAT, MOUSE
SOLDIER
SON-IN-LAW
WEAVE
*-at
EIGHT
HUNGRY
KILL
LEECH
PUT ON, WEAR
VOMIT
*-ap
ENTER
FIREPLACE
NEEDLE
SHOOT
SNOT
STAND
WEEP
*-ik
INTESTINES
ITCH
LEOPARD
LOUSE
NEW
PHEASANT
*-it
CLOSE (EYE)
GOAT
*-ip
SLEEP
*-uk/*-ok
CROOKED
ENCLOSURE (FOR CATTLE)
ENTER
FEAR
MONKEY
POISON
PRICK
SIX
WAIST
WOOD
YEAR
*-ut
FIST
BLOW (OF WIND)
*-up
ROT, SPOIL
WEST
*-is
GALL
SEVEN
TWO
EOF

my $dbh = connectdb();
my $n;

foreach (@roots) {
	next if /^$/;
	if (/^\*/) {
		print "$_\n";
		next;
	}
	print "$_\n";
	s/\(.*//;	# chop off everything after parens
	my $glosses = join ' OR ', map {"gloss RLIKE '^${_}[[:>:]]'"} split /\s*(,|\/)\s*/;
	
	my $sql = <<EndOfSQL;
SELECT DISTINCT reflex, gloss, srcid
  FROM lexicon
  WHERE (($glosses)
    AND reflex != '*'
    AND ($lgids))
  ORDER BY srcid
EndOfSQL
			
	my $recs = $dbh->selectall_arrayref($sql);
	for my $rec (@$recs) {
		$_ = decode_utf8($_) foreach @$rec; # do it here so we don't have to later
	}
	if (@$recs) {
		my $lastid = '';
		my $lastgloss = '';
		for my $rec (@$recs) {
			my ($s, $gloss, $srcid) = @$rec;
			my ($id, $lg) = split /\./, $srcid;
			$lg += 0;
			if ($id != $lastid) {
				$lastid = $id;
				$lastgloss = $gloss;
				print "#$id: '$gloss'\n";
			}
			print "$lgs{$lg}\t$s";
			print " '$gloss'" if $gloss ne $lastgloss;
			print "\n";
		}
	} else {
		# no records
		print "-\n";
	}
	print "\n";
	print STDERR ++$n . " done\n";
}

$dbh->disconnect;

# Returns a database connection
sub connectdb {
  my $host = 'localhost';
  my $db = 'stedt';
  my $db_user = 'root';
  my $db_password = '';

  my $dbh = DBI->connect("dbi:mysql:$db:$host", "$db_user",
			 "$db_password",
			 {RaiseError => 1,AutoCommit => 1})
    || die "Can't connect to the database. $DBI::errstr\n";
  # This makes the database connection unicode aware
  $dbh->do(qq{SET NAMES 'utf8';});
  return $dbh;
}
