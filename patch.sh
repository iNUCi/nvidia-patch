#!/bin/bash
# halt on any error for safety and proper pipe handling
set -euo pipefail ; # <- this semicolon and comment make options apply
# even when script is corrupt by CRLF line terminators (issue #75)
# empty line must follow this comment for immediate fail with CRLF newlines

backup_path="/opt/nvidia/libnvidia-encode-backup"
silent_flag=''
manual_driver_version=''
flatpak_flag=''
backup_suffix=''

print_usage() { printf '
SYNOPSIS
       patch.sh [-s] [-r|-h|-c VERSION|-l|-f]

DESCRIPTION
       The patch for Nvidia drivers to remove NVENC session limit

       -s             Silent mode (No output)
       -r             Rollback to original (Restore lib from backup)
       -h             Print this help message
       -c VERSION     Check if version VERSION supported by this patch.
                      Returns true exit code (0) if version is supported.
       -l             List supported driver versions
       -d VERSION     Use VERSION driver version when looking for libraries
                      instead of using nvidia-smi to detect it.
       -f             Enable support for Flatpak NVIDIA drivers.
       -j             Output the patch list to stdout as JSON
'
}

# shellcheck disable=SC2209
opmode="patch"

while getopts 'rshjc:ld:f' flag; do
    case "${flag}" in
        r) opmode="${opmode}rollback" ;;
        s) silent_flag='true' ;;
        h) opmode="${opmode}help" ;;
        c) opmode="${opmode}checkversion" ; checked_version="$OPTARG" ;;
        l) opmode="${opmode}listversions" ;;
        d) manual_driver_version="$OPTARG" ;;
        f) flatpak_flag='true' ;;
        j) opmode="dump" ;;
        *) echo "Incorrect option specified in command line" ; exit 2 ;;
    esac
done

if [[ $silent_flag ]]; then
    exec 1> /dev/null
fi

if [[ $flatpak_flag ]]; then
    backup_suffix='.flatpak'
    echo "WARNING: Flatpak flag enabled (-f), modifying ONLY the Flatpak driver."
fi

declare -A patch_list=(
    ["375.39"]='s/\x85\xC0\x89\xC5\x75\x18/\x29\xC0\x89\xC5\x90\x90/g'
    ["390.77"]='s/\x85\xC0\x89\xC5\x75\x18/\x29\xC0\x89\xC5\x90\x90/g'
    ["390.87"]='s/\x85\xC0\x89\xC5\x75\x18/\x29\xC0\x89\xC5\x90\x90/g'
    ["390.147"]='s/\x85\xC0\x89\xC5\x75\x18/\x29\xC0\x89\xC5\x90\x90/g'
    ["396.24"]='s/\x85\xC0\x89\xC5\x0F\x85\x96\x00\x00\x00/\x29\xC0\x89\xC5\x90\x90\x90\x90\x90\x90/g'
    ["396.26"]='s/\x85\xC0\x89\xC5\x0F\x85\x96\x00\x00\x00/\x29\xC0\x89\xC5\x90\x90\x90\x90\x90\x90/g'
    ["396.37"]='s/\x85\xC0\x89\xC5\x0F\x85\x96\x00\x00\x00/\x29\xC0\x89\xC5\x90\x90\x90\x90\x90\x90/g' #added info from https://github.com/keylase/nvidia-patch/issues/6#issuecomment-406895356
    # break nvenc.c:236,layout asm,step-mode,step,break *0x00007fff89f9ba45
    # libnvidia-encode.so @ 0x15a45; test->sub, jne->nop-nop-nop-nop-nop-nop
    ["396.54"]='s/\x85\xC0\x89\xC5\x0F\x85\x96\x00\x00\x00/\x29\xC0\x89\xC5\x90\x90\x90\x90\x90\x90/g'
    ["410.48"]='s/\x85\xC0\x89\xC5\x0F\x85\x96\x00\x00\x00/\x29\xC0\x89\xC5\x90\x90\x90\x90\x90\x90/g'
    ["410.57"]='s/\x85\xC0\x89\xC5\x0F\x85\x96\x00\x00\x00/\x29\xC0\x89\xC5\x90\x90\x90\x90\x90\x90/g'
    ["410.73"]='s/\x85\xC0\x89\xC5\x0F\x85\x96\x00\x00\x00/\x29\xC0\x89\xC5\x90\x90\x90\x90\x90\x90/g'
    ["410.78"]='s/\x85\xC0\x89\xC5\x0F\x85\x96\x00\x00\x00/\x29\xC0\x89\xC5\x90\x90\x90\x90\x90\x90/g'
    ["410.79"]='s/\x85\xC0\x89\xC5\x0F\x85\x96\x00\x00\x00/\x29\xC0\x89\xC5\x90\x90\x90\x90\x90\x90/g'
    ["410.93"]='s/\x85\xC0\x89\xC5\x0F\x85\x96\x00\x00\x00/\x29\xC0\x89\xC5\x90\x90\x90\x90\x90\x90/g'
    ["410.104"]='s/\x85\xC0\x89\xC5\x0F\x85\x96\x00\x00\x00/\x29\xC0\x89\xC5\x90\x90\x90\x90\x90\x90/g'
    ["415.18"]='s/\x00\x00\x00\x84\xc0\x0f\x84\x40\xfd\xff\xff/\x00\x00\x00\x84\xc0\x90\x90\x90\x90\x90\x90/g'
    ["415.25"]='s/\x00\x00\x00\x84\xc0\x0f\x84\x40\xfd\xff\xff/\x00\x00\x00\x84\xc0\x90\x90\x90\x90\x90\x90/g'
    ["415.27"]='s/\x00\x00\x00\x84\xc0\x0f\x84\x40\xfd\xff\xff/\x00\x00\x00\x84\xc0\x90\x90\x90\x90\x90\x90/g'
    ["418.30"]='s/\x00\x00\x00\x84\xc0\x0f\x84\x40\xfd\xff\xff/\x00\x00\x00\x84\xc0\x90\x90\x90\x90\x90\x90/g'
    ["418.43"]='s/\x00\x00\x00\x84\xc0\x0f\x84\x40\xfd\xff\xff/\x00\x00\x00\x84\xc0\x90\x90\x90\x90\x90\x90/g'
    ["418.56"]='s/\x00\x00\x00\x84\xc0\x0f\x84\x40\xfd\xff\xff/\x00\x00\x00\x84\xc0\x90\x90\x90\x90\x90\x90/g'
    ["418.67"]='s/\x00\x00\x00\x84\xc0\x0f\x84\x40\xfd\xff\xff/\x00\x00\x00\x84\xc0\x90\x90\x90\x90\x90\x90/g'
    ["418.74"]='s/\x00\x00\x00\x84\xc0\x0f\x84\x0f\xfd\xff\xff/\x00\x00\x00\x84\xc0\x90\x90\x90\x90\x90\x90/g'
    ["418.87.00"]='s/\x00\x00\x00\x84\xc0\x0f\x84\x0f\xfd\xff\xff/\x00\x00\x00\x84\xc0\x90\x90\x90\x90\x90\x90/g'
    ["418.87.01"]='s/\x00\x00\x00\x84\xc0\x0f\x84\x0f\xfd\xff\xff/\x00\x00\x00\x84\xc0\x90\x90\x90\x90\x90\x90/g'
    ["418.88"]='s/\x00\x00\x00\x84\xc0\x0f\x84\x0f\xfd\xff\xff/\x00\x00\x00\x84\xc0\x90\x90\x90\x90\x90\x90/g'
    ["418.113"]='s/\x00\x00\x00\x84\xc0\x0f\x84\x0f\xfd\xff\xff/\x00\x00\x00\x84\xc0\x90\x90\x90\x90\x90\x90/g'
    ["430.09"]='s/\x00\x00\x00\x84\xc0\x0f\x84\x0f\xfd\xff\xff/\x00\x00\x00\x84\xc0\x90\x90\x90\x90\x90\x90/g'
    ["430.14"]='s/\x00\x00\x00\x84\xc0\x0f\x84\x0f\xfd\xff\xff/\x00\x00\x00\x84\xc0\x90\x90\x90\x90\x90\x90/g'
    ["430.26"]='s/\x00\x00\x00\x84\xc0\x0f\x84\x0f\xfd\xff\xff/\x00\x00\x00\x84\xc0\x90\x90\x90\x90\x90\x90/g'
    ["430.34"]='s/\x00\x00\x00\x84\xc0\x0f\x84\x0f\xfd\xff\xff/\x00\x00\x00\x84\xc0\x90\x90\x90\x90\x90\x90/g'
    ["430.40"]='s/\x00\x00\x00\x84\xc0\x0f\x84\x0f\xfd\xff\xff/\x00\x00\x00\x84\xc0\x90\x90\x90\x90\x90\x90/g'
    ["430.50"]='s/\x00\x00\x00\x84\xc0\x0f\x84\x0f\xfd\xff\xff/\x00\x00\x00\x84\xc0\x90\x90\x90\x90\x90\x90/g'
    ["430.64"]='s/\x00\x00\x00\x84\xc0\x0f\x84\x0f\xfd\xff\xff/\x00\x00\x00\x84\xc0\x90\x90\x90\x90\x90\x90/g'
    ["435.17"]='s/\x00\x00\x00\x84\xc0\x0f\x84\x0f\xfd\xff\xff/\x00\x00\x00\x84\xc0\x90\x90\x90\x90\x90\x90/g'
    ["435.21"]='s/\x00\x00\x00\x84\xc0\x0f\x84\x0f\xfd\xff\xff/\x00\x00\x00\x84\xc0\x90\x90\x90\x90\x90\x90/g'
    ["440.26"]='s/\x85\xc0\x41\x89\xc4\x75\x1f/\x31\xc0\x41\x89\xc4\x75\x1f/g'
    ["440.31"]='s/\x85\xc0\x41\x89\xc4\x75\x1f/\x31\xc0\x41\x89\xc4\x75\x1f/g'
    ["440.33.01"]='s/\x85\xc0\x41\x89\xc4\x75\x1f/\x31\xc0\x41\x89\xc4\x75\x1f/g'
    ["440.36"]='s/\x85\xc0\x41\x89\xc4\x75\x1f/\x31\xc0\x41\x89\xc4\x75\x1f/g'
    ["440.43.01"]='s/\x85\xc0\x41\x89\xc4\x75\x1f/\x31\xc0\x41\x89\xc4\x75\x1f/g'
    ["440.44"]='s/\x85\xc0\x41\x89\xc4\x75\x1f/\x31\xc0\x41\x89\xc4\x75\x1f/g'
    ["440.48.02"]='s/\x85\xc0\x41\x89\xc4\x75\x1f/\x31\xc0\x41\x89\xc4\x75\x1f/g'
    ["440.58.01"]='s/\x85\xc0\x41\x89\xc4\x75\x1f/\x31\xc0\x41\x89\xc4\x75\x1f/g'
    ["440.58.02"]='s/\x85\xc0\x41\x89\xc4\x75\x1f/\x31\xc0\x41\x89\xc4\x75\x1f/g'
    ["440.59"]='s/\x85\xc0\x41\x89\xc4\x75\x1f/\x31\xc0\x41\x89\xc4\x75\x1f/g'
    ["440.64"]='s/\x85\xc0\x41\x89\xc4\x75\x1f/\x31\xc0\x41\x89\xc4\x75\x1f/g'
    ["440.64.00"]='s/\x85\xc0\x41\x89\xc4\x75\x1f/\x31\xc0\x41\x89\xc4\x75\x1f/g'
    ["440.66.02"]='s/\x85\xc0\x41\x89\xc4\x75\x1f/\x31\xc0\x41\x89\xc4\x75\x1f/g'
    ["440.66.03"]='s/\x85\xc0\x41\x89\xc4\x75\x1f/\x31\xc0\x41\x89\xc4\x75\x1f/g'
    ["440.66.04"]='s/\x85\xc0\x41\x89\xc4\x75\x1f/\x31\xc0\x41\x89\xc4\x75\x1f/g'
    ["440.66.08"]='s/\x85\xc0\x41\x89\xc4\x75\x1f/\x31\xc0\x41\x89\xc4\x75\x1f/g'
    ["440.66.09"]='s/\x85\xc0\x41\x89\xc4\x75\x1f/\x31\xc0\x41\x89\xc4\x75\x1f/g'
    ["440.66.11"]='s/\x85\xc0\x41\x89\xc4\x75\x1f/\x31\xc0\x41\x89\xc4\x75\x1f/g'
    ["440.66.12"]='s/\x85\xc0\x41\x89\xc4\x75\x1f/\x31\xc0\x41\x89\xc4\x75\x1f/g'
    ["440.66.14"]='s/\x85\xc0\x41\x89\xc4\x75\x1f/\x31\xc0\x41\x89\xc4\x75\x1f/g'
    ["440.66.15"]='s/\x85\xc0\x41\x89\xc4\x75\x1f/\x31\xc0\x41\x89\xc4\x75\x1f/g'
    ["440.66.17"]='s/\x85\xc0\x41\x89\xc4\x75\x1f/\x31\xc0\x41\x89\xc4\x75\x1f/g'
    ["440.82"]='s/\x85\xc0\x41\x89\xc4\x75\x1f/\x31\xc0\x41\x89\xc4\x75\x1f/g'
    ["440.95.01"]='s/\x85\xc0\x41\x89\xc4\x75\x1f/\x31\xc0\x41\x89\xc4\x75\x1f/g'
    ["440.100"]='s/\x85\xc0\x41\x89\xc4\x75\x1f/\x31\xc0\x41\x89\xc4\x75\x1f/g'
    ["440.118.02"]='s/\x85\xc0\x41\x89\xc4\x75\x1f/\x31\xc0\x41\x89\xc4\x75\x1f/g'
    ["450.36.06"]='s/\x85\xc0\x41\x89\xc4\x75\x1f/\x31\xc0\x41\x89\xc4\x75\x1f/g'
    ["450.51"]='s/\x85\xc0\x41\x89\xc4\x75\x1f/\x31\xc0\x41\x89\xc4\x75\x1f/g'
    ["450.51.05"]='s/\x85\xc0\x41\x89\xc4\x75\x1f/\x31\xc0\x41\x89\xc4\x75\x1f/g'
    ["450.51.06"]='s/\x85\xc0\x41\x89\xc4\x75\x1f/\x31\xc0\x41\x89\xc4\x75\x1f/g'
    ["450.56.01"]='s/\x85\xc0\x41\x89\xc4\x75\x1f/\x31\xc0\x41\x89\xc4\x75\x1f/g'
    ["450.56.02"]='s/\x85\xc0\x41\x89\xc4\x75\x1f/\x31\xc0\x41\x89\xc4\x75\x1f/g'
    ["450.56.06"]='s/\x85\xc0\x41\x89\xc4\x75\x1f/\x31\xc0\x41\x89\xc4\x75\x1f/g'
    ["450.56.11"]='s/\x85\xc0\x41\x89\xc4\x75\x1f/\x31\xc0\x41\x89\xc4\x75\x1f/g'
    ["450.57"]='s/\x85\xc0\x41\x89\xc4\x75\x1f/\x31\xc0\x41\x89\xc4\x75\x1f/g'
    ["450.66"]='s/\x85\xc0\x41\x89\xc4\x75\x1f/\x31\xc0\x41\x89\xc4\x75\x1f/g'
    ["450.80.02"]='s/\x85\xc0\x41\x89\xc4\x75\x1f/\x31\xc0\x41\x89\xc4\x75\x1f/g'
    ["450.102.04"]='s/\x85\xc0\x41\x89\xc4\x75\x1f/\x31\xc0\x41\x89\xc4\x75\x1f/g'
    ["455.22.04"]='s/\x85\xc0\x41\x89\xc4\x75\x1f/\x31\xc0\x41\x89\xc4\x75\x1f/g'
    ["455.23.04"]='s/\x85\xc0\x41\x89\xc4\x75\x1f/\x31\xc0\x41\x89\xc4\x75\x1f/g'
    ["455.23.05"]='s/\x85\xc0\x41\x89\xc4\x75\x1f/\x31\xc0\x41\x89\xc4\x75\x1f/g'
    ["455.26.01"]='s/\x85\xc0\x41\x89\xc4\x75\x1f/\x31\xc0\x41\x89\xc4\x75\x1f/g'
    ["455.26.02"]='s/\x85\xc0\x41\x89\xc4\x75\x1f/\x31\xc0\x41\x89\xc4\x75\x1f/g'
    ["455.28"]='s/\x85\xc0\x41\x89\xc4\x75\x1f/\x31\xc0\x41\x89\xc4\x75\x1f/g'
    ["455.32.00"]='s/\x85\xc0\x41\x89\xc4\x75\x1f/\x31\xc0\x41\x89\xc4\x75\x1f/g'
    ["455.38"]='s/\x85\xc0\x41\x89\xc4\x75\x1f/\x31\xc0\x41\x89\xc4\x75\x1f/g'
    ["455.45.01"]='s/\x85\xc0\x41\x89\xc4\x75\x1f/\x31\xc0\x41\x89\xc4\x75\x1f/g'
    ["455.46.01"]='s/\x85\xc0\x41\x89\xc4\x75\x1f/\x31\xc0\x41\x89\xc4\x75\x1f/g'
    ["455.46.02"]='s/\x85\xc0\x41\x89\xc4\x75\x1f/\x31\xc0\x41\x89\xc4\x75\x1f/g'
    ["455.46.04"]='s/\x85\xc0\x41\x89\xc4\x75\x1f/\x31\xc0\x41\x89\xc4\x75\x1f/g'
    ["455.50.02"]='s/\x85\xc0\x41\x89\xc4\x75\x1f/\x31\xc0\x41\x89\xc4\x75\x1f/g'
    ["455.50.04"]='s/\x85\xc0\x41\x89\xc4\x75\x1f/\x31\xc0\x41\x89\xc4\x75\x1f/g'
    ["455.50.05"]='s/\x85\xc0\x41\x89\xc4\x75\x1f/\x31\xc0\x41\x89\xc4\x75\x1f/g'
    ["455.50.07"]='s/\x85\xc0\x41\x89\xc4\x75\x1f/\x31\xc0\x41\x89\xc4\x75\x1f/g'
    ["455.50.10"]='s/\x85\xc0\x41\x89\xc4\x75\x1f/\x31\xc0\x41\x89\xc4\x75\x1f/g'
    ["460.27.04"]='s/\x22\xff\xff\x85\xc0\x41\x89\xc4\x0f\x85/\x22\xff\xff\x31\xc0\x41\x89\xc4\x0f\x85/g'
    ["460.32.03"]='s/\x22\xff\xff\x85\xc0\x41\x89\xc4\x0f\x85/\x22\xff\xff\x31\xc0\x41\x89\xc4\x0f\x85/g'
    ["460.39"]='s/\x22\xff\xff\x85\xc0\x41\x89\xc4\x0f\x85/\x22\xff\xff\x31\xc0\x41\x89\xc4\x0f\x85/g'
    ["460.56"]='s/\x22\xff\xff\x85\xc0\x41\x89\xc4\x0f\x85/\x22\xff\xff\x31\xc0\x41\x89\xc4\x0f\x85/g'
    ["460.67"]='s/\x22\xff\xff\x85\xc0\x41\x89\xc4\x0f\x85/\x22\xff\xff\x31\xc0\x41\x89\xc4\x0f\x85/g'
    ["460.73.01"]='s/\x22\xff\xff\x85\xc0\x41\x89\xc4\x0f\x85/\x22\xff\xff\x31\xc0\x41\x89\xc4\x0f\x85/g'
    ["460.80"]='s/\x22\xff\xff\x85\xc0\x41\x89\xc4\x0f\x85/\x22\xff\xff\x31\xc0\x41\x89\xc4\x0f\x85/g'
    ["460.84"]='s/\x22\xff\xff\x85\xc0\x41\x89\xc4\x0f\x85/\x22\xff\xff\x31\xc0\x41\x89\xc4\x0f\x85/g'
    ["460.91.03"]='s/\x22\xff\xff\x85\xc0\x41\x89\xc4\x0f\x85/\x22\xff\xff\x31\xc0\x41\x89\xc4\x0f\x85/g'
    ["465.19.01"]='s/\xe8\xc5\x20\xff\xff\x85\xc0\x41\x89\xc4/\xe8\xc5\x20\xff\xff\x29\xc0\x41\x89\xc4/g'
    ["465.24.02"]='s/\xe8\xc5\x20\xff\xff\x85\xc0\x41\x89\xc4/\xe8\xc5\x20\xff\xff\x29\xc0\x41\x89\xc4/g'
    ["465.27"]='s/\xe8\xc5\x20\xff\xff\x85\xc0\x41\x89\xc4/\xe8\xc5\x20\xff\xff\x29\xc0\x41\x89\xc4/g'
    ["465.31"]='s/\xe8\xc5\x20\xff\xff\x85\xc0\x41\x89\xc4/\xe8\xc5\x20\xff\xff\x29\xc0\x41\x89\xc4/g'
    ["470.42.01"]='s/\xe8\x25\x1C\xff\xff\x85\xc0\x41\x89\xc4/\xe8\x25\x1C\xff\xff\x29\xc0\x41\x89\xc4/g'
    ["470.57.02"]='s/\xe8\x25\x1C\xff\xff\x85\xc0\x41\x89\xc4/\xe8\x25\x1C\xff\xff\x29\xc0\x41\x89\xc4/g'
    ["470.62.02"]='s/\xe8\x25\x1C\xff\xff\x85\xc0\x41\x89\xc4/\xe8\x25\x1C\xff\xff\x29\xc0\x41\x89\xc4/g'
    ["470.62.05"]='s/\xe8\x25\x1C\xff\xff\x85\xc0\x41\x89\xc4/\xe8\x25\x1C\xff\xff\x29\xc0\x41\x89\xc4/g'
    ["470.63.01"]='s/\xe8\x25\x1C\xff\xff\x85\xc0\x41\x89\xc4/\xe8\x25\x1C\xff\xff\x29\xc0\x41\x89\xc4/g'
    ["470.74"]='s/\xe8\x25\x1C\xff\xff\x85\xc0\x41\x89\xc4/\xe8\x25\x1C\xff\xff\x29\xc0\x41\x89\xc4/g'
    ["470.82.00"]='s/\xe8\x25\x1C\xff\xff\x85\xc0\x41\x89\xc4/\xe8\x25\x1C\xff\xff\x29\xc0\x41\x89\xc4/g'
    ["470.82.01"]='s/\xe8\x25\x1C\xff\xff\x85\xc0\x41\x89\xc4/\xe8\x25\x1C\xff\xff\x29\xc0\x41\x89\xc4/g'
    ["470.86"]='s/\xe8\x25\x1C\xff\xff\x85\xc0\x41\x89\xc4/\xe8\x25\x1C\xff\xff\x29\xc0\x41\x89\xc4/g'
    ["470.94"]='s/\xe8\x25\x1C\xff\xff\x85\xc0\x41\x89\xc4/\xe8\x25\x1C\xff\xff\x29\xc0\x41\x89\xc4/g'
    ["470.103.01"]='s/\xe8\x25\x1C\xff\xff\x85\xc0\x41\x89\xc4/\xe8\x25\x1C\xff\xff\x29\xc0\x41\x89\xc4/g'
    ["470.129.06"]='s/\xe8\x25\x1C\xff\xff\x85\xc0\x41\x89\xc4/\xe8\x25\x1C\xff\xff\x29\xc0\x41\x89\xc4/g'
    ["470.141.03"]='s/\xe8\x25\x1C\xff\xff\x85\xc0\x41\x89\xc4/\xe8\x25\x1C\xff\xff\x29\xc0\x41\x89\xc4/g'
    ["470.161.03"]='s/\xe8\x25\x1C\xff\xff\x85\xc0\x41\x89\xc4/\xe8\x25\x1C\xff\xff\x29\xc0\x41\x89\xc4/g'
    ["470.182.03"]='s/\xe8\x55\x1a\xff\xff\x85\xc0\x41\x89\xc4/\xe8\x55\x1a\xff\xff\x29\xc0\x41\x89\xc4/g'
    ["470.199.02"]='s/\xe8\x55\x1a\xff\xff\x85\xc0\x41\x89\xc4/\xe8\x55\x1a\xff\xff\x29\xc0\x41\x89\xc4/g'
    ["470.223.02"]='s/\xe8\x55\x1a\xff\xff\x85\xc0\x41\x89\xc4/\xe8\x55\x1a\xff\xff\x29\xc0\x41\x89\xc4/g'
    ["470.239.06"]='s/\xe8\x55\x1a\xff\xff\x85\xc0\x41\x89\xc4/\xe8\x55\x1a\xff\xff\x29\xc0\x41\x89\xc4/g'
    ["470.256.02"]='s/\xe8\x55\x1a\xff\xff\x85\xc0\x41\x89\xc4/\xe8\x55\x1a\xff\xff\x29\xc0\x41\x89\xc4/g'
    ["495.29.05"]='s/\xe8\x35\x1f\xff\xff\x85\xc0\x41\x89\xc4/\xe8\x35\x1f\xff\xff\x29\xc0\x41\x89\xc4/g'
    ["495.44"]='s/\xe8\x35\x1f\xff\xff\x85\xc0\x41\x89\xc4/\xe8\x35\x1f\xff\xff\x29\xc0\x41\x89\xc4/g'
    ["495.46"]='s/\xe8\x35\x1f\xff\xff\x85\xc0\x41\x89\xc4/\xe8\x35\x1f\xff\xff\x29\xc0\x41\x89\xc4/g'
    ["510.39.01"]='s/\xe8\x15\x1f\xff\xff\x85\xc0\x41\x89\xc4/\xe8\x15\x1f\xff\xff\x29\xc0\x41\x89\xc4/g'
    ["510.47.03"]='s/\xe8\x15\x1f\xff\xff\x85\xc0\x41\x89\xc4/\xe8\x15\x1f\xff\xff\x29\xc0\x41\x89\xc4/g'
    ["510.54"]='s/\xe8\x15\x1f\xff\xff\x85\xc0\x41\x89\xc4/\xe8\x15\x1f\xff\xff\x29\xc0\x41\x89\xc4/g'
    ["510.60.02"]='s/\xe8\x15\x1f\xff\xff\x85\xc0\x41\x89\xc4/\xe8\x15\x1f\xff\xff\x29\xc0\x41\x89\xc4/g'
    ["510.68.02"]='s/\xe8\x15\x1f\xff\xff\x85\xc0\x41\x89\xc4/\xe8\x15\x1f\xff\xff\x29\xc0\x41\x89\xc4/g'
    ["510.73.05"]='s/\xe8\x15\x1f\xff\xff\x85\xc0\x41\x89\xc4/\xe8\x15\x1f\xff\xff\x29\xc0\x41\x89\xc4/g'
    ["510.73.08"]='s/\xe8\x15\x1f\xff\xff\x85\xc0\x41\x89\xc4/\xe8\x15\x1f\xff\xff\x29\xc0\x41\x89\xc4/g'
    ["510.85.02"]='s/\xe8\x15\x1f\xff\xff\x85\xc0\x41\x89\xc4/\xe8\x15\x1f\xff\xff\x29\xc0\x41\x89\xc4/g'
    ["510.108.03"]='s/\xe8\x15\x1f\xff\xff\x85\xc0\x41\x89\xc4/\xe8\x15\x1f\xff\xff\x29\xc0\x41\x89\xc4/g'
    ["515.43.04"]='s/\xe8\xd5\x1e\xff\xff\x85\xc0\x41\x89\xc4/\xe8\xd5\x1e\xff\xff\x29\xc0\x41\x89\xc4/g'
    ["515.48.07"]='s/\xe8\xd5\x1e\xff\xff\x85\xc0\x41\x89\xc4/\xe8\xd5\x1e\xff\xff\x29\xc0\x41\x89\xc4/g'
    ["515.57"]='s/\xe8\xd5\x1e\xff\xff\x85\xc0\x41\x89\xc4/\xe8\xd5\x1e\xff\xff\x29\xc0\x41\x89\xc4/g'
    ["515.65.01"]='s/\xe8\xd5\x1e\xff\xff\x85\xc0\x41\x89\xc4/\xe8\xd5\x1e\xff\xff\x29\xc0\x41\x89\xc4/g'
    ["515.76"]='s/\xe8\xd5\x1e\xff\xff\x85\xc0\x41\x89\xc4/\xe8\xd5\x1e\xff\xff\x29\xc0\x41\x89\xc4/g'
    ["515.86.01"]='s/\xe8\xd5\x1e\xff\xff\x85\xc0\x41\x89\xc4/\xe8\xd5\x1e\xff\xff\x29\xc0\x41\x89\xc4/g'
    ["515.105.01"]='s/\xe8\x95\x1c\xff\xff\x85\xc0\x41\x89\xc4/\xe8\x95\x1c\xff\xff\x29\xc0\x41\x89\xc4/g'
    ["520.56.06"]='s/\xe8\xa5\xc8\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\xa5\xc8\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["520.61.05"]='s/\xe8\xa5\xc8\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\xa5\xc8\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["525.60.11"]='s/\xe8\xf5\xc6\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\xf5\xc6\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["525.60.13"]='s/\xe8\xf5\xc6\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\xf5\xc6\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["525.78.01"]='s/\xe8\xf5\xc6\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\xf5\xc6\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["525.85.05"]='s/\xe8\xf5\xc6\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\xf5\xc6\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["525.85.12"]='s/\xe8\xf5\xc6\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\xf5\xc6\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["525.89.02"]='s/\xe8\x65\xc7\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\x65\xc7\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["525.105.17"]='s/\xe8\x55\xc4\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\x55\xc4\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["525.116.03"]='s/\xe8\x55\xc4\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\x55\xc4\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["525.116.04"]='s/\xe8\x55\xc4\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\x55\xc4\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["525.125.06"]='s/\xe8\x55\xc4\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\x55\xc4\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["525.147.05"]='s/\xe8\x55\xc4\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\x55\xc4\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["530.30.02"]='s/\xe8\x15\x6f\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\x15\x6f\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["530.41.03"]='s/\xe8\xc5\x6b\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\xc5\x6b\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["535.43.02"]='s/\xe8\xa5\x9e\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\xa5\x9e\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["535.43.25"]='s/\xe8\xa5\x9f\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\xa5\x9f\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["535.54.03"]='s/\xe8\xa5\x9e\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\xa5\x9e\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["535.86.05"]='s/\xe8\x05\xa0\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\x05\xa0\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["535.86.10"]='s/\xe8\x05\xa0\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\x05\xa0\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["535.98"]='s/\xe8\xa5\x9f\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\xa5\x9f\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["535.104.05"]='s/\xe8\xa5\x9f\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\xa5\x9f\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["535.104.12"]='s/\xe8\xa5\x9f\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\xa5\x9f\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["535.113.01"]='s/\xe8\xa5\x9f\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\xa5\x9f\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["535.129.03"]='s/\xe8\xa5\x9f\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\xa5\x9f\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["535.146.02"]='s/\xe8\xa5\x9f\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\xa5\x9f\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["535.154.05"]='s/\xe8\xa5\x9f\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\xa5\x9f\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["535.161.07"]='s/\xe8\xa5\x9f\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\xa5\x9f\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["535.161.08"]='s/\xe8\xa5\x9f\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\xa5\x9f\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["535.171.04"]='s/\xe8\xa5\x9f\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\xa5\x9f\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["535.183.01"]='s/\xe8\xa5\x9f\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\xa5\x9f\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["535.183.06"]='s/\xe8\xa5\x9f\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\xa5\x9f\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["535.216.01"]='s/\xe8\xa5\x9f\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\xa5\x9f\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["535.230.02"]='s/\xe8\xa5\x9f\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\xa5\x9f\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["535.216.03"]='s/\xe8\xa5\x9f\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\xa5\x9f\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["535.247.01"]='s/\xe8\xa5\x9f\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\xa5\x9f\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["545.23.06"]='s/\xe8\xc5\x8f\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\xc5\x8f\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["545.23.08"]='s/\xe8\xc5\x8f\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\xc5\x8f\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["545.29.02"]='s/\xe8\xc5\x8f\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\xc5\x8f\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["545.29.06"]='s/\xe8\xc5\x8f\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\xc5\x8f\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["550.40.07"]='s/\xe8\x35\x54\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\x35\x54\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["550.54.14"]='s/\xe8\x25\x54\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\x25\x54\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["550.54.15"]='s/\xe8\x25\x54\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\x25\x54\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["550.67"]='s/\xe8\x25\x54\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\x25\x54\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["550.76"]='s/\xe8\x25\x54\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\x25\x54\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["550.78"]='s/\xe8\x25\x54\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\x25\x54\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["550.90.07"]='s/\xe8\x25\x54\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\x25\x54\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["550.100"]='s/\xe8\xf5\x52\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\xf5\x52\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["550.107.02"]='s/\xe8\xf5\x52\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\xf5\x52\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["550.120"]='s/\xe8\xf5\x52\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\xf5\x52\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["550.127.05"]='s/\xe8\xf5\x52\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\xf5\x52\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["550.127.08"]='s/\xe8\xf5\x52\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\xf5\x52\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["550.135"]='s/\xe8\xf5\x52\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\xf5\x52\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["550.142"]='s/\xe8\xf5\x52\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\xf5\x52\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["550.163.01"]='s/\xe8\xf5\x52\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\xf5\x52\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["555.42.02"]='s/\xe8\x25\x43\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\x25\x43\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["555.52.04"]='s/\xe8\x25\x43\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\x25\x43\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["555.58"]='s/\xe8\x25\x43\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\x25\x43\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["555.58.02"]='s/\xe8\x25\x43\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\x25\x43\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["560.28.03"]='s/\xe8\x35\x3e\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\x35\x3e\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["560.35.03"]='s/\xe8\x35\x3e\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\x35\x3e\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["560.35.05"]='s/\xe8\x35\x3e\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\x35\x3e\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["565.57.01"]='s/\xe8\x15\x34\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\x15\x34\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["565.77"]='s/\xe8\x15\x34\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\x15\x34\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["570.86.15"]='s/\xe8\x45\x30\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\x45\x30\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["570.86.16"]='s/\xe8\x45\x30\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\x45\x30\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["570.124.04"]='s/\xe8\x45\x30\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\x45\x30\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["570.124.06"]='s/\xe8\x45\x30\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\x45\x30\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["570.133.07"]='s/\xe8\x45\x30\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\x45\x30\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["570.133.20"]='s/\xe8\x45\x30\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\x45\x30\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["570.144"]='s/\xe8\x45\x30\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\x45\x30\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["570.148.08"]='s/\xe8\x45\x30\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\x45\x30\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["570.153.02"]='s/\xe8\x45\x30\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\x45\x30\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["570.158.01"]='s/\xe8\x45\x30\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\x45\x30\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["570.169"]='s/\xe8\x45\x30\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\x45\x30\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["570.172.08"]='s/\xe8\x45\x30\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\x45\x30\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["575.51.02"]='s/\xe8\xb5\x2f\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\xb5\x2f\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["575.57.08"]='s/\xe8\xb5\x2f\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\xb5\x2f\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["575.64"]='s/\xe8\xb5\x2f\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\xb5\x2f\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["575.64.03"]='s/\xe8\xb5\x2f\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\xb5\x2f\xfe\xff\x29\xc0\x41\x89\xc4/g'
    ["575.64.05"]='s/\xe8\xb5\x2f\xfe\xff\x85\xc0\x41\x89\xc4/\xe8\xb5\x2f\xfe\xff\x29\xc0\x41\x89\xc4/g'
)

check_version_supported () {
    local ver="$1"
    [[ "${patch_list[$ver]+isset}" ]]
}

get_flatpak_driver_path () {
    # Flatpak's package versioning replaces '.' by '-'
    version="$(echo "$1" | tr '.' '-')"
    # Attempts to patch system flatpak
    if path=$(flatpak info --show-location "org.freedesktop.Platform.GL.nvidia-${version}" 2>/dev/null); then
        echo "$path/files/lib"
    # If it isn't found will login as the user that envoked sudo & patch this version
    elif path=$(su -c - ${SUDO_USER} 'flatpak info --show-location "org.freedesktop.Platform.GL.nvidia-'${version}'"'); then
        echo "$path/files/lib"
    fi
}

get_supported_versions () {
    for drv in "${!patch_list[@]}"; do
        echo "$drv"
    done | sort -t. -n
    return 0
}

patch_common () {
    NVIDIA_SMI="$(command -v nvidia-smi || true)"
    if [[ ! "$NVIDIA_SMI" ]] ; then
        echo 'nvidia-smi utility not found. Probably driver is not installed.'
        exit 1
    fi

    if [[ "$manual_driver_version" ]]; then
        driver_version="$manual_driver_version"

        echo "Using manually entered nvidia driver version: $driver_version"
    else
        cmd="$NVIDIA_SMI --query-gpu=driver_version --format=csv,noheader,nounits"
        driver_versions_list=$($cmd) || (
            ret_code=$?
            echo "Can not detect nvidia driver version."
            echo "CMD: \"$cmd\""
            echo "Result: \"$driver_versions_list\""
            echo "nvidia-smi retcode: $ret_code"
            exit 1
        )
        driver_version=$(echo "$driver_versions_list" | head -n 1)

        echo "Detected nvidia driver version: $driver_version"
    fi

    if ! check_version_supported "$driver_version" ; then
        echo "Patch for this ($driver_version) nvidia driver not found."
        echo "Patch is available for versions: "
        get_supported_versions
        exit 1
    fi

    patch="${patch_list[$driver_version]}"
    driver_maj_version=${driver_version%%.*}
    if [[ $driver_maj_version -ge "415" && $driver_maj_version -le "435" ]]; then
        object='libnvcuvid.so'
    else
        object='libnvidia-encode.so'
    fi
    echo $object

    if [[ $flatpak_flag ]]; then
        driver_dir=$(get_flatpak_driver_path "$driver_version")
        if [ -z "$driver_dir" ]; then
            echo "ERROR: Flatpak package for driver $driver_version does not appear to be installed."
            echo "Try rebooting your computer and/or running 'flatpak update'."
            exit 1
        fi
        # return early because the code below is out of scope for the Flatpak driver
        return 0
    fi

    declare -a driver_locations=(
        '/usr/lib/x86_64-linux-gnu'
        '/usr/lib/x86_64-linux-gnu/nvidia/current/'
        '/usr/lib/x86_64-linux-gnu/nvidia/tesla/'
        "/usr/lib/x86_64-linux-gnu/nvidia/tesla-${driver_version%%.*}/"
        '/usr/lib64'
        '/usr/lib'
        "/usr/lib/nvidia-${driver_version%%.*}"
    )

    dir_found=''
    for driver_dir in "${driver_locations[@]}" ; do
        if [[ -e "$driver_dir/$object.$driver_version" ]]; then
            dir_found='true'
            break
        fi
    done

    [[ "$dir_found" ]] || { echo "ERROR: cannot detect driver directory"; exit 1; }

}

ensure_bytes_are_valid () {
    driver_file="$driver_dir/$object.$driver_version"
    original_bytes=$(awk -F / '$2 { print $2 }' <<< "$patch")
    patched_bytes=$(awk -F / '$3 { print $3 }' <<< "$patch")
    if LC_ALL=C grep -qaP "$original_bytes" "$driver_file"; then
        return 0 # file is ready to be patched
    fi
    if LC_ALL=C grep -qaP "$patched_bytes" "$driver_file"; then
        return 0 # file is likely patched already
    fi
    echo "Error: Could not find bytes '$original_bytes' to patch in '$driver_file'."
    exit 1
}

rollback () {
    patch_common
    if [[ -f "$backup_path/$object.$driver_version$backup_suffix" ]]; then
        cp -p "$backup_path/$object.$driver_version$backup_suffix" \
           "$driver_dir/$object.$driver_version"
        echo "Restore from backup $object.$driver_version$backup_suffix"
    else
        echo "Backup not found. Try to patch first."
        exit 1
    fi
}

patch () {
    patch_common
    ensure_bytes_are_valid
    if [[ -f "$backup_path/$object.$driver_version$backup_suffix" ]]; then
        bkp_hash="$(sha1sum "$backup_path/$object.$driver_version$backup_suffix" | cut -f1 -d\ )"
        drv_hash="$(sha1sum "$driver_dir/$object.$driver_version" | cut -f1 -d\ )"
        if [[ "$bkp_hash" != "$drv_hash" ]] ; then
            echo "Backup exists and driver file differ from backup. Skipping patch."
            return 0
        fi
    else
        echo "Attention! Backup not found. Copying current $object to backup."
        mkdir -p "$backup_path"
        cp -p "$driver_dir/$object.$driver_version" \
           "$backup_path/$object.$driver_version$backup_suffix"
    fi
    sha1sum "$backup_path/$object.$driver_version$backup_suffix"
    sed "$patch" "$backup_path/$object.$driver_version$backup_suffix" > \
      "${PATCH_OUTPUT_DIR-$driver_dir}/$object.$driver_version"
    sha1sum "${PATCH_OUTPUT_DIR-$driver_dir}/$object.$driver_version"
    ldconfig
    echo "Patched!"
}

query_version_support () {
    if check_version_supported "$checked_version" ; then
        echo "SUPPORTED"
        exit 0
    else
        echo "NOT SUPPORTED"
        exit 1
    fi
}

list_supported_versions () {
    get_supported_versions
}

dump_patches () {
    for i in "${!patch_list[@]}"
    do
        echo "$i"
        echo "${patch_list[$i]}"
    done |
    jq --sort-keys -n -R 'reduce inputs as $i ({}; . + { ($i): (input|(tonumber? // .)) })'
}

case "${opmode}" in
    patch) patch ;;
    patchrollback) rollback ;;
    patchhelp) print_usage ; exit 2 ;;
    patchcheckversion) query_version_support ;;
    patchlistversions) list_supported_versions ;;
    dump) dump_patches ;;
    *) echo "Incorrect combination of flags. Use option -h to get help."
       exit 2 ;;
esac
