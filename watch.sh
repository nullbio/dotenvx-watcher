#!/usr/bin/env bash

#
# ./watch.sh [env-files...]
#

function show_help() {
	cat << EOF
Usage: $0 [options] [file...]

Options:
  -h, --help                Show this help message and exit.

Description:
  This script monitors one or more environment files for changes.
  When a change is detected, it will decrypt the monitored file using dotenvx,
  and store the decrypted file in a ramfs memory-based filesystem mount.
  If no file is specified, it defaults to watching '.env.dev'.

Examples:
  1. Watch the default environment file:
     $0

  2. Watch a specific environment file:
     $0 .env.dev

  3. Watch multiple environment files:
     $0 ~/.env.dev /path/to/.env.prod

This command allows you to specify custom environment files to monitor. If no arguments are provided,
it assumes the file '.env.dev'. Multiple files can be watched by providing each as an argument separated
by spaces.
EOF
}

_mount_ramfs() {
	local mount_point=$1

  # Create a 20mb ramfs mount if we don't already have one to use
  if ! mountpoint -q "$mount_point"; then
	  sudo mkdir -p "$mount_point"
	  sudo mount -t ramfs -o size=20M,mode=1777 ramfs "$mount_point"
  fi
}

_watcher_cleanup() {
	local mount_point=$1

  # Cleanup background inotifywatcher jobs
  while read p; do
	  kill $p 2>/dev/null || true
  done <"/tmp/env_watch_pids.txt"
  rm "/tmp/env_watch_pids.txt" 2>/dev/null || true

  echo ""
  echo "Deleting decrypted env files from memory: $mount_point"
  rm -rf "$mount_point" >/dev/null || true
  rm /tmp/env_watch.lock >/dev/null || true
}

_setup_watcher() {
	local file=$1
	local mount_point=$2

  # Initial run to get the decrypted file into the ramfs mount
  _decrypt_and_save "$file" "$mount_point" true

  # Setup watcher to decrypt on modification to env file
  inotifywait -q -m -e close_write -e delete_self -e move_self "$file" > >(while read path action; do
  if [[ "$action" == "DELETE_SELF" || "$action" == "MOVE_SELF" ]]; then
	  echo "Env file deleted or moved. Terminating watcher for $file..."
	  break
  fi
  _decrypt_and_save "$file" "$mount_point"
done) &

decrypted_file="${mount_point}/$(basename "${file}").decrypted"
echo "Env file watcher started: $file -> $decrypted_file"
echo $! >>/tmp/env_watch_pids.txt
}

_decrypt_and_save() {
	local encrypted_file=$1
	local mount_point=$2
	local decrypted_file="${mount_point}/$(basename "${encrypted_file}").decrypted"

  # Decrypt and convert JSON to .env format
  dotenvx get -f "$encrypted_file" | jq -r 'to_entries | .[] | "\(.key)=\(.value)"' >"$decrypted_file"
  if [ $? -eq 0 ]; then
	  if [ $# -eq 2 ]; then
		  echo "Detected modification in $encrypted_file, decrypting and updating $decrypted_file ..."
	  fi
  else
	  echo "Failed to decrypt $encrypted_file"
	  return 1
  fi
}

function env_watch {
	set +e # disable exit on error to ensure cleanup doesn't get skipped
	local sub_dir="${RAMFS_SUBDIR:-nanowire}"
	local mount_point="/mnt/ramfs/${sub_dir}"

  # Check for another instance running
  if [ -f /tmp/env_watch.lock ]; then
	  echo "Another instance of env:watch is already running. If this is not the case, please check running processes and remove lockfile: /tmp/env_watch.lock"
	  exit 1
  fi

  # Check if inotifywait and jq are installed
  if ! command -v inotifywait >/dev/null || ! command -v jq >/dev/null || ! command -v dotenvx >/dev/null; then
	  echo "This script requires inotify-tools, jq, and dotenvx. Please install them first."
	  exit 1
  fi

  # Error if no args supplied to ./run env:watch
  if [ $# -lt 1 ]; then
	  echo "Warning: No env file supplied. Defaulting to .env.dev, see --help for more info."
	  set -- ".env.dev"
  fi

  for env_file in $@; do
	  if [[ "$env_file" == *".env.prod"* || "$env_file" == *".env.production"* ]]; then
		  echo "Running on production env files is insecure. The env:watcher should only be used on dev."
		  exit 1
	  fi
	  if [ ! -f "$env_file" ]; then
		  echo "Error: '$env_file' does not exist."
		  exit 1
	  fi
  done

  touch /tmp/env_watch.lock

  # Make sure we don't have a stale pids file
  rm "/tmp/env_watch_pids.txt" 2>/dev/null || true

  # Set up ramfs mount and exit cleanup
  _mount_ramfs "/mnt/ramfs"
  trap "_watcher_cleanup '/mnt/ramfs/$sub_dir'" EXIT

  # Ensure subdirectory exists
  mkdir -p "$mount_point"

  # Main loop to setup watchers for each file
  pids=()
  for env_file in $@; do
	  _setup_watcher "$env_file" "$mount_point"
	  pids+=($!)
  done

  echo "Env file watchers running and waiting for file changes. Ctrl+C to quit..."

  # If all watchers terminate, exit app
  wait ${pids[@]}
}

# Main script logic
case "$1" in
	-h|--help)
		show_help
		;;
	*)
		env_watch "$@" 
		;;
esac
