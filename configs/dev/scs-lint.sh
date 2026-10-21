#!/bin/bash
# Lint and test a Drupal extension with the tools baked into the development
# image. An extension's own phpcs.xml, phpstan.neon, CSpell config and
# phpunit.xml win; otherwise the defaults in /usr/local/share/scs-dev apply.
#
# Usage: scs-lint [all|lint|phpcs|phpcbf|phpstan|cspell|phpunit] [path] [-- tool args]
#   all (default) runs lint, phpcs, phpstan and cspell, not phpunit.
#   path defaults to the SODa SCS Manager module.
set -uo pipefail

DRUPAL_ROOT="/opt/drupal"
DEFAULTS="/usr/local/share/scs-dev"
PHP_EXTENSIONS="php,module,inc,install,test,profile,theme,engine"

command="${1:-all}"
[ $# -gt 0 ] && shift
target="${DRUPAL_ROOT}/web/modules/contrib/soda_scs_manager"
if [ $# -gt 0 ] && [ "$1" != "--" ]; then
  target="$1"
  shift
fi
[ "${1:-}" = "--" ] && shift
target="$(realpath "${target}")" || exit 2
cd "${target}" || exit 2

# First file in the extension that exists, or nothing.
own_config() {
  local file
  for file in "$@"; do
    if [ -f "${file}" ]; then
      echo "${file}"
      return
    fi
  done
}

run_lint() {
  parallel-lint --no-progress -e "${PHP_EXTENSIONS}" \
    --exclude vendor --exclude node_modules "$@" .
}

run_phpcs() {
  local tool="$1"
  shift
  if [ -n "$(own_config phpcs.xml phpcs.xml.dist .phpcs.xml .phpcs.xml.dist)" ]; then
    "${tool}" "$@"
  else
    "${tool}" --standard=Drupal,DrupalPractice --extensions="${PHP_EXTENSIONS}" \
      --ignore='*/vendor/*,*/node_modules/*' "$@" .
  fi
}

run_phpstan() {
  local config
  config="$(own_config phpstan.neon phpstan.neon.dist)"
  if [ -n "${config}" ]; then
    phpstan analyse -c "${config}" --memory-limit=1G --no-progress "$@"
  else
    phpstan analyse -c "${DEFAULTS}/phpstan.neon" --memory-limit=1G --no-progress "$@" .
  fi
}

run_cspell() {
  local config
  config="$(own_config .cspell.json cspell.json .cspell.jsonc cspell.jsonc cspell.config.yaml cspell.config.yml)"
  cspell lint -c "${config:-${DEFAULTS}/cspell.json}" --no-progress --no-must-find-files "$@" .
}

# Kernel and functional tests need a database; without SIMPLETEST_DB they use
# the site database with a per-test table prefix. Run as `developer` so
# PHP-FPM (in the developer group) can write into sites/simpletest.
run_phpunit() {
  local config
  config="$(own_config phpunit.xml phpunit.xml.dist)"
  export SIMPLETEST_DB="${SIMPLETEST_DB:-${DB_DRIVER:-mysql}://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT:-3306}/${DB_NAME}}"
  export SIMPLETEST_BASE_URL="${SIMPLETEST_BASE_URL:-http://localhost}"
  export BROWSERTEST_OUTPUT_DIRECTORY="${BROWSERTEST_OUTPUT_DIRECTORY:-${DRUPAL_ROOT}/web/sites/simpletest/browser_output}"
  cd "${DRUPAL_ROOT}/web" || return 2
  if [ -n "${config}" ]; then
    phpunit -c "${target}/${config}" "$@"
  else
    phpunit -c core/phpunit.xml.dist "$@" "${target}"
  fi
}

step() { echo -e "\033[0;33m==> $*\033[0m"; }

case "${command}" in
  lint) run_lint "$@" ;;
  phpcs) run_phpcs phpcs "$@" ;;
  phpcbf) run_phpcs phpcbf "$@" ;;
  phpstan) run_phpstan "$@" ;;
  cspell) run_cspell "$@" ;;
  phpunit) run_phpunit "$@" ;;
  all)
    failed=()
    step "PHP lint (${target})"; run_lint || failed+=(lint)
    step "PHPCS"; run_phpcs phpcs || failed+=(phpcs)
    step "PHPStan"; run_phpstan || failed+=(phpstan)
    step "CSpell"; run_cspell || failed+=(cspell)
    if [ ${#failed[@]} -ne 0 ]; then
      echo -e "\033[0;31mFailed: ${failed[*]}\033[0m"
      exit 1
    fi
    echo -e "\033[0;32mAll checks passed.\033[0m"
    ;;
  *)
    sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'
    exit 2
    ;;
esac
