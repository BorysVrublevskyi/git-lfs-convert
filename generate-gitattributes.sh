#!/bin/bash

# READY?
WORKDIR=/opt/cloned
ROOT_URI=ssh.dev.azure.com:v3/mycorp/Dev
REPOLIST="repo1 repo2"
# REPOLIST=$(ssh root@git 'ls -d /opt/git/*.git | sed "s,/opt/git/,,g"')
# ssh-copy-id -i /root/.ssh/id_rsa.pub root@git

set -exo pipefail
    command -v dos2unix || yum install -y dos2unix

# GO!
mkdir -p $WORKDIR || ture
FILELIST=$WORKDIR/all-files-path-and-mime-list.txt
BINMIMELIST=$WORKDIR/binary-ext-and-mime-list.txt
TEXTMIMELIST=$WORKDIR/text-ext-and-mime-list.txt
BINEXT=$WORKDIR/binary-ext-only-list.txt
TEXTEXT=$WORKDIR/text-ext-only-list.txt
BINANDTEXT=$WORKDIR/common-binary-and-text-ext-list.txt
BINWOTEXT=$WORKDIR/binary-wo-text-ext-list.txt
TEXTWOBIN=$WORKDIR/text-wo-binary-ext-list.txt
GITATTRIBUTES=$WORKDIR/.gitattributes

# BINPATHMIMELIST=$WORKDIR/all-binary-files-path-and-mime-list.txt
# BINPATH=$WORKDIR/all-binary-files-path-list.txt

# STEP 1: Create list with all files and their MIME descriptions
rm -f $WORKDIR/main-list.txt.tgz
for REPO in $REPOLIST; do
    git clone $ROOT_URI/$REPO $WORKDIR/$REPO || \
        (git -C $WORKDIR/$REPO pull || echo -e "\n### $REPO - SKIPED ###\n" >> $FILELIST)
    echo -e "\n### $REPO ###\n" >> $FILELIST # Add separator with repo's name
    find $WORKDIR/$REPO -type f -print0 | xargs -0 file -iN >> $FILELIST # Create list witch conatins file's path and MIME description
done
tar -czvf $WORKDIR/main-list.txt.tgz $FILELIST


# STEP 2: Analyse main list

grep -oE "\.{1}\w*:.*charset=binary$" $FILELIST | grep -v "x-empty" | sort -u > $BINMIMELIST
cut -d: -f1 $BINMIMELIST | sort -u > $BINEXT

# grep -oE ".*charset=binary$" $FILELIST | grep -v "x-empty" | sort -u > $BINPATHMIMELIST
# cut -d: -f1 $BINPATHMIMELIST | sort -u > $BINPATH

grep -oE "\.{1}\w*:.*text.*" $FILELIST | sort -u > $TEXTMIMELIST
cut -d: -f1 $TEXTMIMELIST | sort -u > $TEXTEXT

echo>"$BINANDTEXT"
for EXT in $(cat "$BINEXT"); do
    grep "$EXT" "$TEXTEXT" && echo "$EXT" >> "$BINANDTEXT"
done

cp -f $BINEXT $BINWOTEXT
for EXT in $(cat "$BINEXT"); do
    grep "$EXT" "$TEXTEXT" && sed -i "/.*${EXT}.*/d" "$BINWOTEXT"
done

cp -f $TEXTEXT $TEXTWOBIN
for EXT in $(cat "$TEXTEXT"); do
    grep "$EXT" "$BINEXT" && sed -i "/.*${EXT}.*/d" "$TEXTWOBIN"
done

# STEP 3: Generate .gitattributes

wget -cO $WORKDIR/gitattributes.txt https://gitattributes.io/api/csharp%2Cjava%2Cpython%2Cvisualstudio%2Cweb%2Cobjectivec%2Cswift
cp -f $WORKDIR/gitattributes.txt $GITATTRIBUTES

#sed -i 's/^M$//' $GITATTRIBUTES # Convert line endings: crlf to lf
dos2unix $GITATTRIBUTES

sed -i 's/binary$/filter=lfs diff=lfs merge=lfs -text/g' $GITATTRIBUTES

echo -e "\n### Binary files ###\n" >> $GITATTRIBUTES
for EXT in $(cat "$BINWOTEXT"); do
    grep "$EXT" "$GITATTRIBUTES" || echo "*$EXT        filter=lfs diff=lfs merge=lfs -text" >> "$GITATTRIBUTES"
done

echo -e "\n### Common extensions for binary and text files ###\n" >> $GITATTRIBUTES
for EXT in $(cat "$BINANDTEXT"); do
    grep "$EXT" "$GITATTRIBUTES" || echo "*$EXT        filter=lfs diff=lfs merge=lfs -text" >> "$GITATTRIBUTES"
done
