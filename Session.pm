##################################################################################################################
# 
# Source  : $Source: /home/simran/cvs/misc/cpan/Simran/DB/Session.pm,v $
# Revision: $Revision: 1.3 $ 
# Date    : $Date: 2001/06/04 17:53:05 $
# Author  : $Author: simran $
#
##################################################################################################################

package Simran::DB::Session;

use strict;
use DBI;
use Carp;
use Simran::Error::Error;

($Simran::DB::Session::VERSION = '$Revision: 1.3 $') =~ s/[^\d\.]//g;
my $error = new Simran::Error::Error({CARP => 1});

1;


##################################################################################################################

sub new {

  my $proto  = shift;
  my $params = shift;
  my $class  = ref($proto) || $proto;
  my $self   = {};
  
  $error->clear();
  
  $self->{DATABASE} = undef;
  $self->{HOST}     = undef;
  $self->{PORT}     = undef;
  $self->{USERNAME} = undef;
  $self->{PASSWORD} = undef;
  $self->{DSN}      = undef;
  $self->{PROTOCOL} = "mysql";
  
  # private Properties
  $self->{DATABASE_HANDLE} = undef;
  
  bless ($self, $class);
  
  # if we have parameters, call the set method.
  if ($params) {
    $self->set($params);
  }
  
  return $self;
}


################################################################################################################## 

sub set {
  
  my $self = shift;
  
  my ($key, $value, $param_string);
  
  $error->clear();
  
  # all other while we have parameters
  foreach (@_) {
    
    # multiple key=value pairs are separated by ";"
    foreach (split (/\s*;\s*/, $_)) {
      
      # Get key and value
      ($key, $value) = split (/\s*=\s*/, $_);
      
      # check that key is valid. If it is set the value, if not,
      # set error message, but continue processing
      if ( exists $self->{ uc($key) } ) {
	$self->{uc($key) } = $value;
      }
      else {
	$error->set("attempt to set a bad parameter '$key' to '$value'");
      }
    }
  }
}



##################################################################################################################


sub build_dsn {
  
  my $dsn = "DBI";
  my $self = shift;

  $error->clear();
  
  # protocol is essential
  if ($self->{PROTOCOL}) {
    $dsn .= ":".$self->{PROTOCOL};
  }
  else {
    $error->set("cannot build dsn. No driver (protocol)");
    return 0;
  }
  
  # database is essential
  if ($self->{DATABASE}) {
    $dsn .= ":".$self->{DATABASE};
  }
  else {
    $error->set("cannot build dsn. No database");
    return 0;
  }
  
  if ($self->{HOST}) {
    $dsn .= ";".$self->{HOST};
  }
  
  if ($self->{PORT}) {
    $dsn .= ";".$self->{PORT};
  }
  
  # set DSN and return success
  $self->{DSN} = $dsn;
  
  return 1;
}



##################################################################################################################


sub connect {
  
  my $self = shift;
  
  $error->clear();
  
  if ($self->{DATABASE_HANDLE} ) {
    return 1;
  }
  
  # build the dsn using the method
  if ($self->build_dsn) {
    
    # connect to the database using DBI->connect
    my $dbh = DBI->connect($self->{DSN}, $self->{USERNAME}, $self->{PASSWORD});
    
    # store database handle if it exists (success). If no $dbh
    # it means the connection failed. Get the error
    if ($dbh) {
      $self->{DATABASE_HANDLE} = $dbh;
    }
    else {
      $error->set("Unable to connect to $self->{DSN}:".DBI->errstr);
    }
  }
  
  # we didnt get a dsn so fail and set bad dss as error
  else {
    $error->set("Could not build DSN");
  }
  
  
  # if have have an error return 0 (failure) else return 1 (success)
  if ($error->msg) {
    return 0;
  }
  else {
    return 1;
  }
}


##################################################################################################################

sub disconnect {
  
  my $self = shift;
  my $dbh = $self->{DATABASE_HANDLE};
  
  $error->clear();
  
  # if we have a valid database connection, disconnect and return 1
  if ($dbh) {
    $dbh->disconnect;
    $self->{DATABASE_HANDLE} = undef;
    return 1;
  }
  return undef;

}


##################################################################################################################


sub query_handle {
  my $self = shift;
  my $query =  shift;
  my ($dbh, $sth) = undef;
  
  $error->clear();
  
  # Try to connect, if already connected this is OK
  if (! $self->connect) {
    $error->set("could not connect to $self->{DSN}");
    return "";
  }
  else {
    
    $dbh = $self->{DATABASE_HANDLE};
 
    # prepare the query, if that succeeds execute it. if either fails
    # then complain and return nothing
    if ($sth = $dbh->prepare($query)) {
      if (! $sth->execute) {
	$error->set("Could not execute statement: ".$sth->errstr);
      }
    }
    else {
      $error->set("Could not prepare statement: ".$dbh->errstr);
    }
    return $sth;
  }
}

##################################################################################################################


sub quote {
  my $self = shift;
  local $_ = shift;
  my $literal = shift;
  
  s/(['"!\\])/\\$1/g; #'#quotes, and balckslashes

  # tabs, returns, etc
  s/\t/\\t/g;
  s/\n/\\n/g;
  s/\r/\\r/g;
  s/\0/\\0/g;

  # this is to disable wildcards, greater than etc for literal searching
  if ($literal) {
    s/([_%<>=])/\\$1/g;
  }

  return $_;
}


##################################################################################################################

sub all_values {
  my $self  = shift;
  my $query = shift;
  my($sth);
  
  $error->clear();
 
  $sth = $self->query_handle($query);
  if ($sth) {
    return($sth->fetchall_arrayref);
  }
  else {
    $error->set("Could not get database state handle");
    return "";
  }
}


##################################################################################################################

sub rarh {
  my $self = shift;
  my ($table, $where_clauses) = @_;
  my (@table_data, $sth);

  $error->clear();

  $where_clauses = "where $where_clauses" if ($where_clauses);

  if (! ($sth = $self->query_handle("show fields from $table"))) {
    $error->set("Could not get database state handle");
    return;
  }

  my @fields_ref = @{$sth->fetchall_arrayref([0])};
  my $values_ref = $self->all_values("select * from $table $where_clauses");

  return if ($self->error);

  foreach (@{$values_ref}) {
    my ($i, @row_data);
    for ($i=0; $i <= $#fields_ref; $i++) {
      push (@row_data, lc($fields_ref[$i]->[0]) => $_->[$i]);
    }
    push(@table_data, { @row_data });
  }

  return \@table_data;

}

##################################################################################################################

sub value {
  my $self  = shift;
  my $query = shift;
  my($sth);
  
  $error->clear();
  
  if ($sth = $self->query_handle($query)) {
    return($sth->fetchrow_array);
  }
  else {
    $error->set("Could not get database state handle");
    return "";
  }
}

##################################################################################################################

sub do {
  my $self  = shift;
  my $query = shift;
  my $sth   = undef;

  $error->clear();

  if ($sth = $self->query_handle($query)) {
    if ($sth->errstr) {
      $error->set($sth->errstr);
      return undef;
    }
    return $sth->rows;
  }
  else {
    $error->set("Could not get database state handle");
    return "";
  }  
}


##################################################################################################################


sub DESTROY {
  
  my $self = shift;

  $error->clear();
  
  # need to disconnect if still connected
  if ($self->{DATABASE_HANDLE}) {
    $self->disconnect;
  }
}



##################################################################################################################

sub error {
  my $self = shift;
  return $error->msg();
}

##################################################################################################################




__END__

##################################################################################################################

=pod

=head1 NAME 

Session.pm - Database Session

##################################################################################################################

=head1 DESCRIPTION 

Gives a friendlier interface to the DBI module.

##################################################################################################################

=head1 SYNOPSIS

Please see DESCRIPTION.

##################################################################################################################

=head1 REVISION

$Revision: 1.3 $

$Date: 2001/06/04 17:53:05 $

##################################################################################################################

=head1 AUTHOR

Simran I<simran@unsw.edu.au>

##################################################################################################################

=head1 BUGS

No known bugs. 

##################################################################################################################

=head1 PROPERTIES

DATABASE: the name of the database to connect to.

HOST:     the name of the host computer for the session.

PORT:     the port number to connect to the host.

USERNAME: the user name to use for the connection.

PASSWORD: the password to use for the connection.

DSN:      the Data Source Name.

PROTOCOL: the protocol to use for DBI. Defaults to "mysql"

DATABASE_HANDLE: the database handle when the connection is made (used to perform queries etc).

##################################################################################################################

=head1 METHODS

##################################################################################################################

=head2 new

=over

=item Description

This is the create method for the Simran::DB::Session class. The new method can be
called with parameters, if it is, they ar passed to the set method (see
below).

        $session = Simran::DB::Session->new

        or

        $session = Simran::DB::Session->new($parameters)

eg.

        $session = Simran::DB::Session->new("PROTOCOL=mysql;DATABASE=test;HOST=localhost;PORT=3306");

=item Input

        $parameters -  the parameters string is passed straight to the set method (see below).

=item Output

        New Simran::DB::Session object created.

=item Return Value

        New Simran::DB::Session object.

=back


##################################################################################################################

=head2 set 

=over

=item Description

This method takes strings (one or more) of the form "<property1>=<value1>;
<property2>=<value2>" (i.e. each value in the same string must be
separated by a semi colon). And sets the coressponding property in the
object.

Example: to set the DATABASE property $session->set("DATABASE=MyDataBase")

set is case insensitive when working out which property to set (eg
DATABASE or database) would work equally well.

        $session->set(@parameters); # list of parameter strings

        or

        $session->set($parameters); # single parameter string


=item Input

        @parameters (list of inputs $parameters below)

        $parameters (scalar, string) -  the parameters
        string (or list of strings is a set of paired <property>=<value>,
        with each pair being separated by a semi-colon.

        Note: Dont use semi-colons or equals (; or =) in the values

        eg: $parameters = "DATABASE=MyData;USER=Me;PASSWORD=secret";



=item Output

        Sets properties within the object

=item Return Value

        returns 1 if all parameters successfully set.

=back


##################################################################################################################

=head2 build_dsn 

=over

=item Description

This internal method builds the DSN property (needed for the connection). There
should be no need to call this manually as the Simran::DB::Session object should
invoke this method interanlly whenever it needs to connect to the DB

A DSN looks like "DBI:<protocol>:database=<dbname>;host=<hostname>;
port=portname". The host and the port are optional, but the protocol and
the database are essential.

=item Syntax

        $session->set(@parameters); # list of parameter strings

        or

        $session->set($parameters); # single parameter string

=item Input

        None, uses object properties

=item Output

        Builds the DSN property

=item Return Value

        returns 1 if DSN is valid.

=back



##################################################################################################################

=head2 connect

=over

=item Description

This method connects to the database using the DBI connect method.
Needs a valid DSN to succeed and invokes the internal "build_dsn" method.
This is mostly an internal method called when a conection becomes
necessary.

=item Input

        None, uses object properties DSN, USERNAME, PASSWORD

=item Output

        creates DBI database handle and stores it in the
        DATABASE_HANDLE property.

=item Return Value

        returns 1 if connection succeeds.

=back



##################################################################################################################

=head2 disconnect 

=over

=item Description

This method disconnects the database handle using the DBI disconnect method.
This can be called explicity, but will be called when the Simran::DB::Session object
is destroyed. ie. when the object is removed or deleted.

        $session->disconnect


=item Input

        None, uses object property DATABASE_HANDLE

=item Output

        Disconnects and removes the DATABASE_HANDLE

=item Return Value

        1 if the disconnection succeeds

=back



##################################################################################################################

=head2 query_handle

=over

=item Description

Returns a statement handle of a particular query (see DBI and DBD
documentation for how to use the query handle. The query handle should be
explictly closed ($handle->finish) to avoid warnings and errors.

eg.

        $handle = $query_handle($query);

=item Input

        $query - the sql query to use

=item Output

        $handle - the statement handle

=item Return Value

        same as output

=back



##################################################################################################################

=head2 quote

=over

=item Description

Puts escape characters next to charaters for sql strings (queries etc).

The following characters have an escape '\' put in front of them:
", ', \, !, \t, \r, \n, \0,

In addition if a positive second parameter is sent (for stronger
'literal' escaping) these characters are escaped: %, <, >, =

        $escaped_string = $session->escape($string); or

        $escaped_string = $session->escape($string, 1); (for literal)

=item Input

        $string - the string to 'quote'

        1 (optional) if positive, stronger escaping used.

=item Output

        $escaped_string 

=item Return Value

        none

=back



##################################################################################################################

=head2 all_values

=over

=item Description

Similar to the 'Value' from db_routines.pl function, but returns the
entire query.

'all_values' does not keep the statement handle so once called, the query returns
the results and then is gone.

        $array_ref = $session->all_values($query);

=item Input

        $query - the sql query to run

=item Output

        $array_ref - the result of a 'fetchall_arrayref'

=item Return Value

        output is the return value.

=back

##################################################################################################################

=head2 rarh

=over

=item Description

Used for accessing the data from the database with a special output/return value

        $url_data = $dbObject->rarh("table", "id=$id and name='simran'")

=item Input

        $table - the table name we are to get data from
	$where_clauses - any where clauses 

=item Output

        $table_data - the output is a "reference to an array of references to hashes"
                      containing information for data associated with the query. 
                      eg.
                        $table_data = [
                                       { row1field1 => row1value1, row1field2 => row1value2, ... }
                                       { row2field1 => row2value1, row2field2 => row2value2, ... }
                                      ]

	Note: All the field names will be in lower case. 

=item Return Value

        Same as output.

=back


##################################################################################################################

=head2 value 

=over

=item Description

Equivalent to the 'Value' from db_routines.pl function, but returns the
entire query.

'values' does not keep the statement handle so once called, the query returns
the results and then is gone.

eg. 
        @array = $session->value($query);


=item Input

        $query - the query string...

=item Output

        @array - the result of a 'fetchrow'

=item Return Value

        output is the return value.

=back



##################################################################################################################

=head2 do

=over

=item Description

A fairly generic do command for the database. It connects if necessary
and executes the command. It returns the number of row effected by the
command.

eg. 
       $rows = $session->do($mysql_command);

=item Input

        $mysql_command (scalar, string) a command to be executed using the
          DBI::do method.

=item Output

        $rows (scalar, integer) the number of rows affected. If do method
          fails rows will be 'undef' # if the method succeeds but the
          command effects no rows the return value will be 0.

=item Return Value

        same as output

=back


##################################################################################################################

=head2 error

=over

=item Description

If called in an array context, returns the complete history of error messages
thus far. Else, returns the latest error message if set. 

        $errmsg = $session->error();

        or

        foreach $_ ($session->error()) { 
	  print "Error: $_\n";
        }


=item Input

        none

=item Output

       In array context, returns an array containing all error message set thus far.
       Else, returns the latest error message if set. 

=item Return Value

       same as output

=back


##################################################################################################################

=head2 DESTROY

=over

=item Description

The automatic destructor method for Simran::DB::Session. Called automatically when
a Simran::DB::Session is destroyed.

=item Syntax

        not used. method called when object is destroyed

=item Input

        none

=item Output

        none

=item Return Value

        none

=back


=cut


