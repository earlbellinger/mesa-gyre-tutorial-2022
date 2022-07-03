#!/bin/bash

#### Converter for .GYRE file to oscillation mode frequencies with GYRE 
#### Author: Earl Bellinger ( bellinger@phys.au.dk ) 
#### Max Planck Institute for Astrophysics, Garching, Germany 
#### Stellar Astrophysics Centre, Aarhus University, Denmark 

### Parse command line tokens 

HELP=0
EIGENF=0
SAVE=0
RADIAL=0
FGONG=0
OMP_NUM_THREADS=1
SCALE=0 # Use scaling relations to find lower bound 
LOWER=0.1
CONVERT=0
UPPER=8496 # Kepler Nyquist frequency in microHertz 
UNITS="UHZ"
RESOLUTION=0
DIPOLE=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    -h) HELP=1; break;;
    -i) INPUT="$2"; shift 2;;
    -o) OUTPUT="$2"; shift 2;;
    -t) OMP_NUM_THREADS="$2"; shift 2;;
    -l) LOWER="$2"; shift 2;;
    -u) UPPER="$2"; shift 2;;
    -r) RADIAL=1; shift 1;;
    -d) DIPOLE=1; shift 1;;
    -e) EIGENF=1;SAVE=1; shift 1;;
    -s) SAVE=1; shift 1;;
    -R) RESOLUTION=1; shift 1;;
    -S) SCALE=1; shift 1;;
    -C) CONVERT=1; shift 1;;
    -U) UNITS="$2"; shift 2;;
    
    *) if [ -z "$INPUT" ]; then 
           INPUT="$1"
           shift 1
         else 
           echo "unknown option: $1" >&2
           exit 1
       fi;
  esac
done

if [ $HELP -gt 0 ] || [ -z "$INPUT" ]; then
    echo "Converter for .GYRE files to oscillation mode frequencies."
    echo "Usage: ./gyre2freqs.sh -i input -o output -t threads -e -r -l 1000"
    echo "Flags: -s : save calculations directory"
    echo "       -e : calculate eigenfunctions (automatically turns on -s)"
    echo "       -r : only calculate radial modes"
    echo "       -d : only calculate dipole modes"
    echo "       -f : FGONG file format"
    echo "       -l : lower bound on frequency search"
    echo "       -u : upper bound on frequency search"
    echo "       -S : use scaling relations to find lower bound"
    echo "       -U : units such as 'UHZ' (default) or 'CYC_PER_DAY'"
    echo "       -R : increase grid resolution"
    exit
fi

## Check that the first input (GYRE file) exists
if [ ! -e "$INPUT" ]; then
    echo "Error: Cannot locate GYRE file $INPUT"
    exit 1
fi

## Pull out the name of the GYRE file
bname="$(basename $INPUT)"
fname="${bname%%.*}-freqs"
pname="${bname::-5}"

## If the OUTPUT argument doesn't exist, create a path from the filename 
if [ -z ${OUTPUT+x} ]; then
    path=$(dirname "$INPUT")/"$fname"
  else
    path="$OUTPUT"
fi

MODES="
&mode
    l=0
/
&mode
    l=1
/
&mode
    l=2
/
&mode
    l=3
/
"
if [ $RADIAL -gt 0 ]; then
    MODES="
&mode
    l=0
    n_pg_max=5
/
"
fi
GRID_TYPE="LINEAR"
if [ $DIPOLE -gt 0 ]; then
    MODES="
&mode
    l=1
    n_pg_max=0
/
"
GRID_TYPE="INVERSE"
fi

if [ $RESOLUTION -gt 0 ]; then 
    N_FREQ=10000 #10000
    GRID="
&grid
    w_ctr = 50
    w_osc = 50
    w_exp = 10
/
"
else
    N_FREQ=1000
    GRID="
&grid
    w_ctr = 10
    w_osc = 10
    w_exp = 2
/
"
fi

MODE_ITEM_LIST=''
if [ $EIGENF -gt 0 ]; then
    SAVE=1
    MODE_ITEM_LIST="detail_file_format = 'TXT'
    detail_template = '%L_%N'
    detail_item_list = 'M_star,R_star,l,n_pg,n_p,n_g,freq,E,E_p,E_g,E_norm,M_r,x,xi_r,xi_h'"
fi

# use the scaling relations to calculate lower frequency bound 
# only works on .GYRE files for now 
if [ $SCALE -gt 0 ]; then
    #pnum=$(echo "$pname" | sed 's/profile//g')
    #profs<-read.table('../profiles.index', skip=1)
    #which[profs$V1==$pnum]
    
    # get the first line of the GYRE file 
    read -r FIRSTLINE < "$INPUT"
    #LASTLINE=$(awk '/./{line=$0} END{print line}' "$INPUT")
    
    # pull out M, R, Teff from the GYRE file of the stellar model 
    # https://bitbucket.org/rhdtownsend/gyre/src/tip/doc/mesa-format.pdf
    M=$(echo $FIRSTLINE | awk '{print $2}')
    R=$(echo $FIRSTLINE | awk '{print $3}')
    #T=$(echo $LASTLINE  | awk '{print $6}')
    
    # assumes that Teff is in the 7th column of the profile file header 
    T=$(sed '3q;d' "${INPUT::-5}" | awk '{print $7}')
    
    # divide by the solar values 
    Mscal=$(awk '{ print $1 / 1.988475E+33 }' <<< "$M")
    Rscal=$(awk '{ print $1 / 6.957E+10 }' <<< "$R")
    Tscal=$(awk '{ print $1 / 5772 }' <<< "$T")
    
    # calculate scaling relations 
    # numax = M/R**2/sqrt(Teff/5777)
    # Dnu   = sqrt(M/R**3)
    numax=$(awk -v M="$Mscal" -v R="$Rscal" -v T="$Tscal" \
        'BEGIN { print M / R^2 * T^(-1/2) * 3090 }')
    Dnu=$(awk -v M="$Mscal" -v R="$Rscal" \
        'BEGIN { print (M / R^3)^(1/2) * 135 }')
    
    # find lower limit 
    LOWER=$(awk -v numax="$numax" -v Dnu="$Dnu" \
        'BEGIN { print numax - 10*Dnu }')
    
	UPPER=$(awk -v numax="$numax" \
	    'BEGIN { print numax * 5/3 }')
	
    # check that it's greater than 0.1 
    if [ $(echo "$LOWER < 0.1" | bc -l) -gt 0 ]; then
        LOWER=0.1
    fi
fi

## Create a directory for the results and go there
mkdir -p "$path" 
#cp "$INPUT" "$path" 
cd "$path" 

logfile="gyre-l0.log"
#exec > $logfile 2>&1

## Create a gyre.in file to find the large frequency separation
echo "&model
    model_type = 'EVOL'
    file = '../$bname'
    file_format = $FORMAT
/

&constants
/

$MODES

&osc
    outer_bound = 'JCD'
    variables_set = 'JCD'
    inertia_norm = 'BOTH'
    x_ref = 1
/

&num
    diff_scheme = 'MAGNUS_GL4'
/

&scan
    grid_type = '$GRID_TYPE'
    freq_min_units = '$UNITS' !'UHZ'
    freq_max_units = '$UNITS' !'UHZ'
    freq_min = $LOWER
    freq_max = $UPPER
    n_freq = $N_FREQ
/

$GRID

&rot
/

&ad_output
    summary_file = '$fname.dat'
    summary_file_format = 'TXT'
    summary_item_list = 'l,n_pg,n_p,n_g,freq,E_norm'
    freq_units = '$UNITS' !'UHZ'
    $MODE_ITEM_LIST
/

&nad_output
/

" >| "gyre.in"

## Run GYRE
#exit
$GYRE_DIR/bin/gyre gyre.in &>gyre.out
#exit 

### Hooray!
cp "$fname.dat" ..
echo "Conversion complete. Results can be found in $fname.dat"
if [ $SAVE -gt 0 ]; then exit 0; fi
rm -rf *
currdir=$(pwd)
cd ..
rm -rf "$currdir"
exit 0

