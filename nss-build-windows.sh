#!/bin/bash
#
#   Mozilla NSS with NSPR build script on Windows
#   Developed by Mitsuhiko Hara
#
ME=`basename $0`

usage()
{
    echo "usage: $ME [-v|-l|-c] <NSS source directory> "
    echo
    echo "This script build Mozilla NSS with NSPR on Windows"
    echo "    NSS source directory: top directory of NSS with NSPR source (e. nss-3.87)"  
    echo "    -v: vervose option (for debug)"
    echo "    -l: legacy build using make"
    echo "    -c: clean build"
    echo 
    echo "Note build requires build environment such as"
    echo " - make "
    echo " - gyp"
    echo " - ninja"
    echo " - Visual Studio"
    
    exit 1
}

check_config()
{
    CONFIGERR="Configuration Error: "

    MAKEPATH=`which make`
    if [ "$MAKEPATH" = "" ]
    then
        echo "$CONFIGERR make not found in PATH"
        exit 1
    fi
    GYPPATH=`which gyp`
    if [ "GYPPATH" = "" ]
    then
        echo "$CONFIGERR gyp not found in PATH"
        exit 1
    fi
    NINJAPATH=`which ninja`
    if [ "NINJAPATH" = "" ]
    then
        echo "$CONFIGERR ninja not found in PATH"
        exit 1
    fi

    if [ ! -d $ROOTDIR ]
    then
        echo "$CONFIGERR $ROOTDIR directory not found"
        exit 1
    fi

    if [ ! -d $ROOTDIR/nss ] || [ ! -d $ROOTDIR/nspr ]
    then
        echo "$CONFIGERR $ROOTDIR directory do not contain nss and/or nspr directory"
        exit 1
    fi

}

patch_files()
{

    PATCHFILES="$ROOTDIR/nss/build.sh $ROOTDIR/nss/coreconf/msvc.sh"
    for file in $PATCHFILES
    do
        #echo $file
        if [ -f $file ]
        then
            patchfile=`basename $file`.patch
            if [ -f $patchfile ]
            then
                if [ ! -f $file.org ]
                then
                    cp $file $file.org
                    patch $file < $patchfile
                    echo "$file patched"
                fi
            fi
        fi    
    done

    if [ $GYP_PATCH -eq 1 ]
    then
        GYPDIR=`dirname $GYPPATH`
        GYPPATCHCOUNT=$(grep -c encoding $GYPDIR/pylib/gyp/win_tool.py 2>&1) 
        if [ "$GYPPATCHCOUNT" = "0" ]
        then
            if [ ! -f $GYPDIR/pylib/gyp/win_tool.py.org ]
            then
                cp $GYPDIR/pylib/gyp/win_tool.py $GYPDIR/pylib/gyp/win_tool.py.org
                patch $GYPDIR/pylib/gyp/win_tool.py < win_tool.py.patch
                echo "$GYPDIR/pylib/gyp/win_tool.py patched"
            fi
        fi
    fi

    # add BOM to UTF08 fille
    # The following files needs to change UTF-8 with BOM
    if [ $BOM_PATCH -eq 1 ]
    then
    UNIFILES="\
        $ROOTDIR/nss/gtests/pkcs11testmodule/pkcs11testmodule.cpp \
        $ROOTDIR/nss/gtests/pk11_gtest/pk11_module_unittest.cc \
    "

    for file in $UNIFILES
    do
        if [ ! -f $file.org ]
        then
            mv $file $file.org
            echo -ne '\xEF\xBB\xBF' > $file
            cat $file.org >> $file
            echo "$file updated with BOM"
        fi
    done
fi

# Suppress encoding waring C4566

if [ $SUPPRESS_WARNING -eq 1 ]
then
    grep CFLAGS $ROOTDIR/nss/coreconf/WIN32.mk  | grep "\-WX" 
    if [ $? -eq  0 ]
    then
         cp $ROOTDIR/nss/coreconf/WIN32.mk  $ROOTDIR/nss/coreconf/WIN32.mk.org
         sed -i '/-WX/s/-WX//' $ROOTDIR/nss/coreconf/WIN32.mk 
    fi
fi

}

legacy_build()
{
    target_arch=$(${python:-python} nss/coreconf/detect_host_arch.py)
    source nss/coreconf/msvc.sh
    make -C nss nss_build_all USE_64=1 
}

build()
{
    echo "#### NSPR BUILD #####" 
    nss/build.sh $VERBOSE --nspr --nspr-only  

    # nsinstall installs wrong directory . So need to link to right directory and retry
    PATHARRAY=( ${ROOTDIR//\//" " })
    FALSEROOTDIR="/${PATHARRAY[0]}$ROOTDIR"
    FALSEDIR="/${PATHARRAY[0]}//${PATHARRAY[0]}"

    if [ ! -d $ROOTDIR/dist/Debug ] && [ -d $FALSEROOTDIR/dist/Debug ]
    then
        echo "Files are installed to $FALSEROOTDIR/dist and not $ROOTDIR/dist. Link them for rebuild" 
        ln  -sf $FALSEROOTDIR/dist/Debug $ROOTDIR/dist/
    
        echo "#### NSPR BUILD - Second Try #####" 
        make -C nspr/Debug install 
     
        if [ -f nss/out/gyp_config.new ]
        then
            mv -f nss/out/gyp_config.new nss/out/gyp_config
        fi
        # some files only in FALSEROOTDIR, so copy them to right directory
        MISSINGFILES=$(diff -r $ROOTDIR/dist/Debug $FALSEROOTDIR/dist/Debug | grep "Only in $FALSEROOTDIR" | sed -e 's/Only in //' -e 's/: /\//') 
        if [ "$MISSINGFILES" != "" ]
        then
            echo "Some files are only installed to $FALSEROOTDIR. Copy them to $ROOTDIR"
            for file in $MISSINGFILES
            do
                DESTFILE=$(echo $file | sed -e 's/\/'${PATHARRAY[0]}'//')
                echo "Copy $file to $DESTFILE"
                cp -f $file $DESTFILE
            done
        fi
    fi

    echo "#### NSS BUILD  #####" 
    nss/build.sh $VERBOSE -j 3 -g --with-nspr=${ROOTDIR}/nspr/Debug/dist/include/nspr:${ROOTDIR}/nspr/Debug/dist/lib 

    if [ $? -eq 0 ]
    then
        echo "Build Sucess"
    else
        echo "Build Fail. Check $LOGFILE"
    fi

    # clean up wrong directory
    FALSEDIR="/${PATHARRAY[0]}//${PATHARRAY[0]}"
    if [ -d $FALSEDIR ]
    then
        rm -rf $FALSEDIR
    fi
}

clean()
{
    nss/build.sh -cc
}

#
# Main
#
ROOTDIR=

LEGACY_BUILD=0
CLEAN=0
VERBOSE=

GYP_PATCH=1
BOM_PATCH=1
SUPPRESS_WARNING=1

if [ $# -eq 0 ]
then
    usage
fi

while getopts :hvlc OPT
do
  case $OPT in
     v) VERBOSE=-v;;
     l) LEGACY_BUILD=1;;
     c) CLEAN=1;;
     h) usage;;
  esac
done
shift $((OPTIND-1))

ROOTDIR=$1

# Check Build Configuration
check_config

LOGFILE=build.log
if [ -f $LOGFILE ]
then
    rm -f $LOGFILE
fi

echo "CLEAN=$CLEAN"
echo "LEGACY_BUILD=$LEGACY_BUILD"
echo "VERBOSE=$VERBOSE"
echo "ROOTDIR=$ROOTDIR"
echo "LOGFILE=$LOGFILE"

# Patch Files 
(patch_files) > $LOGFILE 2>&1

pushd . >/dev/null 

cd $ROOTDIR

if [ $CLEAN -eq 1 ]
then
    clean
    exit 0
fi

if [ $LEGACY_BUILD -eq 1 ]
then

    (legacy_build) >> $LOGFILE 2>&1

else 

    (build) >> $LOGFILE 2>&1

fi

popd



