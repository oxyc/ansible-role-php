#!/bin/bash

run() {
  local distribution=$1
  local version=$2
  local init=$3
  local run_opts=$4
  local SITE=$5

  container_id="/tmp/${distribution}-${version}-${SITE}"
  echo "$distribution $version"
  echo "Site: $SITE"
  echo "#######################"

  # Build
  if [[ ! -e $container_id ]]; then
    sudo docker pull ${distribution}:${version}
    sudo docker build --rm=true --file=tests/Dockerfile.${distribution}-${version} --tag=${distribution}-${version}:ansible tests

    sudo docker run --detach --volume="${PWD}":/etc/ansible/roles/role_under_test:ro ${run_opts} ${distribution}-${version}:ansible "${init}" >| "${container_id}"
  fi

  # Install
  sudo docker exec "$(cat ${container_id})" ansible-galaxy install -r /etc/ansible/roles/role_under_test/tests/requirements.yml
  sudo docker exec --tty "$(cat ${container_id})" env TERM=xterm ansible-playbook /etc/ansible/roles/role_under_test/tests/test-${SITE}.yml

  # Setup test
  sudo docker exec "$(cat ${container_id})" mkdir -p /var/www/test
  sudo docker exec "$(cat ${container_id})" bash -c 'echo "<?php phpinfo(); ?>" >| /var/www/test/index.php'

  # Test
  sudo docker exec --tty "$(cat ${container_id})" env TERM=xterm php -i | grep 'memory_limit.*191'
  sudo docker exec --tty "$(cat ${container_id})" env TERM=xterm curl -s --header Host:test.dev localhost | grep 'memory_limit.*191M'

  echo "Container ID: $(cat ${container_id})"
}

for suite in mod_php fpm nginx nginx-fpm no-webserver; do
  echo "$suite #########################################################################################"

  distribution=centos
  version=6
  init=/sbin/init
  run_opts=
  
  run "$distribution" "$version" "$init" "$run_opts" "$suite"
  
  distribution=centos
  version=7
  init=/usr/lib/systemd/systemd
  run_opts="--privileged --volume=/sys/fs/cgroup:/sys/fs/cgroup:ro"
  
  run "$distribution" "$version" "$init" "$run_opts" "$suite"
  
  distribution=ubuntu
  version=12.04
  init=/sbin/init
  run_opts=
  
  run "$distribution" "$version" "$init" "$run_opts" "$suite"
  
  distribution=ubuntu
  version=14.04
  init=/sbin/init
  run_opts=
  
  run "$distribution" "$version" "$init" "$run_opts" "$suite"
done
