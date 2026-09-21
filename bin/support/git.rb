module Dev; end

# Shared by Rails and bin/git-worktree, which can run under macOS's system Ruby.
class Dev::Git
  class << self
    def name(path)
      path = File.expand_path(path)
      name = File.basename(path)
      parent = File.basename(File.dirname(path))

      # Codex uses <hex ID>/<repo name>; include the ID to keep resources separate.
      # Use only the path so teardown works after the directory has been removed.
      if parent.match?(/\A[0-9a-f]{4}\z/i)
        "#{name}-#{parent}"
      else
        name
      end
    end
  end
end
