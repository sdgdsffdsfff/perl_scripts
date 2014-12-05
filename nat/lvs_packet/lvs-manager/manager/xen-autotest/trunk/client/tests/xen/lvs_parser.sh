#!/bin/bash



function get_vrrp_info()
{

}

function get_vs_info()

{

}

function get_rs_info()
{

}


function get_sv_name()
{
    sv_list=$(ls $1/*.conf | sed 's/\.conf$/\.cfg/g')
    for sv in $sv_list
    do
	
    done
}


if ($1 == "") {
    echo "Error: host not defined!"
    exit 1;
}

