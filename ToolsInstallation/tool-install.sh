#!/usr/bin/env bash


## supports MacOS only

osName="$(uname -s)"

if [[ "$osName" != Darwin* ]]
then
    echo "$osName not supported"
    exit 1
fi

## comma separated apps to install
# CLI Applications
cliAppsToInstall="jq,telnet,wget,grep,awscli,kubectl,docker,git,python@2.7,python@3.10,pip-completion,go,tfenv,sshuttle"

# Desktop applications
desktopAppsToInstall="google-chrome,flock,iterm2,visual-studio-code,sublime-text,lens,thunderbird,authy,clipy,zoom,openvpn"

# terraform required versions, installed using tfenv
terraformRequiredVersions="0.11.14,0.14.8"


# install brew if not installed already
if ! command -v brew &> /dev/null
then
    echo "brew in not installed, installing"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# update bash
brew install bash

# add latest bash shell to available shells

bashPATH="/usr/local/bin/bash"
shellsPATH="/etc/shells"
bashProfilePath="$HOME/.bash_profile"

if [[ "$SHELL" == "$bashPATH" ]]
then
    echo "current shell is already $SHELL"
else
    
    if grep -Fxq "$bashPATH" "$shellsPATH"
    then
        echo "$bashPATH already exists in $shellsPATH"
    else
        echo "$bashPATH" | sudo tee -a $shellsPATH
    fi

    # # change shell to use latest bash shell
    chsh -s $bashPATH

fi


# install bash bash-completion
brew install bash-completion@2

bashCompletionLine='[[ -r "/usr/local/etc/profile.d/bash_completion.sh" ]] && . "/usr/local/etc/profile.d/bash_completion.sh"'

if grep -Fxq "$bashCompletionLine" "$bashProfilePath"
then
    echo "bash completion line already exists in $bashProfilePath"
else
    echo "bash completion line added in $bashProfilePath"
    echo """
# added for bash autocompletion
[[ -r \"/usr/local/etc/profile.d/bash_completion.sh\" ]] && . \"/usr/local/etc/profile.d/bash_completion.sh\"
""" >> "$bashProfilePath"
fi

## bash completion for 3rd party tools, install tool using brew, as most of them ships with bash auto completion
# --cask flag is for Desktop applications

installApps() {
    apps="$1"
    appType="$2"
    cmdSuffix=""
    if [[ "$appType" == "desktop" ]]
    then
        cmdSuffix="--cask"
    fi

    for app in $(echo $apps | sed "s/,/ /g")
    do
        read -p "install $app ? " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]
        then
            echo "installing $app"
            brew install $app $cmdSuffix
        fi

    done

}

installApps "$cliAppsToInstall" "cli"
installApps "$desktopAppsToInstall" "desktop"

# source ~/.bash_profile again in current shell update the change
source ~/.bash_profile

# install terraform versions
if command -v tfenv &> /dev/null
then
    echo "tfenv is present, installing versions $terraformRequiredVersions"
    installedVersions=`tfenv list | sed 's/(.*)//; s/\*//' | xargs`
    for teVerion in $(echo $terraformRequiredVersions | sed "s/,/ /g")
    do
        if echo "$installedVersions" | grep -qw "$teVerion"
        then
            echo "$teVerion already installed"
        fi
    done
    lastVersion=`echo $terraformRequiredVersions | awk -F"," '{print $NF}'`
    echo "setting $lastVersion as default"
    tfenv use $lastVersion
fi


# configure aws cli
if command -v aws &> /dev/null
then
    read -p "aws cli is present, need to configure ? " -n 1 -r
    if [[ $REPLY =~ ^[Yy]$ ]]
    then
        echo;echo "configure aws"
        aws configure
    else
        echo
    fi
fi

# configure EKS Cluster
read -p "need to update kubeconfig to connect EKS ? " -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]
then
    if ! command -v aws &> /dev/null
    then
        echo "aws cli command doesn't exist, install awscli first"
    else
        eksRegion="us-east-1"
        echo;read -p "Enter EKS region(default=us-east-1): " eksRegion
        read -p "Enter EKS Cluster: " eksCluster
        while [[ "$eksCluster" = "" ]]
        do
            read -p "Enter EKS Cluster: " eksCluster 
        done

        # update kubeconfig 
        aws eks --region $eksRegion update-kubeconfig --name "$eksCluster"
    fi
else
    echo
fi
