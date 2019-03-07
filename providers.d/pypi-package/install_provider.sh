#!/usr/bin/env bash

main() {

  #local providers_tld="/opt/bashellite/providers.d";

  for dep in \
             mkdir \
             cat \
             curl \
             sha256sum \
             ; do
    which ${dep} &>/dev/null \
    || {
         echo "[FAIL] Can not proceed until ${dep} is installed and accessible in path; exiting." \
         && exit 1;
       };
  done

}

main
