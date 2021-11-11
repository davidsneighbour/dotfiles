shopt -s extglob #it's a needable for the bash completion support
set +o nounset

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/home/patrick/.bin/google-cloud-sdk/path.bash.inc' ]; then 
  source '/home/patrick/.bin/google-cloud-sdk/path.bash.inc'; 
fi

# The next line enables shell command completion for gcloud.
if [ -f '/home/patrick/.bin/google-cloud-sdk/completion.bash.inc' ]; then 
  source '/home/patrick/.bin/google-cloud-sdk/completion.bash.inc'; 
fi

# running autojump completion file
if [ -f "/usr/share/autojump/autojump.bash" ]; then 
  source '/usr/share/autojump/autojump.bash'; 
fi

# initializes completion for grunt
gruntcompletion() {
    if hash grunt 2>/dev/null; then
       	eval "$(grunt --completion=bash)"
    fi
}
gruntcompletion

complete -A hostname rsh rcp telnet r ftp ping fail 
complete -A export printenv
complete -A variable export local readonly unset
complete -A enabled builtin
complete -A alias alias unalias
complete -A function function
complete -A user su mail finger

complete -A helptopic help # currently same as builtins
complete -A shopt shopt
complete -A stopped -P '%' bg
complete -A job -P '%' fg jobs disown

complete -A directory mkdir rmdir
complete -A directory -o default cd

complete -f -o default -X '*.+(zip|ZIP)' zip #there is completion for the some tools that works with filenames
complete -f -o default -X '!*.+(zip|ZIP)' unzip
complete -f -o default -X '*.+(z|Z)' compress
complete -f -o default -X '!*.+(z|Z)' uncompress
complete -f -o default -X '*.+(gz|GZ)' gzip
complete -f -o default -X '!*.+(gz|GZ)' gunzip
complete -f -o default -X '*.+(bz2|BZ2)' bzip2
complete -f -o default -X '!*.+(bz2|BZ2)' bunzip2

complete -f -o default -X '!*.ps' gs ghostview ps2pdf ps2ascii
complete -f -o default -X '!*.dvi' dvips dvipdf xdvi dviselect dvitype
complete -f -o default -X '!*.pdf' acroread pdf2ps
complete -f -o default -X '!*.+(pdf|ps)' gv
complete -f -o default -X '!*.texi*' makeinfo texi2dvi texi2html texi2pdf
complete -f -o default -X '!*.tex' tex latex slitex
complete -f -o default -X '!*.lyx' lyx
complete -f -o default -X '!*.+(htm*|HTM*)' lynx html2ps

complete -f -o default -X '!*.+(jp*g|gif|xpm|png|bmp)' xv gimp
complete -f -o default -X '!*.+(mp3|MP3)' mpg123 mpg321
complete -f -o default -X '!*.+(ogg|OGG)' ogg123

complete -f -o default -X '!*.pl' perl perl5


_ssh() 
{
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    opts=$(grep '^Host' ~/.ssh/config ~/.ssh/config.d/* 2>/dev/null | grep -v '[?*]' | cut -d ' ' -f 2-)

    COMPREPLY=( $(compgen -W "$opts" -- ${cur}) )
    return 0
}
complete -F _ssh ssh


SSH_COMPLETE=( $(cut -f1 -d' ' ~/.ssh/known_hosts |\
                 tr ',' '\n' |\
                 sort -u |\
                 grep -e '[[:alpha:]]') )
complete -o default -W "${SSH_COMPLETE[*]}" ssh


# load hugo autocomplete
if [ -d "$HOME/.dotfiles/bash/completions/hugo.sh" ] ; then
    . "$HOME/.dotfiles/bash/completions/hugo.sh"
fi


# load npm autocomplete
if [ -d "$HOME/.dotfiles/bash/completions/npm.sh" ] ; then
    . "$HOME/.dotfiles/bash/completions/npm.sh"
fi
