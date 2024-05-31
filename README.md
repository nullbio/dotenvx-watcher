# dotenvx-watcher

Env file watcher that watches and decrypts env files on the fly, using Dotenvx for decryption, and stores them in a file-system accessible path for easy loading into a Docker `env_file` directive, so that your Docker containers can be fed live env var file changes.

## Dependencies & Usage

bash, [dotenvx](https://github.com/dotenvx/dotenvx), inotify-tools, jq.

```
# Install dependencies
sudo apt update && sudo apt install inotify-tools jq curl
curl -L -fsS https://raw.githubusercontent.com/dotenvx/dotenvx.sh/main/installer.sh | sh

# Start the watcher from project root containing your .env files
./watch.sh --help
```

This env file watcher was primarily created to assist with the integration of Dotenvx into projects that are heavily Docker based.

After trying to integrate Dotenvx with Docker the "traditional" way, I decided that this was a much nicer solution. You can read more about this process in an article I wrote here: [https://dev.to/nullbio/dotenvx-with-docker-the-better-way-to-do-environment-variable-management-5c0n](https://dev.to/nullbio/dotenvx-with-docker-the-better-way-to-do-environment-variable-management-5c0n).


## Example usage

```docker
# compose.yml
services:
   postgres:
      image: postgres:latest
      env_file:
         - /mnt/ramfs/projectname/.env.dev.decrypted
      environment:
         # $POSTGRES_PASSWORD is decrypted inside .env.dev.decrypted
         POSTGRES_PASSWORD: $POSTGRES_PASSWORD
```

```plaintext
$: ./watch.sh .env.dev
Env file watcher started: .env.dev -> /mnt/ramfs/dotenvx/.env.dev.decrypted
Env file watchers running and waiting for file changes. Ctrl+C to quit...
Detected modification in .env.dev, decrypting and updating /mnt/ramfs/projectname/.env.dev.decrypted ...
^C
Deleting decrypted env files from memory: /mnt/ramfs/projectname
```

Specify custom subdirectory:

```
$: RAMFS_SUBDIR=projectname && ./watch.sh
Env file watcher started: .env.dev -> /mnt/ramfs/projectname/.env.dev.decrypted
```
