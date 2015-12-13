#!/db003/essbase/perl5/bin/perl 
# By Craig Grady
# 06/30/04 

use DBI;
use DBIx::OracleLogin;

my $output = "msi_chk.txt";
my %qry = ();

$qry{add} = q{
      SELECT SUM(a.QTY) 
      FROM DWPROC.GRS_HNDST_ADD_DAILY a, 
	   DWPROC.EMIS_GEOG_HIRCH_SR b
      WHERE b.CSA_ID = a.COMM_SVC_AREA_ID
      AND b.super_reg_type_cd = 'ZCMB'
      AND nvl(a.cust_type_cd, ' ') <> 'J'
      AND nvl(b.owner_desc,' ') <> 'SPRINT PCS'
      AND a.REPORT_DT = '21-JUN-2004' 
      AND a.SALES_CHNL_TYPE_IND = 'U' 
      AND b.OWNER_CD = 'GC' 
};

$qry{aff_add} = q{
      SELECT SUM(a.AFF_ADD_QTY) 
      FROM DWPROC.GRS_HNDST_ADD_DAILY_AFF a, 
	   DWPROC.EMIS_GEOG_HIRCH_SR b
      WHERE b.CSA_ID = a.COMM_SVC_AREA_ID
      AND b.super_reg_type_cd = 'ZCMB'
      AND nvl(a.cust_type_cd, ' ') <> 'J'
      AND a.REPORT_DT = '21-JUN-2004' 
      AND a.SC_TYPE_IND = 'U' 
      AND b.OWNER_CD = 'GC' 
};


$qry{add_adj} = $qry{add};
$qry{add_adj} =~ s/ADD/ADD_ADJ/g;

$qry{dactvn} = $qry{add};
$qry{dactvn} =~ s/ADD/DACTVN/g;

$qry{dactvn_adj} = $qry{add};
$qry{dactvn_adj} =~ s/ADD/DACTVN_ADJ/g;

$qry{xfer_in} = $qry{add};
$qry{xfer_in} =~ s/ADD/XFER_IN/g;

$qry{xfer_out} = $qry{add};
$qry{xfer_out} =~ s/ADD/XFER_OUT/g;

$qry{pend_add} = $qry{add};
$qry{pend_add} =~ s/GRS/PEND/g;

$qry{pend_adj} = $qry{pend_add};
$qry{pend_adj} =~ s/ADD/ADD_ADJ/g;

$qry{pend_dactvn} = $qry{pend_add};
$qry{pend_dactvn} =~ s/ADD/DACTVN/g;

$qry{pend_xfer_in} = $qry{pend_add};
$qry{pend_xfer_in} =~ s/ADD/XFER_IN/g;

$qry{pend_xfer_out} = $qry{pend_add};
$qry{pend_xfer_out} =~ s/ADD/XFER_OUT/g;

$qry{aff_add_adj} = $qry{aff_add};
$qry{aff_add_adj} =~ s/ADD/ADD_ADJ/g;
$qry{aff_add_adj} =~ s/SC_TYPE_IND/SALES_CHNL_TYPE_IND/g;

$qry{aff_dactvn} = $qry{aff_add};
$qry{aff_dactvn} =~ s/ADD/DACTVN/g;

$qry{aff_dactvn_adj} = $qry{aff_add};
$qry{aff_dactvn_adj} =~ s/ADD/DACTVN_ADJ/g;
$qry{aff_dactvn_adj} =~ s/SC_TYPE_IND/SALES_CHNL_TYPE_IND/g;

$qry{aff_xfer_in} = $qry{aff_add};
$qry{aff_xfer_in} =~ s/ADD/XFER_IN/g;

$qry{aff_xfer_out} = $qry{add};
$qry{aff_xfer_out} =~ s/ADD/XFER_OUT/g;


$dbh = DBI->connect('dbi:Oracle:', q{emis/cdb@(DESCRIPTION=
  (ADDRESS=(PROTOCOL=TCP)(HOST= "208.10.66.84")(PORT=1521))
  (CONNECT_DATA=(SID=CDB)))}, "")
    or die $DBI::errstr;

open FILE, "> $output"
    or die "Cannot open file $output:\n  $!";


while(($key, $value) = each(%qry)) {

  my $sth = $dbh->prepare($value) or die $dbh->errstr;

  $sth->execute or die $dbh->errstr;

  while ( @row = $sth->fetchrow_array ) {
      foreach $col(@row) { 
        print FILE "$key: $col\t"; 
      }
      print FILE "\n";
   }
}

close FILE;

$dbh->disconnect;

exit;
