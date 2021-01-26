# oci-find-tagged
List the names and ids of all compute instances in an Oracle Cloud Infrastructure (OCI) tenancy that are tagged with user-specified defined tags.

The options for command line arguments are as follows:
<pre>
Flag                          Description                                       Usage

-c          Compartment name(s) and/or ocid(s). If none specified, all          $0 -c samuel
             compartments are searched. If the string does not have ocid
             format, it is assumed to be the compartment name. If the
             name is not unique, the first value returned from an internal
             command will be used.
-r          Region identifier(s). If none specified, all regions are searched.  $0 -r us-ashburn-1 us-phoenix-1
-h          Show options.                                                       $0 -h
-n          Tag namespace                                                       $0 -n Oracle-Tag
-k          Tag key                                                             $0 -k CreatedBy
-v          Tag value                                                           $0 -v samuel
</pre>
Sample run:
<pre>
$ ./find-tagged -n Oracle-Tag -k CreatedBy -v samuel -c samuel -r us-ashburn-1 us-phoenix-1
</pre>