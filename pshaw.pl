#!/usr/bin/perl

#
# pshaw - A unix shell written in Perl. Because why not?
#

use POSIX;
use Env;          #Import all of the user's environment variables as Perl variables
use Data::Dumper;

$|++; # Autoflush

#use lib 'include';

require 'sys/syscall.ph';

sub processBuiltin {
   my $function = shift;
   my @args = @_;

   # Do the command and return 1 if the command was processed, otherwise return 0.

   if ($function eq "exit") {
      exit join(" ", @args);
   }

   if ($function =~ m/(print|echo)/) {
      eval { $function." ".join(" ", @args) };
      return 1;
   }

   if ($function eq "cd") {
      chdir $args[0];
      return 1;
   }

   return 0;
}

sub processBackground {
   my @input = @_;

   my $isbg = 0;
   for (my $i=0; $i <= scalar(@input); $i++) {
      if ($input[$i] eq "&") {
         $isbg = 1;
         splice(@input, $i, 1);
      }
   }

   #print STDERR "isbg: $isbg\n";

   return $isbg, @input;
}

sub processRedirects {
   my @input = @_;

   #FIXME: This won't work if there are spaces around the redirect operator.

   #print Dumper(@input);

   for (my $i=0; $i <= scalar(@input); $i++) {
      #print STDERR $input[$i]."\n";

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
   my @pipes = split(/\|/, $inputstr);
   for (my $pipe = 0; $pipe < scalar(@pipes); $pipe++) {
      print STDERR "Found pipe #$pipe: $pipes[$pipe]\n" unless $pipe == 0;

      my @input = split(" ", $pipes[$pipe]);

      if ($inputstr =~ m/^\s*$/) {
         prompt;
         next;
      }

      if (scalar(@pipes) > 0) {
         if ($pipe == 0) {
            # Initialize a pipe
            pipe LFTRPIPE,LFTWPIPE;
            print STDERR "Debug: Created LEFTRPIPE ".fileno(LFTRPIPE)." and LEFTWPIPE ".fileno(LFTWPIPE)."\n";
            pipe RGTRPIPE,RGTWPIPE;
            print STDERR "Debug: Created RGHTRPIPE ".fileno(RGTRPIPE)." and RGHTWPIPE ".fileno(RGTWPIPE)."\n";
         } else {
            # Roll the RIGHT pipe to the LEFT pipe
            print STDERR "Debug: LFTRPIPE is now ".fileno(LFTRPIPE)." and LFTWPIPE is now ".fileno(LFTWPIPE)."\n";
            close(LFTRPIPE);
            open(LFTRPIPE, "<&=".fileno(RGTRPIPE)) or die "Couldn't dup RGTRPIPE: $!";
            close(RGTRPIPE);
            close(LFTWPIPE);
            open(LFTWPIPE, "<&=".fileno(RGTWPIPE)) or die "Couldn't dup RGTWPIPE: $!";
            close(RGTWPIPE);
            print STDERR "Debug: LFTRPIPE is now ".fileno(LFTRPIPE)." and LFTWPIPE is now ".fileno(LFTWPIPE)."\n";

            unless ($pipe == scalar(@pipes)) {
               # make a new RIGHT pipe unless this is the last in the chain.
               #####pipe RGTRPIPE,RGTWPIPE;
               #####print STDERR "Debug: Created RGHTRPIPE ".fileno(RGTRPIPE)." and RGTWPIPE ".fileno(RGTWPIPE)."\n";
            }
         }

      }
      
      # FIXME: There is a bug here somewhere. After backgrounding a process, the prompt isn't written after running a subsequent command.
      my $bg; ($bg, @input) = processBackground( @input );
   
      # If the command is a builtin, then process it.
      unless ( processBuiltin( @input ) ) {
         # The command was not a builtin. Start doing the fun stuff.
   
         my $pid = fork();
         if ($pid) {
            # parent

            # If a background token was found in the command, then wait, otherwise don't wait (put the process in the background).
            wait unless $bg; 

         } elsif ($pid == 0) {
            # child
            
            if ($pipe == 0) {
               # Set up file descriptors to write STDOUT to the pipe unless it's the last in the chain.
               close(STDOUT);
               open(STDOUT, ">&=".fileno(LFTRPIPE)); #, RGTWPIPE) or die "Couldn't dup RGTWPIPE: $!";
               print STDERR "Debug: STDOUT is now ".fileno(STDOUT)."(".fileno(LFTRPIPE).")\n";
               close(RGTRPIPE);
               close(RGTWPIPE);
            } else {
               # Set up file descriptors to read STDIN from the pipe unless it's the first in the chain.
               close(STDIN);
               open(STDIN, "<&=".fileno(LFTWPIPE)); #, LFTRPIPE) or die "Couldn't dup LFTRPIPE: $!";
               print STDERR "Debug: STDIN is now ".fileno(STDIN)."(".fileno(LFTWPIPE).")\n";
            }

            print STDERR "$$: ".system("ls -la /proc/$$/fd > /tmp/$$.out")."\n";

            # Handle redirection - Search the input for redirection operators, handle them, then delete them from the input.
            if ($pipe == scalar($pipes)) {
               # Only accept redirection commands if it's the last pipe in the chain (or if there are no pipes)
               @input = processRedirects( @input );
            }
   
            # Locate the file on the disk for the executable
            if ( $input[0] =~ m#^/# ) {
               # The command starts with a /, so the path is absolute
            } elsif ( $input[0] =~ m#/# ) {
               # The command doesn't begin with /, but contains /, so the path is relative
               # Make it absolute by prepending the PWD.
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

            sleep 600;
   
         } else {
            printf STDERR "Failed to fork child: %s", $input[0];
         }
      }

   
      select STDOUT;
      select STDIN;
      select STDERR;
   }

   prompt;
}

# Just in case any of the above get skipped, this wait ensures that we don't intentionally create any zombies.
wait;

close LFTRPIPE;
close LFTWPIPE;
close RGTRPIPE;
close RGTWPIPE;
