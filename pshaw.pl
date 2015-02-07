#!/usr/bin/perl

#
# pshaw - A shell written in Perl. Why not?
#

use POSIX;
use Env;          #Import all of the user's environment variables as Perl variables
use Data::Dumper;

sub processBuiltin {
   my $function = shift;
   my @args = @_;

   # Do the command and return 1 if the command was processed, otherwise return 0.

   if ($function eq "exit") {
      exit join(" ", @args);
      return 1;
   }

   return 0;
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
         printf STDERR "Command not found: %s", $input[0];
         next;
      }
      # Build up argv and argc
      # execve the command
      
      POSIX::execve(@input);
      #printf STDERR "I'd love to be able to %s someday.\n", join(" ", @input);
   }

   prompt;
}
