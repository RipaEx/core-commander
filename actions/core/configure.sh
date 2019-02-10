#!/usr/bin/env bash

core_configure_reset ()
{
    read -p "Are you sure you want to reset the configuration? [y/N] : " choice

    if [[ "$choice" =~ ^(yes|y|Y) ]]; then
        info "Resetting configuration..."

        if [[ ! -d "$CORE_DATA" ]]; then
            mkdir "$CORE_DATA"
        fi

        rm -rf "$CORE_CONFIG"

        cp -r "${CORE_DIR}/packages/core/lib/config/${CORE_TOKEN}/${CORE_NETWORK}" "$CORE_CONFIG"
        cp "${CORE_DIR}/packages/crypto/lib/networks/${CORE_TOKEN}/${CORE_NETWORK}.json" "$CORE_CONFIG/network.json"

        info "Reset configuration!"
    else
        warning "Skipping configuration reset..."
    fi
}

core_configure ()
{
    ascii

    local configured=false

    if [[ -d "$CORE_CONFIG" ]]; then
        read -p "We found an Ark Core configuration, do you want to overwrite it? [y/N] : " choice

        if [[ "$choice" =~ ^(yes|y|Y) ]]; then
            __core_configure_pre

            rm -rf "$CORE_CONFIG"

            __core_configure_network

            core_configure_database

            core_configure_log_level

            __core_configure_post

            configured=true
        else
            warning "Skipping configuration..."
        fi
    else
        __core_configure_pre

        __core_configure_network

        core_configure_database

        core_configure_log_level

        __core_configure_post

        configured=true
    fi

    if [[ "$configured" = true ]]; then
        read -p "Ark Core has been configured, would you like to start the relay? [Y/n] : " choice

        if [[ -z "$choice" || "$choice" =~ ^(yes|y|Y) ]]; then
            relay_start
        fi
    fi
}

__core_configure_pre ()
{
    if [[ "$STATUS_RELAY" = "On" ]]; then
        relay_stop
    fi

    if [[ "$STATUS_FORGER" = "On" ]]; then
        forger_stop
    fi
}

__core_configure_post ()
{
    database_create

    lerna clean --yes
    lerna bootstrap | tee -a "$commander_log"

    # Make sure the git commit hash is not modified by a local yarn.lock
    git reset --hard | tee -a "$commander_log"
}

__core_configure_network ()
{
    ascii

    info "Which network would you like to configure?"

    validNetworks=("xpx mainnet" "xpx devnet" "ark mainnet" "ark devnet" "testnet")

    select opt in "${validNetworks[@]}"; do
        case "$opt" in
            "xpx mainnet")
                __core_configure_branch "master"
                __core_configure_core "mainnet"
                __core_configure_commander "mainnet"
                __core_configure_environment "xpx mainnet"
                break
            ;;
            "xpx devnet")
                __core_configure_branch "master"
                __core_configure_core "devnet"
                __core_configure_commander "devnet"
                __core_configure_environment "xpx devnet"
                break
            ;;
            "ark mainnet")
                __core_configure_branch "master"
                __core_configure_core "mainnet"
                __core_configure_commander "mainnet"
                __core_configure_environment "ark mainnet"
                break
            ;;
            "ark devnet")
                __core_configure_branch "develop"
                __core_configure_core "devnet"
                __core_configure_commander "devnet"
                __core_configure_environment "ark devnet"
                break
            ;;
            "testnet")
                __core_configure_branch "develop"
                __core_configure_core "testnet"
                __core_configure_commander "testnet"
                __core_configure_environment "ark testnet"
                break
            ;;
            *)
                echo "Invalid option $REPLY"
            ;;
        esac
    done

    . "$commander_config"
}

__core_configure_core ()
{
    if [[ ! -d "$CORE_DATA" ]]; then
        mkdir "$CORE_DATA"
    fi

    cp -r "${CORE_DIR}/packages/core/lib/config/${CORE_TOKEN}/$1" "$CORE_CONFIG"
    cp "${CORE_DIR}/packages/crypto/lib/networks/${CORE_TOKEN}/$1.json" "$CORE_CONFIG/network.json"
}

__core_configure_commander ()
{
    sed -i -e "s/CORE_NETWORK=$CORE_NETWORK/CORE_NETWORK=$1/g" "$commander_config"
}

__core_configure_environment ()
{
    heading "Creating Environment configuration..."

    local envFile="${CORE_DATA}/.env"

    touch "$envFile"

    grep -q '^ARK_P2P_HOST' "$envFile" 2>&1 || echo 'ARK_P2P_HOST=0.0.0.0' >> "$envFile" 2>&1
    grep -q '^ARK_API_HOST' "$envFile" 2>&1 || echo 'ARK_API_HOST=0.0.0.0' >> "$envFile" 2>&1

    if [[ "$1" = "xpx mainnet" ]]; then
        grep -q '^ARK_P2P_PORT' "$envFile" 2>&1 || echo 'ARK_P2P_PORT=5501' >> "$envFile" 2>&1
        grep -q '^ARK_API_PORT' "$envFile" 2>&1 || echo 'ARK_API_PORT=5502' >> "$envFile" 2>&1
    fi

    if [[ "$1" = "xpx devnet" ]]; then
        grep -q '^ARK_P2P_PORT' "$envFile" 2>&1 || echo 'ARK_P2P_PORT=7501' >> "$envFile" 2>&1
        grep -q '^ARK_API_PORT' "$envFile" 2>&1 || echo 'ARK_API_PORT=7502' >> "$envFile" 2>&1
    fi

    if [[ "$1" = "ark testnet" ]]; then
        grep -q '^ARK_P2P_PORT' "$envFile" 2>&1 || echo 'ARK_P2P_PORT=4000' >> "$envFile" 2>&1
        grep -q '^ARK_API_PORT' "$envFile" 2>&1 || echo 'ARK_API_PORT=4003' >> "$envFile" 2>&1
    fi

    if [[ "$1" = "ark mainnet" ]]; then
        grep -q '^ARK_P2P_PORT' "$envFile" 2>&1 || echo 'ARK_P2P_PORT=4001' >> "$envFile" 2>&1
        grep -q '^ARK_API_PORT' "$envFile" 2>&1 || echo 'ARK_API_PORT=4003' >> "$envFile" 2>&1
    fi

    if [[ "$1" = "ark devnet" ]]; then
        grep -q '^ARK_P2P_PORT' "$envFile" 2>&1 || echo 'ARK_P2P_PORT=4002' >> "$envFile" 2>&1
        grep -q '^ARK_API_PORT' "$envFile" 2>&1 || echo 'ARK_API_PORT=4003' >> "$envFile" 2>&1
    fi

    grep -q '^ARK_WEBHOOKS_HOST' "$envFile" 2>&1 || echo 'ARK_WEBHOOKS_HOST=0.0.0.0' >> "$envFile" 2>&1
    grep -q '^ARK_WEBHOOKS_PORT' "$envFile" 2>&1 || echo 'ARK_WEBHOOKS_PORT=4004' >> "$envFile" 2>&1

    grep -q '^ARK_GRAPHQL_HOST' "$envFile" 2>&1 || echo 'ARK_GRAPHQL_HOST=0.0.0.0' >> "$envFile" 2>&1
    grep -q '^ARK_GRAPHQL_PORT' "$envFile" 2>&1 || echo 'ARK_GRAPHQL_PORT=4005' >> "$envFile" 2>&1

    grep -q '^ARK_JSON_RPC_HOST' "$envFile" 2>&1 || echo 'ARK_JSON_RPC_HOST=0.0.0.0' >> "$envFile" 2>&1
    grep -q '^ARK_JSON_RPC_PORT' "$envFile" 2>&1 || echo 'ARK_JSON_RPC_PORT=8080' >> "$envFile" 2>&1

    success "Created Environment configuration!"
}

__core_configure_branch ()
{
    heading "Changing git branch..."

    sed -i -e "s/CORE_BRANCH=$CORE_BRANCH/CORE_BRANCH=$1/g" "$commander_config"
    . "${CORE_DATA}/.env"

    cd "$CORE_DIR"
    git reset --hard | tee -a "$commander_log"
    git pull | tee -a "$commander_log"
    git checkout "$1" | tee -a "$commander_log"

    success "Changed git branch!"
}
