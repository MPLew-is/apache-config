# apache-config #


[![CircleCI build status](https://circleci.com/gh/MPLew-is/apache-config.svg?style=svg)](https://circleci.com/gh/MPLew-is/apache-config)


## What? ##

This is an Apache configuration management script, inspired by `a2enmod` and co. 

This script allows you to run simple commands like `apache-config enable module rewrite` instead of having to edit the configuration files manually, meaning it can be automated if needed.

The primary goal of this script is to be able to start with a "vanilla" Apache installation, and get multiple virtual hosts running, all without touching an existing `.conf` file.

Please note that this is **experimental**; I would strongly advise making a copy of your configuration before installing this script.

Please feel free to file an issue if you find it, and I'll work to get it fixed as soon as I can.


## Why? ##

I've found myself growing more and more frustrated with managing local/development environments on macOS (and Linux distributions that don't have an equivalent of a2enmod), so this is an attempt at a "port" of the functionality of Debian's `a2enmod` to other platforms.


## How? ##


### Requirements ###

- `httpd` 2.2 or 2.4

	- The script needs to be able to find the `httpd` executable in its PATH

The script is written to be as POSIX-compliant as possible, but if you find any inadvertent errors or bashisms, please file an issue!


### Basic overview of commands ###

- `apache-config help` prints a help message explaining the purpose of the script

	- `apache-config help --verbose` prints even more help text

- `apache-config check` checks that `apache-config` has been installed, exiting with a non-zero status if not

- `apache-config install` sets up the needed directories and configuration files

	- Please be aware, this command adds a few lines at the end of your existing `httpd.conf` file, but they can be removed easily if you ever want to uninstall

- `apache-config list {type} {status}` lists all files with the given type and status

	- The supported statuses are:
	
		- `enabled`: any currently-enabled files
		
		- `available`: any files in the `{type}-available` directory
		
		- `disabled`: any files in the `{type}-available` directory that are not enabled

- `apache-config enable {type} {name}` symlinks a file from an `available` folder into an `enabled` folder, from where Apache will include it

	- The different types and folder structure are discussed further below

- `apache-config disable {type} {name}` removes the links created by `apache-config enable`

- `apache-config --quiet {command}` can be used to silence status output from the script (`--help` excluded)


More information is available by running `apache-config help` once installed


### Installation with homebrew (recommended) ###

[`homebrew`](https://github.com/Homebrew/brew) is the recommended way of installing `apache-config`. This will take care of most of the initial setup, so you can get started more quickly. Simply run the commands below to get started:

```shell
brew tap MPLew-is/experimental
brew install apache-config
apache-config install
```


### Manual installation ###

There isn't any reason the script can't be used on platforms other than macOS, but so far I've only tested it on CentOS, and briefly at that. If you want to use it on other platforms, you'll need to copy the script to your system, and run `./apache-config.sh install`, or move it to somewhere included in your PATH.


### Uninstallation ###

There's not really a nice way of uninstalling `apache-config` at the moment, due to editing your existing `httpd.conf` file. The easiest way is to open `httpd.conf` and remove all blocks that look like this:

```conf
Define VENDOR_MPLEWIS_CONFIG_CONTROLLER_{number}_{number} 'true'

<IfDefine VENDOR_MPLEWIS_CONFIG_CONTROLLER_{number}_{number}>
	<IfDefine !VENDOR_MPLEWIS_CONFIG_CONTROLLER>
		Define VENDOR_MPLEWIS_CONFIG_CONTROLLER '{number}_{number}'
		Include {Apache config root}/other/config-controller.conf
	</IfDefine>
</IfDefine>
```

After that, you can safely remove the `other` directory, unless your installation stored files there initially.


## Where? ##

As of now, there are four types of configuration files supported, below, in the order in which they are included. There are no special requirements for any of these, but these are what I had in mind when writing the script:

- A `module` is meant to contain `LoadModule` directives and initial configuration of the modules if the defaults are not adequate

- A `config` is meant to contain server-wide directives, such as those that depend on multiple modules to run

	- I am currently using files of this type to configure `mod_ssl` and to add a few macros (using `mod_macro`) that are used by other configuration files

- A `site` is meant to contain directives related to initializing a host

	- This is where all of my `VirtualHost` blocks live

- A `cleanup` is meant to do anything that needs to be done after the `VirtualHost` blocks have been included

	- For instance, this is where I undefine the macros created in a `config`, which is the recommended practice to avoid possible naming conflicts


By default, a folder for each of these types is created upon install in a subfolder of the main Apache configuration directory. The basic structure looks like this:

```markdown
- Apache configuration root

	- httpd.conf
	
	- extra
	
	- **other** (created if not present)
		
		- modules-available
		
		- modules-enabled
		
		- configs-available
		
		- configs-enabled
		
		- sites-available
		
		- sites-enabled
		
		- cleanups-available
		
		- cleanups-enabled
```


These folders serve largely the same purpose as in `a2enmod` and friends, with the files you want to be included copied or symlinked into the `*-available` directories, and then enabled from a terminal, which symlinks the files into the `*-enabled` directories, which are included into the Apache configuration files.

You should never place or edit files directly into the `*-enabled` folders; rather, use the `enable` and `disable` commands as intended. Anything placed into those folders can be deleted at any time without making a backup, as it is assumed that anything in that folder is a symlink.


### Summary (TL;DR) ###

1. Copy or symlink your files into `{Apache configuration root}/other/*-available` (generally something like `/usr/local/etc/apache2/2.4/other/*-available` if you installed Apache using homebrew)

	- These files must end with `.conf` to be included in Apache's configuration

	- You can also provide the filename to the enable command, and it will copy your files into the `available` directory for you

2. Enable the file with `apache-config enable {type} {name}`

	- For instance, if you wanted to add a module named `rewrite` and copied a file named `rewrite.conf` to `modules-available`, the command would be `apache-config enable module rewrite`
	
	- If you provide a name that is not in the appropriate `available` directory, `apache-config` will treat it as a file, and if that file exists, will copy it into the `available` directory for you, changing the file extension to `.conf` in the process

3. Disable the file with `apache-config disable {type} {name}`

	- Just undoes #2




### Random tips ###

You can append as many files of one type as you like to the command, for instance `apache-config enable rewrite headers ssl ...`. This makes using the script with `xargs` a lot easier.

You can edit the script however works best for you. I've tried my best to put everything that could be considered "configuration" in a group of variables at the top of the file, so you can, for instance, easily change the directory from `other` to whatever you want.



## Who? ##

Hi, I'm Mike, an IT administrator and full-stack developer, dealing primarily with LAMP-based stacks. I'm currently remotely managing a small group of development workstations whose primary users are unfamiliar with the internals of Apache and Unix/Linux scripting. Trying to manage the configuration files manually was getting to be too much of a hassle, so I decided I had enough, and here we are.



## To do/known issues ##

- Add `man` page/other documentation
