# zsh-auto-venv
Automatically activate venv when you enter a project folder.

## Installation

### [antigen](https://github.com/zsh-users/antigen)

1. Add the following to your `.zshrc`:

    ```sh
    antigen bundle k-sriram/zsh-auto-venv
    ```

2. Start a new terminal session.

### [oh-my-zsh](http://github.com/robbyrussell/oh-my-zsh)

1. Clone this repository into `$ZSH_CUSTOM/plugins` (by default `~/.oh-my-zsh/custom/plugins`)

    ```sh
    git clone https://github.com/k-sriram/zsh-auto-venv ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-auto-venv --depth=1
    ```

2. Add the plugin to the list of plugins for Oh My Zsh to load (inside `~/.zshrc`):

    ```sh
    plugins=(
      ...
      zsh-auto-venv
    )
    ```

3. Start a new terminal session.

### Manual (Git Clone)

1. Clone this repository somewhere on your machine.

    ```sh
    git clone https://github.com/k-sriram/zsh-auto-venv ~/.zsh/zsh-auto-venv
    ```

2. Add the following to your `.zshrc`:

    ```sh
    source ~/.zsh/zsh-auto-venv/zsh-auto-venv.zsh
    ```

3. Start a new terminal session.

## Configuration

`zsh-auto-venv` can be configured using environment variables.

Disable automatic activation by setting `AUTOVENV_DISABLE` to any value. Most of the automatic features are disabled when the user manually activates a `venv`.

For the purposes of auto-activation only `venv`s with the name defined by `AUTOVENV_DIR` are looked for. It not set a default value of `.venv` is used.

This plugin automatically deactivates `venv` as you leave the directory that they are situated in or any its children. This only auto-deactivates `venv`s that were activated automatically by entering the directory. If you want to disable this behaviour set `AUTOVENV_NOAUTODEACTIVATE`.

With an already auto-activated `venv` if you move into a new sub-directory that also has an auto-activatable `venv`, this new `venv` will be activated. To disable this behaviour set `AUTOVENV_DONT_ACTIVATE_SUBDIR_VENV`

## Utility scripts

This plugin provides a function `autovenv::activate`. If you intend to use it, it is advised alias it to something more usable.

```sh
alias venv='autovenv::activate'
```

This function searches for `venv`s. It first looks in the current directory / path passed as argument, then at the root of a git repository if inside one, then in the user's home directory. This function is not just limited to `venv`s of name `AUTOENV_DIR`, it looks for them by checking if they have a `./bin/activate` file.