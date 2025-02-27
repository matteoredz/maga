#!/usr/bin/env ruby

# MAGA: My Amazing Git Assistant.
#
# A tiny wrapper for Git to perform annoying tasks with ease.

require "debug"

begin
  require "dry/cli"
rescue LoadError
  puts "> dry-cli is missing, installing now..."
  puts `gem install dry-cli -v '~> 1.2'`

  if $?.success?
    puts "\n> dry-cli was installed."
    Gem.refresh
    retry
  else
    puts "\n> dry-cli was not installed."
    exit
  end
end

module Maga
  module CLI
    module Commands
      extend Dry::CLI::Registry

      class Version < Dry::CLI::Command
        desc "Print Git version"
        def call(*)
          puts `git --version`
        end
      end

      class Sync < Dry::CLI::Command
        desc "Fetch from remote and delete gone brances from current"
        def call(*)
          puts "\n> Pulling with prune from remote..."
          puts `git pull --prune`

          puts "\n> Deleting gone branches..."
          puts `git branch --format '%(refname:short) %(upstream:track)' | awk '$2 == "[gone]" { print $1 }' | xargs -r git branch -D`
        end
      end

      class Pull < Dry::CLI::Command
        desc "Rebase-aware pull from remote for the current branch"
        def call(*)
          puts "> Stashing changes..."
          git_stash_out = `git stash`
          puts git_stash_out

          puts "\n> Fetching with prune from remote..."
          puts `git fetch --prune`

          if (`git status`).match?(/Your branch and '[^']*' have diverged/)
            puts "\n> Pulling from remote with rebase..."
            puts `git pull --rebase`
          else
            puts "\n> Pulling from remote..."
            puts `git pull`
          end

          unless git_stash_out.match?("No local changes to save")
            puts "\n> Unstashing changes..."
            puts `git stash pop`
          end
        end
      end

      class Commit < Dry::CLI::Command
        argument :message, required: true, desc: "The commit message"
        option :mode, default: "regular", values: %w[regular setup force], aliases: ["-m"], desc: "The push mode"

        desc "Commit and push all changes to remote"
        def call(**options)
          message = options.fetch(:message)

          puts "> Preparing commit..."
          puts `git commit -am '#{message}'`

          puts "\n> Pushing to remote..."
          case options.fetch(:mode)
          when "regular"
            puts `git push`
          when "setup"
            puts `git push --set-upstream origin $(git_current_branch)`
          when "force"
            puts `git push --force-with-lease --force-if-includes`
          end
        end
      end

      register "commit", Commit
      register "pull", Pull
      register "sync", Sync
      register "version", Version, aliases: ["-v", "--version"]
    end
  end
end

Dry::CLI.new(Maga::CLI::Commands).call
