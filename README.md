# dotenvx-watcher

Env file watcher that watches and decrypts env files on the fly, and stores them in a file-system accessible path.

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

