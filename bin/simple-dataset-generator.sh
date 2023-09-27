#!/bin/bash

CNT=20
MAX_CNT=2000000
OUT_FILE=cdc-dataset.sql

usage() {
	echo "Usage: $0 [-f output_filename ] [-s start_count ] [-e end_count]"
	exit
}

while getopts 'f:s:e:h' OPT; do
	case "$OPT" in
		f) OUT_FILE="$OPTARG";;
		s) CNT=$OPTARG;;
		e) MAX_CNT=$OPTARG;;
		h) usage;;
		?) usage; exit 1;;
	esac
done

echo "SET STREAMING ON;" > $OUT_FILE

while [ $CNT -le $MAX_CNT ]; do
	echo "INSERT INTO CDC_CACHE VALUES ($CNT, $CNT, '-$CNT+$CNT');" >> $OUT_FILE
	echo "Line: $CNT"
	(( CNT++ ))
done

echo "SET STREAMING OFF;" >> $OUT_FILE
