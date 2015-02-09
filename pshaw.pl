#!/usr/bin/perl

#
# pshaw - A shell written in Perl. Why not?
#

use POSIX;
use Env;          #Import all of the user's environment variables as Perl variables
use Data::Dumper;

#use lib 'include';

require 'sys/syscall.ph';

sub processBuiltin {
   my $function = shift;
   my @args = @_;

   # Do the command and return 1 if the command was processed, otherwise return 0.

   if ($function eq "exit") {
      exit join(" ", @args);
   }

   if ($function eq "print") {
      eval { $function." ".join(" ", @args) };
      return 1;
   }

   if ($function eq "cd") {
      chdir $args[0];
      return 1;
   }

   return 0;
}

sub processRedirects {
   my @input = @_;

   #FIXME: This won't work if there are spaces around the redirect operator.

   #print Dumper(@input);

   for (my $i=0; $i <= scalar(@input); $i++) {
      print STDERR $input[$i]."\n";

      # Scan for any redirect operators
      if ($input[$i] =~ m/[<>]+&*/) {
         #print STDERR "Found a redirect: $input[$i]\n";
         # Parse the redirect
         $input[$i] =~ m/(&*)(.*)([<>]+)(&*)(.*)/;
         my $srcmode = $1;
         my $src = $2;
         my $op = $3;
         my $dstmode = $4;
         my $dst = $5;

         $src = 1 if ((! $src) && ($op eq ">"));
         $src = 0 if ((! $src) && ($op eq "<"));

         if ($src == 0) {
            close(STDIN);
            open(STDIN, $op.$dstmode, $dst);
         } elsif ($src == 1) {
            close(STDOUT);
            open(STDOUT, $op.$dstmode, $dst);
         } elsif ($src == 2) {
            close(STDERR);
            open(STDERR, $op.$dstmode, $dst);
         }

         splice(@input, $i, 1); # Delete this element from the array
         $i--;
      }
   }

   #print Dumper(@input);
   return @input;
}

sub prompt {
   # Print a prompt
   print "pshaw> \$ ";
}

prompt;

while ($inputstr = <>) {
   # Main Loop

   chomp $inputstr;
   my @input = split(" ", $inputstr);

   if ($inputstr =~ m/^\s*$/) {
      prompt;
      next;
   }


   # If the command is a builtin, then process it.
   unless ( processBuiltin( @input ) ) {
      # The command was not a builtin. Start doing the fun stuff.

      my $pid = fork();
      if ($pid) {
         # parent
         wait;
      } elsif ($pid == 0) {
         # child

         # Handle redirection - Search the input for redirection operators, handle them, then delete them from the input.
         @input = processRedirects( @input );

         # Locate the file on the disk for the executable
         if ( $input[0] =~ m#^/# ) {
            # The command starts with a /, so the path is absolute
         } elsif ( $input[0] =~ m#/# ) {
            # The command doesn't begin with /, but contains /, so the path is relative
            # Make it absolute.
            $input[0] = $PWD . "/" . $input[0];
         } else {
            # Search the PATH for the command
            foreach my $pathel (split(":", $PATH)) {
               if (stat($pathel . "/" . $input[0])) {
                  $input[0] = $pathel . "/" . $input[0];
                  break;
               }
            }
         }
   
         # Make sure the file really exists
         unless (stat($input[0])) {
            printf STDERR "Command not found: %s\n", $input[0];
            prompt;
            next;
         }

         exec { $input[0] } @input;

      } else {
         printf STDERR "Failed to fork child: %s", $input[0];
      }
   }

   select STDOUT;
   select STDIN;
   select STDERR;

   prompt;
}

# Just in case any of the above get skipped, this wait ensures that we don't intentionally create any zombies.
wait;
