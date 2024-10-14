#!/usr/bin/perl -w
# Generate table of collision polygon coordinates.

use strict;
use constant PI => 3.14159265358979323846264338327950288419716939937510;

use constant ROTATION_STEPS => 36;
use constant BAR_WIDTH => 112;
use constant BAR_HEIGHT => 27;
use constant CUP_WIDTH => 110;
use constant CUP_HEIGHT => 45;
use constant SQUARE_WIDTH => 97;
use constant SQUARE_HEIGHT => 60;


# Return rotated (x,y) coordinate values, formatted as "{rx,ry}".
sub rotate($$$)
{
   my ($x, $y, $a) = @_;

   my $ca = cos($a);
   my $sa = sin($a);
   my $rx = $x * $ca - $y * $sa;
   my $ry = $x * $sa + $y * $ca;
   return "{$rx, $ry}";
}

# Generate bounding quad coordinate offsets for a single object type.
sub generate_table($$$)
{
   my ($label, $width, $height) = @_;

   print "$label =\n{\n";
   for(my $angle = 0; $angle < ROTATION_STEPS; $angle++)
   {
      my $a = $angle * PI * 2.0 / ROTATION_STEPS;
      print "\t{\n",
            "\t\t", rotate($width / 2, -$height / 2, $a), ",\n",
            "\t\t", rotate($width / 2, $height / 2, $a), ",\n",
            "\t\t", rotate(-$width / 2, $height / 2, $a), ",\n",
            "\t\t", rotate(-$width / 2, -$height / 2, $a), "\n",
            "\t},\n";
   }
   print "}\n";
}

generate_table("bar_poly", BAR_WIDTH, BAR_HEIGHT);
generate_table("cup_poly", CUP_WIDTH, CUP_HEIGHT);
generate_table("square_poly", SQUARE_WIDTH, SQUARE_HEIGHT);
