#!/bin/bash

INLIST=inlist_project
change() { 
    # Modifies a parameter in the current inlist. 
    # args: ($1) name of parameter 
    #       ($2) new value 
    #       ($3) filename of inlist where change should occur 
    # example command: change initial_mass 1.3 
    # example command: change log_directory 'LOGS_MS' 
    # example command: change do_element_diffusion .true. 
    param=$1 
    newval=$2 
    filename=$3 
    escapedParam=$(sed 's#[^^]#[&]#g; s#\^#\\^#g' <<< "$param")
    search="^\s*\!*\s*$escapedParam\s*=.+$" 
    replace="    $param = $newval" 
    if [ ! "$filename" == "" ]; then
        sed -r -i.bak -e "s#$search#$replace#g" $filename 
    fi
    if [ ! "$filename" == "$INLIST" ]; then 
        change $param $newval "$INLIST"
    fi 
} 

for M in 0.7 0.8 0.9 1.0 1.1 1.2; do
    echo "Running mass $M"
    change initial_mass $M
    change log_directory "'$M'" 
    ./rn
    
    cd $M
    for FGONG in *.FGONG; do
        ../../src/gyre6freqs.sh -i $FGONG -f -t $OMP_NUM_THREADS
    done
    cd -
done 

