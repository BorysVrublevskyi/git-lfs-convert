#!/bin/bash
set -ex

# ja-chatscript
# .hprof - add to .gitignore !!

REPONAME=myrepo
WORKDIR=/opt/cloned
EXCLUDEDIR=${REPONAME//.git/_somedir}
ORIGREPOSDIR=/opt/git-original # /opt/git - for main Git serer; /opt/git-original - for test server

mkdir -p /opt/{git-lfs,git-original} || true

BIGEXT=$(grep "merge=lfs" $WORKDIR/.gitattributes | grep -Eo "^(\*\.\w+)(\.\w+)?" | tr '\r\n' ',')
# BIGEXT="*.class,*.dll,*.ear,*.jar,*.so,*.war,*.db,*.p,*.pkl,*.pickle,*.pyc,*.pyd,*.pyo,*.ai,*.bmp,*.eps,*.gif,*.gifv,*.ico,*.jng,\
# *.jp2,*.jpg,*.jpeg,*.jpx,*.jxr,*.pdf,*.png,*.psb,*.psd,*.svgz,*.tif,*.tiff,*.wbmp,*.webp,*.kar,*.m4a,*.mid,*.midi,*.mp3,*.ogg,*.ra,\
# *.3gpp,*.3gp,*.as,*.asf,*.asx,*.fla,*.flv,*.m4v,*.mng,*.mov,*.mp4,*.mpeg,*.mpg,*.ogv,*.swc,*.swf,*.webm,*.7z,*.gz,*.jar,*.rar,*.tar,\
# *.zip,*.ttf,*.eot,*.otf,*.woff,*.woff2,*.exe,*.pyc,*.Dll,*.DLL,*.DS_Store,*.dylib,*.EXE,*.fdf,*.GIF,*.gpg,*.h5,*.hdf5,*.ICO,*.idx,\
# *.ilk,*.index,*.iobj,*.jfif,*.jnilib,*.JPG,*.keystore,*.lnk,*.msi,*.node,*.nupkg,*.ods,*.p7s,*.pbix,*.pdn,*.pfx,*.pgp,*.PNG,*.potx,\
# *.ppt,*.pptx,*.snk,*.suo,*.swp,*.tlb,*.tree,*.TTF,*.unknownextension,*.version,*.vsd,*.whl,*.wmv,*.xls,*.xlsm,*.xlsx,*.AddIn,*.cache,\
# *.cd,*.cdf,*.chm,*.cpp,*.crc,*.crt,*.cur,*.dic,*.doc,*.document,*.emf,*.exp,*.flf,*.gemspec,*.glue,*.graffle,*.info,*.LIC,*.old,*.out,\
# *.pack,*.plist,*.pri,*.proto,*.rtf,*.scc,*.snap,*.strings,*.tsv,*.vsix,*.vsp"

# Install dependencies
command -v java || dnf install -y java
command -v git-lfs || dnf install -y git-lfs
if [[ ! -f /opt/git-lfs/bfg.jar ]]; then
	wget -cO /opt/git-lfs/bfg.jar https://repo1.maven.org/maven2/com/madgag/bfg/1.13.0/bfg-1.13.0.jar
fi

### GET ORIGINAL BARE REPOS AS BACKUP ###
echo "Use root pass"
if [ ! -d /opt/git/$REPONAME ]; then
	rsync -arv --progress --exclude "$EXCLUDEDIR*" root@git:/opt/git/$REPONAME $ORIGREPOSDIR
fi

### Copy repo for convertation ###
# git clone --mirror ssh://root@git:/git/$REPONAME /opt/git-lfs/$REPONAME
# rsync -arv --delete $ORIGREPOSDIR/$REPONAME /opt/git-lfs/$REPONAME
git clone --mirror file:///$ORIGREPOSDIR/$REPONAME /opt/git-lfs/$REPONAME || \
	git -C /opt/git-lfs/$REPONAME remote update

### Convert the Git history with BFG ###
java -jar /opt/git-lfs/bfg.jar --convert-to-git-lfs "$BIGEXT" --no-blob-protection /opt/git-lfs/$REPONAME

# Clean up the repository !!!
cd /opt/git-lfs/$REPONAME
git reflog expire --expire=now --all && git gc --prune=now --aggressive || \
	echo "Failed to clean up repository! Check out missed binsry file extensions"

# Install Git LFS in the mirror repository
git lfs install

# Unprotect the default branch, so that we can force-push the rewritten repository
mv $ORIGREPOSDIR/$REPONAME/{hooks,hooks.bak}
sed -i "s/denyNonFastforwards.*/denyNonFastforwards = false/g" $ORIGREPOSDIR/$REPONAME/config


#Ask for confirm

#grep remote to be sure you'll push to the right server
# REPOURL=$(grep url /opt/git-lfs/$REPONAME/config) || REPOURL=$(grep url /opt/git-lfs/$REPONAME/.git/config)
#	clear
#	while true; do
#		read -rp "You are going to git push --force $REPONAME to $REPOURL. [Y]es, [N]o ?" RLY
#		case "$RLY" in
#			[Yy]|[Yy]es)
#				# FORCE PUSH TO GIT !!1
#				ifdown eth0
#				cd /opt/git-lfs/$REPONAME
#				git push --force
#				ifup eth0
#				break
#			;;
#			[Nn]|[Nn]o)
#				echo "See ya next time"
#				exit 1
#			;;
#			*)
#				echo -e "Yes or No?"
#			;;
#		esac
#	done

ifdown eth0
cd /opt/git-lfs/$REPONAME
git push --force
ifup eth0

# Re-protect the default branch
mv $ORIGREPOSDIR/$REPONAME/{hooks.bak,hooks} || true
sed -i "s/denyNonFastforwards.*/denyNonFastforwards = true/g" $ORIGREPOSDIR/$REPONAME/config

### TEST GIT-LFS
git clone file:///opt/git-lfs/$REPONAME /opt/git-lfs/lfs-cloned-$REPONAME
#git lfs ls-files

# Track the files you want with LFS
cd /opt/git-lfs/lfs-cloned-$REPONAME
git reset --hard origin/master
git lfs track "$BIGEXT"

cat /opt/git-lfs/lfs-cloned-$REPONAME/.gitattributes

echo "Clone this repo to your PC with:
git clone ssh://root@$(hostname -I):/opt/git-lfs/$REPONAME
"

# Sources
# https://docs.gitlab.com/ee/topics/git/lfs/migrate_to_git_lfs.html
# https://confluence.atlassian.com/bitbucket/use-bfg-to-migrate-a-repo-to-git-lfs-834233484.html
# https://github.com/git-lfs/git-lfs/wiki/Tutorial
# https://rtyley.github.io/bfg-repo-cleaner/
# https://git-scm.com/docs/gitignore#_pattern_format
# https://rehansaeed.com/gitattributes-best-practices/
# https://gitattributes.io/
# https://www.toptal.com/developers/gitignore