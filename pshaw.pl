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
         printf STDERR "Command not found: %s\n", $input[0];
         prompt;
         next;
      }
      # Build up argv and argc
      # execve the command
      
      #my $executable = shift @input;
      #print Dumper(@input);
      
      my $pid = fork();
      if ($pid) {
         # parent
         wait;
      } elsif ($pid == 0) {
         # child
         exec { $input[0] } @input;
      } else {
         printf STDERR "Failed to fork child: %s", $input[0];
      }
   }

   prompt;
}

#use Inline C => <<'END_OF_C_CODE';
#
#void call_execve(SV* filename, 
