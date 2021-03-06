#!/bin/bash
set -e

BZ2_FILE=appium-ci-${TRAVIS_BRANCH}-${TRAVIS_JOB_NUMBER}-${TRAVIS_COMMIT:0:10}.tar.bz2
RUN_SAUCE=false
if [[ $TRAVIS_SECURE_ENV_VARS == true ]] && [[ $TRAVIS_PULL_REQUEST == false ]]; then 
    RUN_SAUCE=true
fi

if [[ $CI_CONFIG == 'unit' ]]; then
    cd docs
    appium_doc_lint || exit 1
    cd -
    npm test
elif [[ $CI_CONFIG == 'ios' ]]; then
    unset SUDO_UID
    echo OS X version: `sw_vers -productVersion`
    echo Xcode version: `xcodebuild build -version`
    echo Xcode path: `xcode-select --print-path`
    ./reset.sh --hardcore --no-npmlink --dev --ios
    if [[ $RUN_SAUCE == true ]]; then
        ./ci/upload_build_to_sauce.sh
        TARBALL=sauce-storage:$BZ2_FILE \
        node ./ci/tools/parallel-mocha.js \
        -p 30 \
        -c ios
    fi
elif [[ $CI_CONFIG == 'android' ]]; then
    source ./ci/android_env
    echo JAVA_HOME: $JAVA_HOME
    ./reset.sh --hardcore --no-npmlink --dev --android 
    if [[ $RUN_SAUCE == true ]]; then
        rm sample-code/apps/ApiDemos
        mv submodules/ApiDemos sample-code/apps/
        ./ci/upload_build_to_sauce.sh
        TARBALL=sauce-storage:$BZ2_FILE \
        node ./ci/tools/parallel-mocha.js \
        -p 30 \
        -c android
    fi
elif [[ $CI_CONFIG == 'others' ]]; then
    if [[ $TRAVIS_PULL_REQUEST != false ]]; then 
        echo "Skipping this config for pull requests, it takes too long."
        exit 0 
    fi
    source ./ci/android_env
    echo OS X version: `sw_vers -productVersion`
    echo Xcode version: `xcodebuild build -version`
    echo Xcode path: `xcode-select --print-path`
    echo JAVA_HOME: $JAVA_HOME
    ./reset.sh --hardcore --ios --android --no-npmlink
    ./reset.sh --dev --gappium --selendroid --no-npmlink
    if [[ $RUN_SAUCE == true ]]; then
        rm sample-code/apps/ApiDemos
        mv submodules/ApiDemos sample-code/apps/
        rm sample-code/apps/selendroid-test-app.apk
        mv submodules/selendroid/selendroid-test-app/target/selendroid-test-app-0.10.0.apk \
            sample-code/apps/selendroid-test-app.apk
        rm sample-code/apps/io.appium.gappium.sampleapp
        mv submodules/io.appium.gappium.sampleapp sample-code/apps/
        ./ci/upload_build_to_sauce.sh
        TARBALL=sauce-storage:$BZ2_FILE \
        node ./ci/tools/parallel-mocha.js \
        -p 30 \
        -c others
    fi
fi
