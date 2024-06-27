#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo "Comparing ground truth outputs to new processor"
cd .

while getopts "q" o; do
    case "${o}" in
        q)
            quiet=true
            ;;
        *)
            quiet=false
            ;;
    esac
done
shift $((OPTIND-1))

passed=0
total=0
# This only runs *.s files. How could you add *.c files?
for source_file in programs/*.{s,c}; do
    same=true
    program=$(echo "$source_file" | cut -d '.' -f1 | cut -d '/' -f 2)
    echo "Running $program"
    make $program.out
    ((total+=1))
    echo "Comparing writeback output for $program"
    cmp ./output/$program.wb ./correct_out/$program.wb && $same = true || $same = false
    echo "Comparing memory output for $program"
     # This takes the ground truth as the pattern copy and prints out what's unique in the ground truth
    if $quiet
    then 
        if diff ./output/$program.out ./correct_out/$program.out | grep -q "@@@"
        then
            same=false
        fi
    else
        if diff ./output/$program.out ./correct_out/$program.out | grep "@@@"
        then
            same=false
        fi
    fi
    echo "Comparing cycles per instruction for $program"
    printf "CPI for $program output: "
    grep "@@.*cycles" ./output/$program.out
    printf "CPI for $program correct_out: "
    grep "@@.*cycles" ./correct_out/$program.out

    # If either has unique elements starting with @@@, there is a difference and fail the test
    echo "Printing Passed or Failed"
    if $same
    then printf "${GREEN}@@@ Passed: $program ${NC}\n"
    ((passed+=1))
    else printf "${RED}@@@ Failed: $program ${NC}\n"
    $same = true
    fi
done
echo $passed " out of " $total "total tests passed"
