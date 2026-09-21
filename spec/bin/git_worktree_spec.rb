# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require "open3"

RSpec.describe "bin/git-worktree" do
  around do |example|
    Dir.mktmpdir("components-worktrees-") do |dir|
      @root = File.join(dir, "repo")
      FileUtils.mkdir_p(File.join(@root, "bin"))
      FileUtils.cp(File.expand_path("../../bin/git-worktree", __dir__), File.join(@root, "bin"))
      FileUtils.cp_r(File.expand_path("../../bin/support", __dir__), File.join(@root, "bin"))
      File.write(File.join(@root, ".gitignore"), ".env\n.claude/\n")
      @fake_bin = File.join(dir, "tools")
      FileUtils.mkdir_p(@fake_bin)
      %w[bundle mise localroast].each do |name|
        path = File.join(@fake_bin, name)
        File.write(path, "#!/bin/sh\nexit 0\n")
        FileUtils.chmod(0o755, path)
      end
      git("init", "-b", "main")
      git("add", ".")
      git("-c", "user.name=Test", "-c", "user.email=test@example.com", "commit", "-m", "initial")
      example.run
    end
  end

  def git(*args)
    output, status = Open3.capture2e("git", "-C", @root, *args)
    raise output unless status.success?
    output
  end

  def command(path, *args)
    result = Open3.capture2e({ "PATH" => "#{@fake_bin}:#{ENV.fetch('PATH')}" },
      RbConfig.ruby, File.join(path, "bin/git-worktree"), *args)
    result
  end

  def worktree(name)
    path = File.join(@root, ".claude/worktrees", name)
    git("worktree", "add", "-b", name, path)
    path
  end

  it "assigns distinct ports and preserves them when setup is repeated" do
    first = worktree("first")
    second = worktree("second")
    expect(command(first, "setup").last).to be_success
    original = File.read(File.join(first, ".env"))
    File.write(File.join(second, ".env"), original)
    expect(command(second, "setup").last).to be_success
    port = ->(path) { File.read(File.join(path, ".env"))[/^PORT=(\d+)/, 1] }
    expect(port.call(second)).not_to eq(port.call(first))
    expect(command(first, "setup").last).to be_success
    expect(File.read(File.join(first, ".env"))).to eq(original)
  end

  it "preserves a user-created environment file" do
    path = worktree("custom")
    File.write(File.join(path, ".env"), "PORT=5900\nCUSTOM=yes\n")
    expect(command(path, "setup").last).not_to be_success
    expect(File.read(File.join(path, ".env"))).to include("CUSTOM=yes")
  end

  it "rejects main checkout removal and preserves dirty worktrees" do
    expect(command(@root, "teardown", @root).last).not_to be_success
    path = worktree("dirty")
    File.write(File.join(path, "unfinished.txt"), "keep me")
    expect(command(@root, "teardown", path).last).not_to be_success
    expect(File.read(File.join(path, "unfinished.txt"))).to eq("keep me")
  end

  it "makes teardown dry runs inert, then removes a clean worktree" do
    path = worktree("clean")
    expect(command(@root, "teardown", "--dry-run", path).last).to be_success
    expect(File.directory?(path)).to be true
    expect(command(@root, "teardown", path).last).to be_success
    expect(File.exist?(path)).to be false
  end

  it "keeps unmerged commits even when cleanup is forced" do
    path = worktree("unfinished")
    File.write(File.join(path, "new.txt"), "unfinished")
    git("-C", path, "add", ".")
    git("-C", path, "-c", "user.name=Test", "-c", "user.email=test@example.com", "commit", "-m", "unfinished")
    output, status = command(@root, "cleanup", "--delete", "--force")
    expect(status).to be_success
    expect(output).to include("1 other worktree kept")
    expect(File.directory?(path)).to be true
  end
end
