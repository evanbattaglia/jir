# Finally, JIRA in the terminal 🤓🥳

`jir` is a JIRA CLI. It aims to allow you to do most of your daily JIRA tasks
from the command line. It is highly configurable for different JIRA
installations.

# Features and examples 🪄

* Powerful customizable searching:
  * Composable, named searches, with names mapping to JQL queries (and optionally taking string arguments)
  * Customized outputs using a `jq` query to get just the data you want, how
    you need it
  * Examples (see [example configs](./configs) for definitions of names searches):
    * `jir s bug,open count` to count open bugs.
    * `jir s myteam1,grep summary 'needle'` to show ticket summaries where `needle` is in the summary or description
    * `jir s sprint summary` to show data typically shown in a sprint board (tickets, status, assignee, etc.)
    * `jir s created1h summary` to find that ticket you just created within the past hour.
    * `jir s myepic,open summary` to show open tickets part of an epic that you are working on, where `myepic` is a search defined as `'parent'='MYPROJECT-1234'`
* Quickly set fields on ticket:
  * `jir field set 1234 storypoints 3`
  * `jir field set 1234 summary "old name was: $(jir get 1234 summary-text)"`
* Assign tickets, move tickets to sprints, change ticket status. Combine with shell scripts to do bulk operations.
  * `jir assign 1234 me`
  * `jir agile move-issue current 1234 1235` -- move 1234 and 1235 into the "current" sprint (see `current:` sprint definition in `030_EXAMPLE_team_with_2_subteams.yml`)
  * `jir transition 1234 Done`
* View description & comments as markdown
  * `jir get 1234 glow`
* Aliases for tickets, users, and field values. Extract ticket names from git commit messages.
    * `jir get my-epic-alias glow`
    * `jir get git: glow`
* Manage attachments
  * `jir download-all OTHERPROJ-1234`
  * `jir attach git:HEAD demo.mp4`
* Show changelog on a ticket
  * `jir changelog 1234`
* Create and comment on tickets
  * `jir comment 1234`
  * `jir create Bug "Feature ABC is broken" points=3`
* Link tickets
  * `jir links link 123 "Depends on" 456`
* Manage watchers
  * `jir watchers get 1234`
  * `jir watchers remove 1234 me`
* hit arbitrary JIRA APIs with auth, using `httpie` syntax
  * `jir http get /issues/INTEROP-1234`
* Tab completion using [tabry](https://github.com/evanbattaglia/tabry)

# Prerequisites 🧐

* `jq`
* `httpie`
* `pass` or `gopass` (highly recommended)

*OR*

* `nix`

# Installation 🚀

1. Ensure you have the preqrequisites listed above.
2. If using nix, run `nix run .#jir` to show the help. If not using jir, run `bundle install` and then `bin/jir` You can always get help on subcommands by running them with no arguments or by adding the `--help` flag.
3. make a basic config:
```bash
mkdir ~/.config/jir/
echo 'auth_backend: env' >> ~/.config/jir/test.yml
echo 'base_url: https://mycompany.atlassian.net' >> ~/.config/jir/test.yml
```
5. Create an API token at https://id.atlassian.com/manage-profile/security/api-tokens
6. Set the `JIR_AUTH` environment variable to the token, in the form `myemail@mycompany.com:TOKEN`. Alternatively, you can skip directly to adding it with `pass insert jir` and using `auth_backend: pass` in your config file.
7. Test it out with `bin/jir get MYPROJECT-123`

# Configuration 🔧

Once you have a simple `jir get` command working, for convenience, you should:
1. symlink the bin/jir to somewhere in your PATH (e.g. ~/bin), or add the bin/ directory to your PATH.
2. optional: for tab completion, run `jir completion bash`, save it to a file, and source it from your PATH. (See `jir completion --help` for more tab completion options)
3. Use a password manager (e.g. pass or gopass) to store your token, if you haven't already.

You will want some configuration to run `jir`. The easiest way is to run
`jir list builtin-configs` to see the list of available built-in configs and
run `jir install-builtin-config <config-name>` to create a symlink to it in the
`~/.config/jir` directory

Files in the directory `~/.config/jir` will be read in sorted order. You can
add your own additional config files in this directory with your custom
searches, outputs, etc.

See the `configs/` directory for example configs.

# Coming soon? 🤫

I have a JIRA TUI (sprint board) prototype in development. If there is interest in this, let me know!
