#!/bin/bash

#### A script to install the MESA SDK and MESA to a 64-bit Linux system 
#### Author: Earl Patrick Bellinger ( bellinger@phys.au.dk ) 
#### Max Planck Institute for Astrophysics, Garching, Germany 
#### Stellar Astrophysics Centre, Aarhus University, Denmark 

# The following is intended to be run line-by-line rather than all at once 
# This will enable you to catch and fix errors as they arise 
# See also instructions and solutions here: 
# https://docs.mesastar.org/en/release-r22.05.1/installation.html 

#################
### Variables ###
#################
MESA_VER=22.05.1         # Adjust these if you want a different version 
SDK_VER=22.6.1           # ...but check the zenodo link below 
export OMP_NUM_THREADS=1 # Adjust this if you want to use more threads 
add_to_bashrc=1          # set to zero if you don't want your bashrc to change 

######################
### Pre-requisites ###
######################
# this command is needed for my lubuntu laptop 
#sudo apt install libc-dev binutils make perl libx11-dev tcsh zlib1g-dev libncurses5-dev 

#########################################
### Download and install the MESA SDK ###
#########################################
mkdir MESA
cd MESA

## Download SDK
SDK_REV=mesasdk-x86_64-linux-"$SDK_VER"
curl --remote-name http://www.astro.wisc.edu/~townsend/resource/download/mesasdk/"$SDK_REV".tar.gz
mkdir $SDK_REV
tar xvfz "$SDK_REV".tar.gz -C "$SDK_REV"
ln -sfn "$SDK_REV"/mesasdk mesasdk
export MESASDK_ROOT=$(pwd)/mesasdk

## Run SDK
source $MESASDK_ROOT/bin/mesasdk_init.sh

#################################
### Download and install MESA ###
#################################
## Download MESA
MESA_REV=mesa-r"$MESA_VER"
wget https://zenodo.org/record/6547951/files/"$MESA_REV".zip
unzip "$MESA_REV".zip
ln -sfn $(pwd)/"$MESA_REV" mesa
export MESA_DIR=$(pwd)/mesa

## Install MESA
cd $MESA_DIR
./install

## Install GYRE
export GYRE_DIR=$MESA_DIR/gyre/gyre
cd $GYRE_DIR
make

if [ add_to_bashrc == 1 ]; then
    echo export MESASDK_ROOT="$MESASDK_ROOT" >> ~/.bashrc 
    echo export MESA_DIR="$MESA_DIR" >> ~/.bashrc
    echo export GYRE_DIR=$MESA_DIR/gyre/gyre >> ~/.bashrc 
    echo export OMP_NUM_THREADS="$OMP_NUM_THREADS" >> ~/.bashrc
    echo source "$MESASDK_ROOT"/bin/mesasdk_init.sh >> ~/.bashrc 
fi
