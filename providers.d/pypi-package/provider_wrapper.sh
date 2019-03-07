bashelliteProviderWrapperBandersnatch() {

  # Perform some pre-sync checks
  read _ pypi_status_code _ < <(curl -sI "${_n_repo_url}");

  if [[ "${pypi_status_code:0:1}" < "4" ]]; then
    utilMsg INFO "$(utilTime)" "The pypi mirror appears to be up; sync should work...";
  else
    utilMsg FAIL "$(utilTime)" "The pypi mirror appears to be down/invalid/inaccessible; exiting...";
    return 1;
  fi

  local directory_parameter="$(grep -oP "(?<=(^directory = )).*" ${_r_metadata_tld}/repos.conf.d/${_n_repo_name}/provider.conf)"
  if [[  "${directory_parameter}" != "${_r_mirror_tld}/${_n_repo_name}" ]]; then
    utilMsg WARN "$(utilTime)" "The \"directory\" parameter (${directory_parameter}) in provider.conf does not match mirror location (${_r_mirror_tld}/${_n_repo_name})..."
  fi

  if [ ! -d ${HOME}/.bashellite ]; then
    utilMsg WARN "$(utilTime)" "The temporary directory (${HOME}/.bashellite) doesn't exist.  Creating..."
    mkdir -p ${HOME}/.bashellite
  fi

  local config_file="${_r_metadata_tld}/repos.conf.d/${_n_repo_name}/provider.conf"
  local tmp_config_file="${HOME}/.bashellite/tmp_${_n_repo_name}_provider.conf"

  > ${tmp_config_file}

  local line_counter=0
  while IFS=$'\n' read line; do
    if [[ ${line} =~ ^directory[[:blank:]]*[=][[:blank:]]*[[:alnum:]/_.-]+ ]]; then
      if [ "${line_counter}" = 0 ]; then
        echo "directory = ${_r_mirror_tld}/${_n_repo_name}" >> ${tmp_config_file}
      else
        utilMsg WARN "$(utilTime)" "Duplicate directory parameter found.  Skipping line..."
      fi
      line_counter=$(($line_counter + 1))
    else
      echo "${line}" >> ${tmp_config_file}
    fi
  done < ${config_file}

  utilMsg INFO "$(utilTime)" "Proceeding with sync of repo (${_n_repo_name}) using ${_n_repo_provider}..."
  # If dryrun is true, perform dryrun
  if [[ ${_r_dryrun} ]]; then
    utilMsg INFO "$(utilTime)" "Sync of repo (${_n_repo_name}) using ${_n_repo_provider} completed without error..."
  # If dryrun is not true, perform real run
  else
    ${_r_providers_tld}/bandersnatch/exec/bin/bandersnatch -c "${tmp_config_file}" mirror;
    if [[ "${?}" == "0" ]]; then
      utilMsg INFO "$(utilTime)" "Sync of repo (${_n_repo_name}) using ${_n_repo_provider} completed without error...";
    else
      utilMsg WARN "$(utilTime)" "Sync of repo (${_n_repo_name}) using ${_n_repo_provider} did NOT complete without error...";
    fi
  fi


####################################################################

  local pypi_url="${_n_repo_url}"
  local base_dir="${_r_mirror_tld}/${_n_repo_name}/web"
  mkdir -p "${base_dir}" &>/dev/null \
      || Fail "Unable to create directory (${base_dir}); check permissions."

  local simple_dir="${base_dir}/simple"

  mkdir -p "${simple_dir}" &>/dev/null \
      || Fail "Unable to create directory (${simple_dir}); check permissions."

  local packages_dir="${base_dir}/packages"

  mkdir -p "${packages_dir}" &>/dev/null \
      || Fail "Unable to create directory (${packages_dir}); check permissions."

  while read package_line; do 
    # Step 1. Get package listing from $pypi_url/simple/$mirror_package_name/ 
    # Step 2. For each package listing, modify it to point to ../../packages/<packages directory>
    # and save it to $base_dir/simple/$mirror_package_name/index.html
    # Step 3. Save non package listing lines to previous index.html
    # Step 4. For each package listing, download package and save
    # it to $base_dir/packages/<packages directory>

    mirror_package_name=${package_line}

    local package_name_dir="${simple_dir}/${mirror_package_name}"

    mkdir -p "${package_name_dir}" &>/dev/null \
        || Fail "Unable to create directory (${package_name_dir}); check permissions."

    cat /dev/null > ${package_name_dir}/index.html

    curl -s ${pypi_url}/simple/${mirror_package_name}/ \
    | while read line; do
      # Save the line to the index.html file substituting 'https://files.pythonhosted.org' with '../..' 
      # This is to make the file downloads relative to the package being mirrored
      # Example line:     <a href="https://files.pythonhosted.org/packages/b5/9e/ab36e384db3602fdd3729fbb3a467949c40758361f244a379b7553683663/mypy-0.1.tar.gz#sha256=0055650b0b17702e5b7d82a5b09330f9a7d500c829e9967e169bd773d538eb6b">mypy-0.1.tar.gz</a><br/>
      local newline=${line/https\:\/\/files\.pythonhosted\.org/..\/..}
      echo "${newline}" >> ${package_name_dir}/index.html

      # Only process lines that contain an href html tag
      if [[ ${line} =~ .*href.* ]]; then
        # Need to get the URL of the package to download
        #local package_url=`echo ${line} | grep -oP "(?<=href\=\").*(?=\"\>)"`
        #package_url=${package_url%% *}
        local package_url=${line#*\<a\ href\=\"}
        package_url=${package_url%%\"*}
      
        # Need to get the SHA256 value to compare to the file, to see if file already exists
        #local package_sha256=`echo ${line} | grep -oP "(?<=sha256\=)[[:alnum:]]*(?=\")"`
        local package_sha256=${line##*sha256\=}
        package_sha256=${package_sha256%%\"*}
        
        # Need to get the package file name
        #local package_file_name=`echo ${line} | grep -oP "(?<=\"\>).*(?=\</a\>\<br/\>)"`
        local package_file_name=${line#\<a\ href*\>}
        package_file_name=${package_file_name%%\<*}

        # Need to get the package directory
        #local package_url_dir_path=`echo ${package_url} | grep -oP "(?<=packages/).*(?=#sha256\=)"`
        #package_url_dir_path=${package_url_dir_path%/*}
        local package_url_dir_path=${package_url#*packages/}
        package_url_dir_path=${package_url_dir_path%%\#sha256*}
        package_url_dir_path=${package_url_dir_path%/*}

        mkdir -p "${packages_dir}/${package_url_dir_path}" &>/dev/null \
          || Fail "Unable to create directory (${packages_dir}/${package_url_dir_path}); check permissions."

        # Now check to see if file from package listing already exists
        if [[ ${package_file_name} != "" ]]; then
          local file_save="true"
          if [ -s "${packages_dir}/$package_url_dir_path/${package_file_name}" ]; then
            local file_sha256=`sha256sum "${packages_dir}/$package_url_dir_path/${package_file_name}"`
            local file_sha256_array=( ${file_sha256} )

            if [[ ${#file_sha256_array} > 0 ]]; then
              if [[ ${file_sha256_array[0]} == ${package_sha256} ]]; then
                file_save="false"
              fi
            fi
          fi

          # Save file if file_save == "true"
          if [[ ${file_save}  == "true" ]]; then
            echo "Saving File: ${package_file_name}..."
            curl -s -S -o "${packages_dir}/$package_url_dir_path/${package_file_name}" ${package_url}
          else
            echo "File: ${package_file_name} already exists, skipping..."
          fi
        fi
      fi

    done
  done < ${config_file}



}
