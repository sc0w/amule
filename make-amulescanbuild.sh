#!/bin/bash

set -e
set -v
set -x

export TITLESCANBUILD="${REPO_NAME} (clang-tools `dpkg -s clang-tools|grep -i version|cut -d " " -f 2`) - scan-build results"

mkdir -p html-report

if [[ -d "/rootdir" ]]; then
    git config --global --add safe.directory /rootdir
fi

if [ -f "autogen.sh" ]; then
    NOCONFIGURE=1 unbuffer ./autogen.sh  2>&1 | tee -a --output-error=exit ./html-report/output_${TRAVIS_COMMIT}
    if [ ${PIPESTATUS[0]} -ne 0 ];then
        exit 1
    fi
fi

if [ "${1}" = "meson" ]; then
    unbuffer scan-build $CHECKERS --keep-cc meson $2 _build 2>&1 | tee -a --output-error=exit ./html-report/output_${TRAVIS_COMMIT}
    if [ ${PIPESTATUS[0]} -ne 0 ];then
        exit 1
    fi
    unbuffer scan-build $CHECKERS --keep-cc -o html-report --html-title="$TITLESCANBUILD" ninja -C _build 2>&1 | tee -a --output-error=exit ./html-report/output_${TRAVIS_COMMIT}
    if [ ${PIPESTATUS[0]} -ne 0 ];then
        exit 1
    fi

    if cat /rootdir/html-report/*/failures/*stderr.txt; then
        exit 1
    fi

else
    unbuffer scan-build $CHECKERS ./configure --prefix=/usr $1  2>&1 | tee -a --output-error=exit ./html-report/output_${TRAVIS_COMMIT}
    if [ ${PIPESTATUS[0]} -ne 0 ];then
        exit 1
    fi

    if [ $CPU_COUNT -gt 1 ]; then
        unbuffer scan-build $CHECKERS --html-title="$TITLESCANBUILD" --keep-cc -o html-report make -j $(( $CPU_COUNT + 1 )) 2>&1 | tee -a --output-error=exit ./html-report/output_${TRAVIS_COMMIT}
        if [ ${PIPESTATUS[0]} -ne 0 ];then
            exit 1
        fi
    else
        unbuffer scan-build $CHECKERS --html-title="$TITLESCANBUILD" --keep-cc -o html-report make 2>&1 | tee -a --output-error=exit ./html-report/output_${TRAVIS_COMMIT}
        if [ ${PIPESTATUS[0]} -ne 0 ];then
            exit 1
        fi
    fi

    if cat /rootdir/html-report/*/failures/*stderr.txt; then
        exit 1
    fi

    make prefix=/usr install

    if [ "${REPO_NAME}" == "baul" ]; then
      xvfb-run make check 2>&1 | tee -a --output-error=exit ./html-report/output_${TRAVIS_COMMIT}
      if [ ${PIPESTATUS[0]} -ne 0 ];then
          find . -name '*test-suite.log'
          echo > cat
          cat cat `find . -name '*test-suite.log'`
          exit 1
      fi
    elif [ "${REPO_NAME}" != "lector" ]; then
      unbuffer make check 2>&1 | tee -a --output-error=exit ./html-report/output_${TRAVIS_COMMIT}
      if [ ${PIPESTATUS[0]} -ne 0 ];then
          find . -name '*test-suite.log'
          echo > cat
          cat cat `find . -name '*test-suite.log'`
          exit 1
      fi
    fi

#    if [ "${REPO_NAME}" != "ctk" ]; then
#      make distcheck
#    fi
fi
