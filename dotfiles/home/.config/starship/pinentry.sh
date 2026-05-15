function check_pinentry_mode() {
    local gpg_agent_conf="$HOME/.gnupg/gpg-agent.conf"
    local pinentry_program_mac="pinentry-mac"

    local current_pinentry_program
    current_pinentry_program=$(grep "^pinentry-program" "$gpg_agent_conf")

    if [[ "$current_pinentry_program" == *"$pinentry_program_mac"* ]]; then
        echo "󰌋"
    else
        echo ""
    fi
}

check_pinentry_mode
