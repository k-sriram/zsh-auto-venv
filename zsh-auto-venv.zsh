function autovenv::verbose() {
    [[ $1 -ge 1 ]] && echo -e "$fg[blue]INFO$reset_color $2"
}

function autovenv::error() {
    [[ $1 -ge 0 ]] && >&2 echo -e "$fg_bold[red]ERROR$reset_color $2"
}

function autovenv::warning() {
    [[ $1 -ge 0 ]] && >&2 echo -e "$fg_bold[yellow]WARNING$reset_color $2"
}

function autovenv::_activate() {
    local verb auto venv_path excode
    verb=0
    excode=0
    while [ $# -gt 0 ]; do
        case "$1" in
            -q)
                verb=-1
                ;;
            -v)
                verb=1
                ;;
            -a)
                auto=1
                ;;
            -*)
                ;;
            *)
                venv_path=${1%/}
                ;;
        esac
        shift
    done

    if [[ -z "$venv_path" ]]; then
        autovenv::error $verb "Autovenv backend: venv dir to activate not specified"
        return 1
    fi

    autovenv::verbose $verb "Autovenv backend: Trying to activate venv $venv_path"
    
    if [[ $venv_path[1] != "/" ]]; then
        autovenv::verbose $verb "Autovenv backend: Path is relative correcting to absolute"
        venv_path="$PWD/$venv_path"
    fi        

    # Don't activate a venv without deactivating first. Although this is usually safe, this function wouldn't do it.
    if [[ -n "$VIRTUAL_ENV" ]]; then
        autovenv::error $verb "Autovenv backend: Already in a Virtual Environment. Deactivate it first"
        return 1
    else
        autovenv::verbose $verb "Autovenv backend: No venv active"
    fi

    # Cry if activation script doesn't exist
    if [[ ! -f "$venv_path/bin/activate" ]]; then
        autovenv::error $verb "Autovenv backend: virtual environment $venv_path or its activation script not found"
        return 1
    else
        autovenv::verbose $verb "Autovenv backend: Found activation script $venv_path/bin/activate"
    fi

    # Don't reactivate an already activated virtual environment
    if [[ "$venv_path" != "$VIRTUAL_ENV" ]]; then
        autovenv::verbose $verb "Autovenv backend: Activating venv $venv_path"
        source "$venv_path/bin/activate"
    else
        autovenv::verbose $verb "Autovenv backend: venv not activated because it was already active"
    fi

    # Error is venv didn't activate
    if [[ -z "$VIRTUAL_ENV" ]]; then
         autovenv::warning $verb "Autovenv backend: venv seems to be not activated"
    else
        if [[ "$(realpath $venv_path)" != "$(realpath $VIRTUAL_ENV)" ]]; then
            if [[ -n $auto ]]; then
                autovenv::warning $verb "Autovenv backend: venv misconfigured, you probably moved it after creating it. Deactivating"
                autovenv::deactivate
                excode=1
            else
                autovenv::warning $verb "Autovenv backend: venv misconfigured, you probably moved it after creating it"
            fi
        fi
    fi
    return $excode
}

function autovenv::deactivate() {
    if [[ -n "$VIRTUAL_ENV" ]]; then
        autovenv::verbose ${1:-0} "Deactivating $VIRTUAL_ENV"
        deactivate
    fi
    [[ -n "$AUTOVENV" ]] && unset AUTOVENV
}

# Finds all venv dirs in the given directory
function autovenv::_find_venv() {
    find $1 -maxdepth 3 -wholename "*/bin/activate" 2>/dev/null | grep -Po "(?<=$1/).*(?=/bin/activate)"
}

# Gives the path to the nearest target file
function autovenv::_check_path()
{
    local check_dir="$1"
    local check_file="$2"

    if [[ -f "${check_dir}/$check_file/bin/activate" ]]; then
        echo "${check_dir}/$check_file"
        return
    else
        # Abort search at file system root or HOME directory (latter is a performance optimisation).
        if [[ "$check_dir" = "/" || "$check_dir" = "$HOME" ]]; then
            return
        fi
        autovenv::_check_path "$(dirname "$check_dir")" "$check_file"
    fi
}

function autovenv::activate() {
    local args verb auto venv_path excode base_path printhelp
    args=($@)
    verb=0
    excode=0
    while [ $# -gt 0 ]; do
        case "$1" in
            -q)
                verb=-1
                ;;
            -v)
                verb=1
                ;;
            -a)
                auto=1
                ;;
            -h | --help)
                printhelp=1
                ;;
            -*)
                ;;
            *)
                venv_path=${1%/}
                ;;
        esac
        shift
    done
    # Print help
    if [[ -n $printhelp ]]; then
        local hstyle optstyle keystyle nostyle
        hstyle="$fg_bold[green]"
        optstyle="$fg[magenta]"
        keystyle="$fg[blue]"
        nostyle=$reset_color
        echo -e "${hstyle}USAGE: ${keystyle}$0 ${optstyle}[-a] [-h] [-q] [-v] ${keystyle}VENVPATH${nostyle}\n"
        echo -e "${hstyle}ARGUMENTS:${nostyle}"
        echo -e "  ${keystyle}VENVPATH${nostyle}          location of the venv"
        echo -e ""
        echo -e "${hstyle}OPTIONS:${nostyle}"
        echo -e "  ${optstyle}-a${nostyle}                automatic mode"
        echo -e "  ${optstyle}-h, --help${nostyle}        print this message"
        echo -e "  ${optstyle}-q${nostyle}                quiet"
        echo -e "  ${optstyle}-v${nostyle}                verbose\n"
        return
    fi
    # If a path is given, normalize the intention
    base_path=$PWD
    if [[ -n "$venv_path" ]]; then
        if [[ ! -d $venv_path ]]; then
            autovenv::error $verb "Given path is not a directory"
            return 1
        fi
        if [[ $venv_path[1] != "/" ]]; then
            venv_path="$(realpath -s $venv_path)"
            autovenv::verbose $verb "Path is relative converting to absolute $venv_path"
        fi
        if [[ -f $venv_path/bin/activate ]]; then
            autovenv::verbose $verb "Given path is a venv $venv_path"
        else
            autovenv::verbose $verb "Given path($venv_path) is not a venv using it as a base of search"
            base_path=$venv_path
            venv_path=""
        fi
    else
        autovenv::verbose $verb "No explicit venv path given"
    fi
    # if not given path is not a venv try to find for one
    if [[ -z "$venv_path" ]]; then
        autovenv::verbose $verb "Looking for venv with base path $base_path"
        if [[ -n $auto ]]; then
            local autovenvdir
            autovenvdir="${AUTOVENV_DIR:-".venv"}"
            autovenv::verbose $verb "Auto option given. Looking for $autovenvdir in current directory and parents"
            venv_path="$(autovenv::_check_path "$base_path" "$autovenvdir")"
            if [[ -z "$venv_path" ]]; then
                autovenv::verbose $verb "Search failed"
                return 1
            else
                autovenv::verbose $verb "Found venv $venv_path"
            fi
        else
            local venv_dir venvs
            # First try PWD
            autovenv::verbose $verb "Looking for venvs in base path"
            venvs=($(autovenv::_find_venv "$base_path"))
            if [[ -n "$venvs" ]]; then
                autovenv::verbose $verb "venv(s) found in base path"
                venv_dir=$base_path
            else
                # else try git_root
                autovenv::verbose $verb "No venv found in base path. Checking if in a git repository."
                local git_root
                git_root=$(git -C $base_path rev-parse --show-toplevel 2>/dev/null)
                if [[ -n "$git_root" ]]; then
                    if [[ "$git_root" == "$base_path" ]]; then
                        autovenv::verbose $verb "base path was git repository root"    
                    else
                        autovenv::verbose $verb "Git repository found. Looking for venvs in $git_root"
                        venvs=($(autovenv::_find_venv "$git_root"))
                    fi
                else
                    autovenv::verbose $verb "Not in a git repository"
                fi
                if [[ -n "$venvs" ]]; then
                    venv_dir=$git_root
                    autovenv::verbose $verb "venv(s) found in git root"
                else
                    [[ -n "$git_root" ]] && autovenv::verbose $verb "No venv found in git root"
                    if [[ $base_path != $HOME ]]; then
                        # else try home
                        autovenv::verbose $verb "Looking for venv in home directory"
                        venvs=($(autovenv::_find_venv "$HOME"))
                        if [[ -n "$venvs" ]]; then
                            autovenv::verbose $verb "venv(s) found in home directory"
                            venv_dir=$HOME
                        fi
                    fi
                fi
            fi
            if [[ -z "$venvs" ]]; then
                [[ $1 -ge 0 ]] && >&2 echo -e "No venv found"
                return 1
            else
                if [[ 1 -eq ${#venvs[@]} ]]; then
                    venv_path="$venv_dir/$venvs"
                    autovenv::verbose "(( $verb + 1 ))" "Using venv: $venv_path"
                else
                    local response
                    echo "$fg[white]Found multiple venvs in directory $venv_dir$reset_color"
                    printf '%s\n' "${venvs[@]}"
                    echo "$fg[white]Choose which venv you want to activate:$reset_color"
                    read response
                    while [[ ${venvs[(ie)$response]} -gt ${#venvs} ]]; do
                        echo "$response$fg[white] is not in $reset_color$venvs$fg[white] Please choose again:$reset_color"
                        read response
                    done
                    venv_path="$venv_dir/$response"
                    autovenv::verbose $verb "venv $venv_path chosen"
                fi
            fi
        fi
    fi
    if [[ -n $VIRTUAL_ENV ]]; then
        autovenv::deactivate $verb
    fi
    autovenv::_activate $args $venv_path
    excode=$?
    if [[ -n $auto ]]; then
        export AUTOVENV=$venv_path
    else
        unset AUTOVENV
    fi
    return $excode
}

function autovenv::autovenv(){
    if [[ -z "$VIRTUAL_ENV" && -n "$AUTOVENV" ]] unset AUTOVENV
    if [[ -n $AUTOVENV_DISABLE ]]; then
        return
    fi
    # First check auto deactivate
    if [[ -n "$VIRTUAL_ENV" && -z "$AUTOVENV_NOAUTODEACTIVATE" ]]; then
        local parentdir rpwd
        parentdir="$(dirname "$VIRTUAL_ENV")"
        # Normalize for symbolic links
        parentdir="$(realpath $parentdir)"
        rpwd = "$(realpath $PWD)"
        # Only deactivate if autovenv autoactivated the venv and we are outside the venv directory
        if [[ "$AUTOVENV" == "$VIRTUAL_ENV" && "$rpwd"/ != "$parentdir"/* ]]; then
            autovenv::deactivate
        fi
    fi
    if [[ -z "$VIRTUAL_ENV" || -z "$AUTOVENV_DONT_ACTIVATE_SUBDIR_VENV" && -n "$AUTOVENV" ]]; then
        autovenv::activate -a
    fi
}

if [[ -z $AUTOVENV_DISABLE ]]; then
    autoload -Uz add-zsh-hook
    add-zsh-hook chpwd autovenv::autovenv

    autovenv::autovenv
fi
