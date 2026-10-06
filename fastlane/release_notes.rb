# frozen_string_literal: true

# Store release notes ("What's new") written from the commits of a release.
#
# Commits from this repo since the previous vX.Y.Z tag, plus the shared KMP
# repo since the shared commit that release was built from, are rewritten for
# end users by the Claude CLI. The result is saved as JSON next to the release
# (fastlane/release_notes/vX.Y.Z.json), reviewed by a human before upload, and
# committed with the version bump.
#
# Kept identical in DadoMatch (Android) and DadoMatch-ios.

require "json"
require "open3"
require "fileutils"

module ReleaseNotes
  # Languages generated, as Google Play codes; App Store mapping lives in the iOS Fastfile
  LANGUAGES = %w[en-US es-419].freeze
  MAX_CHARS = 500 # Google Play hard limit (App Store allows 4000); the prompt aims for ~200
  NOTES_DIR = File.expand_path("release_notes", __dir__)
  SHARED_TRAILER = "Shared"
  TRAILER = /\A(Co-Authored-By|Signed-off-by|#{SHARED_TRAILER}): /i

  module_function

  def path_for(tag)
    File.join(NOTES_DIR, "#{tag}.json")
  end

  # Draft written by the `notes` lane (git-ignored) so the exact text reviewed
  # ahead of time is the one the release uploads
  def draft_path_for(tag)
    File.join(NOTES_DIR, "#{tag}.draft.json")
  end

  # Uses the draft for this tag if there is one, otherwise generates the notes;
  # the block returns the commits and only runs when generating
  def prepare(tag, platform:)
    draft = draft_path_for(tag)
    if File.exist?(draft)
      UI.message("Using reviewed draft #{draft}")
      FileUtils.mv(draft, path_for(tag))
    else
      save(tag, generate(platform: platform, commits: yield))
    end
  end

  def load(tag)
    path = path_for(tag)
    UI.user_error!("No release notes for #{tag} at #{path}") unless File.exist?(path)
    JSON.parse(File.read(path))
  end

  # Latest release tag reachable from HEAD, or nil on the first release
  def previous_tag(repo)
    out, status = Open3.capture2("git", "-C", repo, "describe", "--tags", "--abbrev=0", "--match", "v[0-9]*")
    status.success? ? out.strip : nil
  end

  # "Shared: <sha>" trailer the release lanes write into the tag message
  def tag_trailer_line(shared_sha)
    "#{SHARED_TRAILER}: #{shared_sha}"
  end

  # Commits worth telling users about since the previous release, from both repos
  def collect_commits(app_repo:, shared_repo:, previous_tag:)
    app_range = previous_tag ? ["#{previous_tag}..HEAD"] : ["-20", "HEAD"]
    shared_args =
      if previous_tag && (shared_sha = shared_sha_of(app_repo, previous_tag))
        ["#{shared_sha}..HEAD"]
      elsif previous_tag
        # Tags created before the trailer existed: fall back to the tag date
        ["--since=#{git(app_repo, 'log', '-1', '--format=%cI', previous_tag)}", "HEAD"]
      else
        ["-20", "HEAD"]
      end
    log(app_repo, app_range) + log(shared_repo, shared_args)
  end

  # Returns { "en-US" => "• ...", "es-419" => "• ..." }
  def generate(platform:, commits:)
    return fallback if commits.empty?

    prompt = <<~PROMPT
      You write the "What's new" text shown in the app store for DadoMatch, an app that
      suggests icebreakers / openers for dating. The readers are everyday users, not
      developers. Below are the git commits of the new #{platform} version.

      Rules:
      - At most 3 bullets, each starting with "• " and under 60 characters.
      - Lead with what the user gets ("Sign in with Google without hiccups"), never how it
        was done. No technical words: no OS or version numbers, component or library names,
        "layout", "navigation stack", "API", "crash", "context", etc.
      - Only changes a user of the #{platform} app can notice. Ignore other platforms, CI,
        build, release tooling, refactors and invisible fixes.
      - Put the most exciting change first. Fold minor fixes into one last bullet:
        "• Bug fixes and improvements".
      - If nothing is user-visible, use only "• Bug fixes and improvements".
      - Warm, simple, no exclamation overload, no emojis, no PR numbers.

      Return ONLY a JSON object, no code fences: {"en-US": "...", "es-419": "..."}
      where es-419 is natural, casual Latin American Spanish (use "tú").
    PROMPT

    # Use the developer's claude.ai login: an exported API key would take precedence
    env = { "ANTHROPIC_API_KEY" => nil }
    out, err, status = Open3.capture3(env, "claude", "-p", prompt, stdin_data: commits.join("\n"))
    unless status.success?
      UI.important("Claude CLI failed (#{err.strip.lines.last}); using generic notes — edit them in the review step")
      return fallback
    end

    notes = JSON.parse(out[/\{.*\}/m] || "")
    LANGUAGES.to_h { |lang| [lang, notes.fetch(lang).strip] }
  rescue JSON::ParserError, KeyError, Errno::ENOENT => e
    UI.important("Could not generate release notes (#{e.class}); using generic notes — edit them in the review step")
    fallback
  end

  # Shows the notes and waits for approval; the file can be edited meanwhile.
  # RELEASE_NOTES_APPROVED=1 skips the prompt (non-interactive runs, notes
  # approved beforehand from a draft); length limits still apply.
  def review!(tag, purpose:)
    path = path_for(tag)
    loop do
      notes = JSON.parse(File.read(path))
      too_long = notes.select { |_, text| text.length > MAX_CHARS }.keys
      UI.header("Release notes #{tag} — #{purpose}")
      notes.each { |lang, text| UI.message("[#{lang}] (#{text.length}/#{MAX_CHARS})\n#{text}\n") }
      UI.important("Over #{MAX_CHARS} characters: #{too_long.join(', ')}") unless too_long.empty?

      if ENV["RELEASE_NOTES_APPROVED"] == "1"
        UI.user_error!("Shorten #{too_long.join(', ')} in #{path}") unless too_long.empty?
        UI.message("Approved via RELEASE_NOTES_APPROVED")
        return notes
      end

      case UI.select("Edit #{path} if needed, then:", ["Use these notes", "Reload after editing", "Abort"])
      when "Use these notes"
        return notes if too_long.empty?
        UI.error("Shorten #{too_long.join(', ')} first")
      when "Abort"
        UI.user_error!("Release notes not approved")
      end
    end
  end

  def save(tag, notes)
    FileUtils.mkdir_p(NOTES_DIR)
    File.write(path_for(tag), JSON.pretty_generate(notes) + "\n")
  end

  def fallback
    {
      "en-US" => "• Bug fixes and improvements",
      "es-419" => "• Corrección de errores y mejoras"
    }
  end

  def shared_sha_of(repo, tag)
    message = git(repo, "tag", "-l", "--format=%(contents)", tag)
    message[/^#{SHARED_TRAILER}: (\h{7,40})$/, 1]
  end

  # Subject + body of user-facing commits (feat/fix/perf), without trailers
  def log(repo, args)
    raw = git(repo, "log", "--no-merges", "--format=%s%n%b%x1e", *args)
    raw.split("\x1e").map(&:strip).reject(&:empty?)
       .select { |c| c.match?(/\A(feat|fix|perf)(\(.+?\))?!?:/) }
       .map { |c| c.lines.reject { |l| l.strip.match?(TRAILER) }.join.strip }
  end

  def git(repo, *args)
    out, status = Open3.capture2("git", "-C", repo, *args)
    UI.user_error!("git #{args.join(' ')} failed in #{repo}") unless status.success?
    out.strip
  end
end
