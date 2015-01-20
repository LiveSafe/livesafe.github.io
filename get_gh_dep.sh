#!/bin/bash

# args: folder gh-user gh-project tag [subdir]
#
# Use like:
# get_gh_dep.sh _sass Compass compass 1.0.1 core/stylesheets

echo "`date +%FT%T%z` ./get_gh_dep.sh $1 $2 $3 $4 $5" >> get_gh_dep.log

MAIN_DIR=$1
GH_USER=$2
GH_PROJ=$3
GIT_TAG=$4
SUB_DIR="$5"

DEST_DIR=$MAIN_DIR/vendor/$GH_PROJ
SVN_URL=https://github.com/$GH_USER/$GH_PROJ/tags/$GIT_TAG/$SUB_DIR

set -e

echo "Cleaning $DEST_DIR"
mkdir -p $DEST_DIR
rm -rf $DEST_DIR

echo "Checking out $SVN_URL"
svn checkout $SVN_URL $DEST_DIR
rm -rf $DEST_DIR/.svn
# rm $MAIN_DIR/$GH_PROJ || echo ""
# ln -s vendor/$GH_PROJ/$GH_PROJ $MAIN_DIR
