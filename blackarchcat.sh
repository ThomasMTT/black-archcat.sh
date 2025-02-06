#!/bin/bash                                   

# Define the list of checkpoints
declare -a CHECKPOINTS=("install_blackarch" "install_systemwide_tools" "install_local_tools" "install_docker_tools" "download_wordlists" "cleanup")   

# Define the checkpoint file
CHECKPOINT_FILE="/tmp/BLACKARCHCAT-CHECKPOINT"

# Function to update the checkpoint
update_checkpoint() {
    local checkpoint=$1
    echo "$checkpoint" > "$CHECKPOINT_FILE"
}

# Function to get the last completed checkpoint
get_last_checkpoint() {
    if [ -f "$CHECKPOINT_FILE" ]; then
        cat "$CHECKPOINT_FILE"
    else
        # Default to the beginning if no checkpoint exists
        echo "${CHECKPOINTS[0]}"  
    fi
}

# If exitcode of command or function is non-zero display error and exit
exit_code_check() {
        if [ "$1" -ne 0 ]; then
                echo "$2" && return "$1"
        fi
}

cleanup() {
    rm -f "$CHECKPOINT_FILE"
}

net_tools="$HOME/tools/network"
web_tools="$HOME/tools/web"

manage_required_programs() {

    # Install programs if not present
    which pipx &>/dev/null || sudo pacman -S --noconfirm python-pipx || exit $?
    which go &>/dev/null || sudo pacman -S --noconfirm go || exit $?
    which jq &>/dev/null || sudo pacman -S --noconfirm jq || exit $?
    which gem &>/dev/null || sudo pacman -S --noconfirm ruby || exit $?
    which git &>/dev/null || sudo pacman -S --noconfirm git || exit $?

    if ! which bundler &>/dev/null; then 
        gem install bundler || exit $?
        bundle_path=$(find "$HOME"/.local/share/gem/ruby/*/bin/bundle | head -n1)
        if [[ -n $bundle_path ]]; then
            ln -s "$bundle_path" "$RUBY_BIN_DIR"
            ln -s "$bundle_path"r "$RUBY_BIN_DIR"
        fi
    fi
}

trap cancel SIGINT
cancel() {
    deactivate 2>/dev/null
    exit $?
}

check_root() {
    [[ $(whoami) == "root" ]] && echo "run as user, not root" && exit 1
}

check_localpac(){
    which localpac &>/dev/null
    exit_code_check $? "localpac tool required to run this script" || exit 127
}

install_blackarch() {
    [[ -n $(grep -o blackarch < /etc/pacman.conf  | head -n1) ]]
    exit_code_check $? "blackarch is already installed, skipping" && return 0

    if [[ ! -e strap.sh ]]; then
        wget https://blackarch.org/strap.sh
        exit_code_check $? "Error while downloading strap.sh" || exit $?

        chmod +x strap.sh
        exit_code_check $? "Error while giving strap.sh execute permisions" || exit $?

        # Dont install all possible bloatware tools system-wide, no thanks :)
        sed -i "s/pacman -S --noconfirm --needed blackarch-officials//g" strap.sh
    fi
    sudo ./strap.sh
    rm ./strap.sh 2>/dev/null
}

## SYSTEM WIDE TOOLS AND PACKAGES
install_systemwide_tools() {
    update_checkpoint "${FUNCNAME[0]}"

    sudo pacman --noconfirm -Syy
    exit_code_check $? "Error while updating blackarch.db" || exit $?

    sudo pacman --noconfirm -S rustup docker docker-compose dnsenum burpsuite wireshark-qt nmap metasploit
    exit_code_check $? "Error while installing system wide tools and packages" || exit $?

    rustup default stable 
    exit_code_check $? "Error while setting default rust to stable (required for netexec)" || exit $?

    sudo systemctl enable --now docker.service
    exit_code_check $? "Error while enabling docker.service" || exit $?

    sudo systemctl enable --now docker.socket
    exit_code_check $? "Error while enabling docker.socket" || exit $?
}

## LOCAL TOOLS
install_local_tools() {
    update_checkpoint "${FUNCNAME[0]}"

    install_pkinittools() { # NOT A CHECKPOINT
        ## Pkinittools
        rm -rf "$net_tools/pkinittools" 2>/dev/null
        git clone https://github.com/dirkjanm/PKINITtools "$net_tools/pkinittools"
        exit_code_check $? "Error while downloading pkinittools " || exit $?

        python -m venv "$net_tools/pkinittools"
        exit_code_check $? "Error while creating virtual env for pkinittools" || exit $?

        trap deactivate SIGINT
        # shellcheck disable=SC1091
        source "$net_tools"/pkinittools/bin/activate

        pip install -r "$net_tools/pkinittools"/requirements.txt
        exit_code_check $? "Error while installing requirements for pkinittools" || exit $?

        # shellcheck disable=SC2044
        for python_file in $(find "$net_tools/pkinittools" -maxdepth 1 -type f -name "*.py"); do
            filename=$(basename "$python_file")

            chmod +x "$python_file"
            exit_code_check $? "Error while giving pkinittool's $filename execution rights" || exit $?

            venv_python_path="$net_tools/pkinittools/bin/python"
            venv_python_path_enc="${venv_python_path//\//\\/}"
            
            sed -i "s/#\!\/usr\/bin\/env python/#\!$venv_python_path_enc/g" "$python_file" || 
                \ sed -i "1s/^/#\!$venv_python_path_enc\n/" "$python_file"
            exit_code_check $? "Error while giving pkinittool's $filename execution rights" || exit $?
            
            unlink "$HOME"/.local/bin/pkinit-"${filename//.py/}" 2>/dev/null
            ln -s "$net_tools"/pkinittools/"$filename" "$HOME"/.local/bin/pkinit-"${filename//.py/}"
            exit_code_check $? "Error while linking pkinittool's $filename to ~/.local/bin" || exit $?
        done
    }

    install_kerbrute() {
        ## Kerbrute
        wget -P "$net_tools/kerbrute" https://github.com/ropnop/kerbrute/releases/latest/download/kerbrute_linux_amd64
        exit_code_check $? "Error while downloading kerbrute_linux_amd64 " || exit $?

        chmod +x "$net_tools"/kerbrute/kerbrute_linux_amd64
        exit_code_check $? "Error while giving kerbrute_linux_amd64 execution rights " || exit $?

        unlink "$HOME"/.local/bin/kerbrute 2>/dev/null
        ln -s "$net_tools"/kerbrute/kerbrute_linux_amd64 "$HOME"/.local/bin/kerbrute
        exit_code_check $? "Error while linking kerbrute_linux_amd64 to ~/.local/bin " || exit $?

    }

    # Localpac installed tools (it can multi-install, but since this script has to detect errors to exit...)
    local_tools=(
        "LANG p" 
        "LINK_TO $net_tools"
        bloodhound-ce 
        pywhisker 
        certipy 
        pennyw0rth/netexec
        "-P impacket- impacket"

        "LINK_TO $web_tools"
        arthaud/git-dumper

        "LANG r" 
        "LINK_TO $net_tools"
        evil-winrm

        "LINK_TO $web_tools"
        urbanadventurer/whatweb

        "LANG g" 
        "LINK_TO $web_tools"
        oj/gobuster
        ffuf/ffuf
    )

    for tool_info in "${local_tools[@]}"; do

        # Check for params
        if [[ $tool_info == LANG* ]] ; then
            LANG="-$(echo "$tool_info" | awk '{print $2}')"
            continue
        elif [[ $tool_info == LINK_TO* ]]; then
            LINK_TO="$(echo "$tool_info" | awk '{print $2}')"
            MINUS_L="-L"
            [ -z "$LINK_TO" ] && MINUS_L=""
            continue
        else 
            tool_name=$tool_info
        fi

        echo "executing localpac -S "$LANG" "$MINUS_L" "$LINK_TO" $tool_name"
        # Run localpac with custom params
        localpac -S "$LANG" "$MINUS_L" "$LINK_TO" "$tool_name"
        exit_code_check $? "Error while installing $tool_name" || return $?

    done 


    # Manually installed tools
    if [ "$(find "$HOME"/.local/bin/ -maxdepth 1 -type l -name "pkinit-get*" | wc -l)" -lt 3 ]; then
        install_pkinittools
    fi

    [ ! -f "$HOME"/.local/bin/kerbrute ] && install_kerbrute
    echo boof
}

# Docker based tools
install_docker_tools() {
    update_checkpoint "${FUNCNAME[0]}"

    # Bloodhound CE server
    mkdir -p "$net_tools/bloodhound-ce-server" 2>/dev/null

    curl -s -L https://ghst.ly/getbhce -o "$net_tools/bloodhound-ce-server/docker-compose.yml"
    exit_code_check $? "Error while downloading dockerfile for bloodhound-ce-server" || exit $?

    echo -e "#!/bin/bash\nsudo docker compose -f $net_tools/bloodhound-ce-server/docker-compose.yml up" > "$net_tools/bloodhound-ce-server/bloodhound-ce-server.sh"

    chmod +x "$net_tools/bloodhound-ce-server/bloodhound-ce-server.sh"
    exit_code_check $? "Error while giving bloodhound-ce-server execution rights" || exit $?

    unlink "$HOME"/.local/bin/bloodhound-ce-server 2>/dev/null
    ln -s "$net_tools"/bloodhound-ce-server/bloodhound-ce-server.sh "$HOME"/.local/bin/bloodhound-ce-server
    exit_code_check $? "Error while linking bloodhound-ce-server to ~/.local/bin" || exit $?
}

download_wordlists() {
    git clone https://github.com/danielmiessler/SecLists "$HOME"/wordlists/
}


main() {
    check_root
    check_localpac
    manage_required_programs

    # Implement the main script logic to resume from the last checkpoint
    last_checkpoint=$(get_last_checkpoint)

    # Determine the index of the last completed Checkpoint
    for i in "${!CHECKPOINTS[@]}"; do
        if [ "${CHECKPOINTS[$i]}" == "$last_checkpoint" ]; then
            break
        fi
    done

    # Run the last checkpoint to the end
    for (( j=i ;j < ${#CHECKPOINTS[@]}; j++ )); do
        Checkpoint=${CHECKPOINTS[$j]}
        
        # Define checkpoints order
        case $Checkpoint in
            "install_blackarch")            $Checkpoint || exit $?;;
            "install_systemwide_tools")     $Checkpoint || exit $?;;
            "install_local_tools")          $Checkpoint || exit $?;;
            "install_docker_tools")         $Checkpoint || exit $?;;
            "download_wordlists")           $Checkpoint || exit $?;;
            "cleanup")                      $Checkpoint || exit $?;;
            
            *) echo "Checkpoint $Checkpoint doesnt have any linked function... skipping to ${CHECKPOINTS[$(( i + 1))]}"
        esac
    done
}

main "$@"