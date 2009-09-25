package Dancer::Error;

use strict;
use warnings;

use Dancer::Response;
use Dancer::Renderer;
use Dancer::Config 'setting';
use Dancer::Logger;

sub new {
    my ($class, %params) = @_;
    my $self = \%params;
    bless $self, $class;

    $self->{title} ||= "Error " . $self->code;

    my $html_output = "<h2>" . $self->{type} . "</h2>";
    $html_output .= $self->backtrace;
    $html_output .= $self->environment;

    $self->{message} = $html_output;
    return $self;
}

sub code    { $_[0]->{code} }
sub title   { $_[0]->{title} }
sub message { $_[0]->{message} }

sub backtrace {
    my ($self) = @_;

    my $message = $self->{message};
    my ($file, $line) = ($message =~ /at (\S+) line (\d+)/);
    return $message unless ($file and $line);

    my $fh;
    open $fh, '<', $file or return $message;
    my @lines = <$fh>;
    close $fh;

    $line--;
    my $start = (($line - 3) >= 0)             ? ($line - 3) : 0;
    my $stop  = (($line + 3) < scalar(@lines)) ? ($line + 3) : scalar(@lines);

    my $backtrace = "<div id=\"error\"><pre>$message</pre></div>";
    $backtrace .= "<pre class=\"sourcecode\">";
    for (my $l = $start; $l <= $stop; $l++) {
        chomp $lines[$l];
        if ($l == $line) {
            $backtrace
              .= "<span class=\"nu\">"
              . ($l + 1)
              . "</span> <font color=\"red\">"
              . $lines[$l]
              . "</font>\n";
        }
        else {
            $backtrace
              .= "<span class=\"nu\">"
              . ($l + 1)
              . "</span> "
              . $lines[$l] . "\n";
        }
    }
    $backtrace .= "</pre>";

    return $backtrace;
}

sub dumper {
    my $obj = shift;

    my $content = "";
    while (my ($k, $v) = each %$obj) {
        $content
          .= "<span class=\"key\">$k</span> : <span class=\"value\">$v</span>\n";
    }
    return $content;
}

sub render {
    my $self = shift;
    return Dancer::Response->new(
        status  => $self->code,
        headers => {'Content-Type' => 'text/html'},
        content =>
          Dancer::Renderer->html_page($self->title, $self->message, 'error')
    ) if setting('show_errors');

    return Dancer::Renderer->render_error($self->code);
}

sub environment {
    my ($self) = @_;

    my $env = "<h3>Environment</h3><pre>" . dumper(\%ENV) . "</pre>";
    my $settings =
      "<h3>Settings</h3><pre>" . dumper(Dancer::Config->settings) . "</pre>";
    my $source = "<h3>Stack</h3><pre>" . $self->get_caller . "</pre>";
    return "$source $settings $env";
}

sub get_caller {
    my ($self) = @_;
    my @stack;

    my $deepness = 0;
    while (my ($package, $file, $line) = caller($deepness++)) {
        push @stack, "$package in $file l. $line";
    }

    return join("\n", reverse(@stack));
}

1;
