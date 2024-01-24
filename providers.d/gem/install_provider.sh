#!/usr/bin/env bash

main() {

  local bin_name="ruby";
  local ruby_ver="2.5.1";
  local ruby_ver="$(ruby -v | awk '{print $2}')"

  for dep in \
             git \
             ruby \
             gem \
             make \
             ; do
    which ${dep} &>/dev/null \
    || {
         echo "[FAIL] Can not proceed until ${dep} is installed and accessible in path." \
         && exit 1;
       };
  done;

  # Check to see if ruby is already installed in /home/bashellite/.rubies, if not install it.
  local ruby_bin="/home/bashellite/.rubies/ruby-${ruby_ver}/bin/ruby"

  # campfield - not sure why there is a direct reference to Ruby versions.
  #  However, I'm smarter than everybody else so I'm just going to do a which on the binary.
  local ruby_bin=$(which ruby)
  if [[ -z $ruby_bin ]]; then
    echo "Binary for Ruby [ruby] not found."
    exit 1
  fi

  if [[ -s "${ruby_bin}" && $(${ruby_bin} --version | grep -o "ruby ${ruby_ver}") == "ruby ${ruby_ver}" ]]; then
    echo "[INFO] ${bin_name} provider successfully installed.";
  else
    echo "[WARN] ${bin_name} does NOT appear to be installed, (or it is broken); (re)installing..."
    # Download ruby-install
    if [ ! -d ${providers_tld}/gem/src/ruby-install ]; then
      git clone https://github.com/pcseanmckay/ruby-install ${providers_tld}/gem/src/ruby-install
    fi

    # Install ruby to /home/bashellite/.rubies
    local ruby_installer="${providers_tld}/gem/src/ruby-install/bin/ruby-install"
    local ruby_src_dir="${providers_tld}/gem/src/ruby_src"
    local ruby_install_dir="/home/bashellite/.rubies"
    local ruby_dir="${ruby_install_dir}/ruby-${ruby_ver}"

    ${ruby_installer} -i ${ruby_dir} -s ${ruby_src_dir} ruby ${ruby_ver}
    chown -R bashellite:bashellite ${ruby_install_dir}
    chmod -R 0700 ${ruby_install_dir}

    # Check installation of ruby
    if [[ -s "${ruby_bin}" && $(${ruby_bin} --version | grep -o "ruby ${ruby_ver}") == "ruby ${ruby_ver}" ]]; then
      echo "[INFO] ${bin_name} provider successfully installed.";
    else
      echo "[FAIL] ${bin_name} was NOT installed successfully; exiting." \
      && exit 1;
    fi
  fi

}

main